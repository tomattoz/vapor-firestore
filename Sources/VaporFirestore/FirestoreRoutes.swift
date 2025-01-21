//
//  FirestoreRoutes.swift
//  App
//
//  Created by Ash Thwaites on 02/04/2019.
//

import Vapor

public struct FirestoreResource {
    private weak var app: Application!
    private var client: FirestoreClient

    init(app: Application) {
        self.app = app
        self.client = FirestoreAPIClient(app: app)
    }

    public func getDocument<T: Decodable>(path: String) -> EventLoopFuture<Firestore.Document<T>> {
        return client.send(method: .GET, path: path, query: "", body: ByteBuffer(), headers: [:])
    }

    public func listDocuments<T: Decodable>(path: String) -> EventLoopFuture<[Firestore.Document<T>]> {
        let sendReq: EventLoopFuture<Firestore.List.Response<T>> = client.send(
            method: .GET,
            path: path,
            query: "",
            body: ByteBuffer(),
            headers: [:])
        return sendReq.map { result in
            result.documents
        }
    }
    public func listDocuments<T: Decodable>(path: String) async throws -> [Firestore.Document<T>] {
        var results = [Firestore.Document<T>]()
        
        let result: Firestore.List.Response<T> = try await client.send(
            method: .GET,
            path: path,
            query: "pageSize=250",
            body: ByteBuffer(),
            headers: [:]).get()

        results.append(contentsOf: result.documents)

        if var token = result.nextPageToken {
            repeat {
                let pageResults: Firestore.List.Response<T> = try await client.send(
                    method: .GET,
                    path: path,
                    query: "pageSize=250&pageToken=\(token)",
                    body: ByteBuffer(),
                    headers: [:]).get()
                token = pageResults.nextPageToken ?? ""
                results.append(contentsOf: pageResults.documents)
                //print("\(token):\(results.count)")
            } while (token != "")
        }
        
        return results
    }

    public func createDocument<T: Codable>(path: String, name: String? = nil, fields: T) -> EventLoopFuture<Firestore.Document<T>> {
        var query = ""
        if let safeName = name {
            query += "documentId=\(safeName)"
        }
        return app.client.eventLoop.tryFuture { () -> ByteBuffer in
            return try JSONEncoder.firestore.encode(["fields": fields]).convertToHTTPBody()
        }.flatMap { requestBody -> EventLoopFuture<Firestore.Document<T>> in
            return client.send(
                method: .POST,
                path: path,
                query: query,
                body: requestBody,
                headers: [:])
        }
    }

    public func updateDocument<T: Codable>(path: String, fields: T, updateMask: [String]?) -> EventLoopFuture<Firestore.Document<T>> {
        var queryParams = ""
        if let updateMask = updateMask {
            queryParams = updateMask.map({ "updateMask.fieldPaths=\($0)" }).joined(separator: "&")
        }

        return app.client.eventLoop.tryFuture { () -> ByteBuffer in
            return try JSONEncoder.firestore.encode(["fields": fields]).convertToHTTPBody()
        }.flatMap { requestBody -> EventLoopFuture<Firestore.Document<T>> in
            return client.send(
                method: .PATCH,
                path: path,
                query: queryParams,
                body: requestBody,
                headers: [:])
        }
    }

    public func updateDocument<T: Codable>(path: String, raw: String, updateMask: [String]?) -> EventLoopFuture<T> {
        var queryParams = ""
        if let updateMask = updateMask {
            queryParams = updateMask.map({ "updateMask.fieldPaths=\($0)" }).joined(separator: "&")
        }

        return app.client.eventLoop.tryFuture { () -> ByteBuffer in
            return ("{fields: \(raw)}".data(using: .utf8) ?? .init()).convertToHTTPBody()
        }.flatMap { requestBody -> EventLoopFuture<T> in
            return client.send(
                method: .PATCH,
                path: path,
                query: queryParams,
                body: requestBody,
                headers: [:])
        }
    }
}

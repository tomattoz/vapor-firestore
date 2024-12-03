import Foundation


public struct FirestoreErrorResponse: Error, Codable {
    public struct FirestoreErrorResponseBody: Codable {
        public let code: Int
        public let message: String
        public let status: String
    }
    
    public let error : FirestoreErrorResponseBody
}

public enum FirestoreError: Error {
    case requestFailed
    case signing
    case parseFailed(data: String)
    case response(error: FirestoreErrorResponse)
}

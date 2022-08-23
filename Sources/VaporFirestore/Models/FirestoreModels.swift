//
//  FirestoreRequest.swift
//  App
//
//  Created by Ash Thwaites on 02/04/2019.
//


import Foundation
import Vapor
import JWT

public protocol PropertyWrapperValue {
    associatedtype WrappedValue: Codable
    var wrappedValue: WrappedValue { get }
    
    init(wrappedValue: WrappedValue)
}

public struct ScopeClaim: JWTClaim, ExpressibleByStringLiteral {
    /// The claim's subject's identifier
    public var value: String
    
    /// See Claim.init
    public init(value: String) {
        self.value = value
    }
}

public enum Firestore
{

    public enum Auth
    {
        public struct Payload: JWTPayload {
            
            public var exp: ExpirationClaim
            public var iss: IssuerClaim
            public var aud: AudienceClaim
            public var iat: IssuedAtClaim
            public var scope: ScopeClaim
            
            public init(exp: ExpirationClaim = ExpirationClaim(value: Date(timeIntervalSinceNow: (60 * 15))),
                        iss: IssuerClaim,
                        aud: AudienceClaim = AudienceClaim(value: "https://www.googleapis.com/oauth2/v4/token"),
                        iat: IssuedAtClaim = IssuedAtClaim(value: Date()),
                        scope: ScopeClaim =  ScopeClaim(value: "https://www.googleapis.com/auth/datastore")) {
                self.exp = exp
                self.iss = iss
                self.aud = aud
                self.iat = iat
                self.scope = scope
            }

            public func verify(using signer: JWTSigner) throws {
                try exp.verifyNotExpired()
            }
        }

        
        public struct Request: Content {
            public static let defaultMediaType: HTTPMediaType = .urlEncodedForm
            
            public let grantType: String
            public let assertion: String
            
            enum CodingKeys: String, CodingKey {
                case assertion
                case grantType = "grant_type"
            }
            
            public init(grantType: String, assertion: String) {
                self.grantType = grantType
                self.assertion = assertion
            }
        }
        
        public struct Response: Content {
            public var accessToken: String
            public var tokenType: String
            public var expiresIn: Int
            
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case tokenType = "token_type"
                case expiresIn = "expires_in"
            }
        }
    }
    
    
    enum Create
    {
        public struct Request<T: Codable>: Content {
            public let name: String
            public let fields: T?
        }
        
        public struct Response<T: Codable>: Content {
        }

    }
    
    enum List
    {
        public struct Request<T: Codable>: Content {
        }

        public struct Response<T: Codable>: Content {
            public let documents: [Document<T>]
            public let nextPageToken: String?
            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                nextPageToken = try values.decodeIfPresent(String.self, forKey: .nextPageToken) 
                documents = try values.decodeIfPresent( [Document<T>].self, forKey: .documents) ?? [Document<T>]()
            }
        }
        
    }

    
    public struct Document<T: Codable>: Codable {
        public let name: String
        public let createTime: Date
        public let updateTime: Date
        public let fields: T?
        public var id: String { return String(name.split(separator: "/").last ?? "") }
    }
    
    // MARK - VALUES wrappers
    
    public enum CodingKeys: String, CodingKey {
        case stringValue
        case booleanValue
        case integerValue
        case doubleValue
        case geoPointValue
        case timestampValue
        case referenceValue
        case mapValue
        case arrayValue
        case nullValue
    }
    
    @propertyWrapper
    public class GenericValue<T: Codable, Keys: CodingKey>: Codable, PropertyWrapperValue {
        public var wrappedValue: T
        public class var key: Keys { fatalError() }
        
        required public init(wrappedValue: T) {
            self.wrappedValue = wrappedValue
        }
        
        required public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            self.wrappedValue = try container.decode(T.self, forKey: Self.key)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Keys.self)
            try container.encode(wrappedValue, forKey: Self.key)
        }
    }
    
    // MARK: - simple types
    @propertyWrapper
    public class StringValue: GenericValue<String, CodingKeys>, ExpressibleByStringLiteral {
        public override var wrappedValue: String {
            get { super.wrappedValue }
            set { super.wrappedValue = newValue }
        }
        
        public required init(stringLiteral value: StringLiteralType) {
            super.init(wrappedValue: value)
        }
        
        required public init(from decoder: Decoder) throws {
            try super.init(from: decoder)
        }
        
        required public init(wrappedValue: String) {
            super.init(wrappedValue: wrappedValue)
        }
        
        override public class var key: CodingKeys { .stringValue }
    }
    
    @propertyWrapper
    public class BoolValue: GenericValue<Bool, CodingKeys>, ExpressibleByBooleanLiteral {
        public override var wrappedValue: Bool {
            get { super.wrappedValue }
            set { super.wrappedValue = newValue }
        }
        
        public required init(booleanLiteral value: BooleanLiteralType) {
            super.init(wrappedValue: value)
        }
        
        required public init(from decoder: Decoder) throws {
            try super.init(from: decoder)
        }
        
        required public init(wrappedValue: Bool) {
            super.init(wrappedValue: wrappedValue)
        }
        
        override public class var key: CodingKeys { .booleanValue }
    }
    
    @propertyWrapper
    public class TimestampValue: GenericValue<Date, CodingKeys> {
        public override var wrappedValue: Date {
            get { super.wrappedValue }
            set { super.wrappedValue = newValue }
        }
        override public class var key: CodingKeys { .timestampValue }
    }
    
    public class ReferenceValue: Codable, PropertyWrapperValue {
        public typealias WrappedValue = String
        /// In this case wrappedValue is fullDocumentPath
        public var wrappedValue: String { return fullDocumentPath }
        
        /// e.g. "users/userNicknameOne/"
        public var documentPath: String {
            didSet { regenerateFullDocumentPath() }
        }
        
        /// e.g. "projects/{project_id}/databases/{databaseId}/documents/{document_path}"
        private(set) var fullDocumentPath: String
        
        private var projectId: String
        private var databaseId: String
        
        public required init(wrappedValue: String) {
            self.fullDocumentPath = wrappedValue
            do {
                let parts = try ReferenceValue.parts(fromFullPath: fullDocumentPath)
                self.projectId = parts.0
                self.databaseId = parts.1
                self.documentPath = parts.2
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        
        public init(projectId: String, databaseId: String = "(default)", documentPath: String) {
            self.projectId = projectId
            self.databaseId = databaseId
            self.documentPath = documentPath
            self.fullDocumentPath = ""
            regenerateFullDocumentPath()
        }
        
        required public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.fullDocumentPath = try container.decode(String.self, forKey: .referenceValue)
            let parts = try ReferenceValue.parts(fromFullPath: fullDocumentPath)
            self.projectId = parts.0
            self.databaseId = parts.1
            self.documentPath = parts.2
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fullDocumentPath, forKey: .referenceValue)
        }
        
        func regenerateFullDocumentPath() {
            fullDocumentPath = "projects/\(projectId)/databases/\(databaseId)/documents/\(documentPath)"
        }
        
        static func parts(fromFullPath fullPath: String) throws -> (projectId: String, databaseId: String, documentPath: String)  {
            let tokens = fullPath.trimmingCharacters(in: ["/"]).components(separatedBy: "/")
            guard tokens.count > 6 else {
                throw NSError(domain: "vapor-firestore", code: 100, userInfo: ["description":
                "tokens.count <= 6"])
            }
            let projectId = tokens[1]
            let databaseId = tokens[3]
            let documentPath = Array(tokens.suffix(from: 5)).joined(separator: "/")
            
            return (projectId, databaseId, documentPath)
        }
    }
    
    @propertyWrapper
    public struct DoubleValue: Codable, PropertyWrapperValue, ExpressibleByFloatLiteral {
        public var wrappedValue: Double
        
        public init(floatLiteral value: FloatLiteralType) {
            self.init(wrappedValue: value)
        }
        
        public init(wrappedValue: Double) {
            self.wrappedValue = wrappedValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.wrappedValue = try container.decode(Double.self, forKey: .doubleValue)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(wrappedValue, forKey: .doubleValue)
        }
    }
    
    @propertyWrapper
    public struct IntValue: Codable, PropertyWrapperValue, ExpressibleByIntegerLiteral {
        private var stringVersion: String
        public var wrappedValue: Int {
            get { return Int(stringVersion) ?? 0 }
            set { stringVersion = String(newValue) }
        }
        
        public init(integerLiteral value: IntegerLiteralType) {
            self.init(wrappedValue: value)
        }
        
        public init(wrappedValue: Int) {
            self.stringVersion = String(wrappedValue)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.stringVersion = try container.decode(String.self, forKey: .integerValue)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(wrappedValue, forKey: .integerValue)
        }
    }
    
    // MARK: - Geo Type
    public struct GeoPoint: Codable, PropertyWrapperValue {
        public var wrappedValue: GeoPoint { self }
        
        public let latitude: Double
        public let longitude: Double
        
        private enum GeoCodingKeys: String, CodingKey {
            case latitude
            case longitude
        }
        
        public init(wrappedValue: Firestore.GeoPoint) {
            self.init(latitude: wrappedValue.latitude, longitude: wrappedValue.longitude)
        }
    
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let nestedContainer = try container.nestedContainer(keyedBy: GeoCodingKeys.self, forKey: .geoPointValue)
            latitude = try nestedContainer.decode(Double.self, forKey: .latitude)
            longitude = try nestedContainer.decode(Double.self, forKey: .longitude)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            var nestedContainer = container.nestedContainer(keyedBy: GeoCodingKeys.self, forKey: .geoPointValue)
            try nestedContainer.encode(latitude, forKey: .latitude)
            try nestedContainer.encode(longitude, forKey: .longitude)
        }
    }
    
    // MARK: - complex types
    @propertyWrapper
    public struct MapValue<T: Codable>: Codable, PropertyWrapperValue {
        enum NestedCodingKeys: CodingKey {
            case fields
        }
        
        public var wrappedValue: T
        
        public init(wrappedValue: T) {
            self.wrappedValue = wrappedValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Firestore.CodingKeys.self)
            let nestedContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .mapValue)
            wrappedValue = try nestedContainer.decode(T.self, forKey: .fields)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Firestore.CodingKeys.self)
            var nestedContainer = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .mapValue)
            try nestedContainer.encode(wrappedValue, forKey: .fields)
        }
    }
    
    @propertyWrapper
    public struct ArrayValue<T: Codable>: Codable, PropertyWrapperValue, ExpressibleByArrayLiteral {
        public typealias ArrayLiteralElement = T
        
        enum NestedCodingKeys: CodingKey {
            case values
        }
        
        public var wrappedValue: [T]
        
        public init(arrayLiteral elements: ArrayLiteralElement...) {
            self.init(wrappedValue: elements)
        }
        
        public init(wrappedValue: [T]) {
            self.wrappedValue = wrappedValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Firestore.CodingKeys.self)
            let nestedContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .arrayValue)
            wrappedValue = try nestedContainer.decode([T].self, forKey: .values)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Firestore.CodingKeys.self)
            var nestedContainer = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .arrayValue)
            try nestedContainer.encode(wrappedValue, forKey: .values)
        }
    }
    
    // MARK: - Util Types
    @propertyWrapper
    public class NullableValue<T: Codable & PropertyWrapperValue>: Codable, ExpressibleByNilLiteral {
        public var wrappedValue: T.WrappedValue?
        
        public required init(nilLiteral: ()) {
            wrappedValue = nil
        }
        
        public init(wrappedValue: T.WrappedValue?) {
            self.wrappedValue = wrappedValue
        }
        
        required public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Firestore.CodingKeys.self)
            do {
                _ = try container.decode(T?.self, forKey: .nullValue)
            } catch {
                wrappedValue = try T(from: decoder).wrappedValue
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            if let someValue = wrappedValue {
                try T(wrappedValue: someValue).encode(to: encoder)
            } else {
                var container = encoder.container(keyedBy: Firestore.CodingKeys.self)
                try container.encode(wrappedValue, forKey: .nullValue)
            }
        }
    }
}



import Vapor
@testable import VaporFirestore
import XCTest
import Nimble


struct FSFlightplan: Codable {
    @Firestore.StringValue
    var id: String
    
    @Firestore.StringValue
    var parentId: String
    
    // @Firestore.StringValue
    // var origin: String
    
    //@Firestore.StringValue
    //var destination: String
    
    @Firestore.TimestampValue
    var lastModified: Date
    
    @Firestore.TimestampValue
    var metadataModified: Date
}



final class VaporFirestoreTests: XCTestCase {
    var app: Application!

    override func setUp() {
        super.setUp()
        self.app = Application(.testing)
        self.app.storage[FirestoreConfig.FirestoreConfigKey.self] = FirestoreConfig(
            projectId: Environment.get("FS_PRJ_KEY")!,
            email: Environment.get("FS_EMAIL_KEY")!,
            privateKey: Environment.get("FS_PRIVKEY_KEY")!
        )
    }

    func testAuthToken() throws {
        do {
            let apiClient = FirestoreAPIClient(app: app)
            let result = try apiClient.getToken().wait()
            
            expect(result).toNot(beEmpty())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCreateDoc() throws {
        do {
            let client = app.firestoreService.firestore
            let testObject = TestFields(title: "A title", subTitle: "A subtitle")

            let result = try client.createDocument(path: "test", fields: testObject).wait()
            expect(result).toNot(beNil())

            print("Test object-id: \( (result.name as NSString).lastPathComponent)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testGeoCreate() throws {
        do {
            let client = app.firestoreService.firestore
            let testObject = GeoFieldTest(somegeoPoint: Firestore.GeoPoint(latitude: 15.03, longitude: 15.03))
            let result = try client.createDocument(path: "test", fields: testObject).wait()
            expect(result).toNot(beNil())

            print("Test object-id: \( (result.name as NSString).lastPathComponent)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testGeoRead() throws {
        do {
            var objectId = "<object-id>"
            objectId = "7B5qnHhy0vzpq6yQNFlR" // uncomment this string a and set it to some real id from testDatabbase
            let client = app.firestoreService.firestore

            let result: Firestore.Document<GeoFieldTest> = try client.getDocument(path: "test/\(objectId)").wait()

            expect(result).toNot(beNil())
            expect(result.fields?.somegeoPoint.latitude).toNot(beNil())
            expect(result.fields?.somegeoPoint.longitude).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testNullableCreate() throws {
        do {
            let client = app.firestoreService.firestore
            let testObject = NullValueTest(title: nil, number: 120)
            let result = try client.createDocument(path: "test", fields: testObject).wait()
            expect(result).toNot(beNil())

            print("Test object-id: \( (result.name as NSString).lastPathComponent)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testNullRead() throws {
        do {
            var objectId = "<object-id>"
            objectId = "bGxv5lBmZrlWZQWyyGS6" // uncomment this string a and set it to some real id from testDatabbase
            let client = app.firestoreService.firestore

            let result: Firestore.Document<NullValueTest> = try client.getDocument(path: "test/\(objectId)").wait()

            expect(result).toNot(beNil())
            expect(result.fields?.title).to(beNil())
            expect(result.fields?.number).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testUpdateDoc() throws {
        do {
            var objectId = "<object-id>"
            objectId = "oomlgfl9uWovPVKikBFB" // uncomment this string a and set it to some real id from testDatabbase
            let client = app.firestoreService.firestore
            let testObject = TestFields(title: "An updated title again", subTitle: "expecting to ignore this text")
            let result = try client.updateDocument(path: "test/\(objectId)", fields: testObject, updateMask: ["title"]).wait()

            expect(result).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testListDocs() throws {
        do {
            let client = app.firestoreService.firestore
            let result: [Firestore.Document<TestFields>] = try client.listDocuments(path: "test").wait()

            expect(result).toNot(beNil())
            expect(result[0].fields?.title).toNot(beNil())
            expect(result[0].fields?.subTitle).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testListDocs2() async throws {
        do {
            let client = app.firestoreService.firestore
            let result: [Firestore.Document<FSFlightplan>] = try await client.listDocuments(path: "users/2/flightplans")
            
            expect(result).toNot(beNil())
            XCTAssertGreaterThan(result.count, 3900)
            expect(result[0].fields?.id).toNot(beNil())
            expect(result[0].fields?.parentId).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testGetDoc() throws {
        do {
            var objectId = "<object-id>"
            objectId = "oomlgfl9uWovPVKikBFB" // uncomment this string a and set it to some real id from testDatabbase
            let client = app.firestoreService.firestore

            let result: Firestore.Document<TestFields> = try client.getDocument(path: "test/\(objectId)").wait()

            expect(result).toNot(beNil())
            expect(result.fields?.title).toNot(beNil())
            expect(result.fields?.subTitle).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAllTypesCreate() throws {
        do {
            let client = app.firestoreService.firestore
            let testObject = AllTypesModelTest(someStringValue: "demoString",
                                               someBoolValue: true,
                                               someIntValue: 42,
                                               someDoubleValue: 3.14159265359,
                                               someGeoPoint: Firestore.GeoPoint(latitude: 15, longitude: 10),
                                               someTimestamp: Date(),
                                               someReference: Firestore.ReferenceValue(projectId: app.firebaseConfig!.projectId, documentPath: "test/tester"),
                                               someMapValue: AllTypesModelTest.NestedType(nestedString: "nestedStringDemo"),
                                               someArray: ["lemon", "banana", "apple", "grapes"]
            )
            let result = try client.createDocument(path: "test", fields: testObject).wait()
            expect(result).toNot(beNil())

            print("Test object-id: \( (result.name as NSString).lastPathComponent)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAllTypesRead() throws {
        do {
            var objectId = "<object-id>"
            objectId = "7ANaWtFHJ2p4VKspHOP9" // uncomment this string a and set it to some real id from testDatabbase
            let client = app.firestoreService.firestore

            let result: Firestore.Document<AllTypesModelTest> = try client.getDocument(path: "test/\(objectId)").wait()

            print(result.fields)
            expect(result.fields).toNot(beNil())
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testWriteWithName() throws {
        do {
            let client = app.firestoreService.firestore
            let testObject = TestFields(title: "A title", subTitle: "A subtitle")

            let result = try client.createDocument(path: "test", name: "demoName", fields: testObject).wait()
            expect(result).toNot(beNil())
            expect(result.id).to(be("demoName"))

            print("Test object-id: \( (result.name as NSString).lastPathComponent)")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}

//
//  HTTPRequestBuilderTests.swift
//  CombineNetworking
//
//  Created by Denis Silko on 29.04.2024.
//

import XCTest
import Combine
import CombineNetworking

final class HTTPRequestBuilderTests: XCTestCase {
    var sut: HTTPRequestBuilder<MockEndpoint>!
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        sut = HTTPRequestBuilder(jsonEncoder: JSONEncoder())
    }
    
    override func tearDown() {
        sut = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    func testRequestCreation() throws {
        let expectation = XCTestExpectation(description: "Request creation")
        let endpoint = MockEndpoint()

        sut.request(endpoint)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected error: \(error)")
                }
            }, receiveValue: { request in
                XCTAssertEqual(request.url?.absoluteString, "https://example.com/path?key=value")
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMethodAreSetCorrectly() throws {
        let expectation = XCTestExpectation(description: "Method set correctly")
        let endpoint = MockEndpoint(_method: .delete)

        sut.request(endpoint)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected error: \(error)")
                }
            }, receiveValue: { request in
                XCTAssertEqual(request.httpMethod, endpoint.method.rawValue)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testHeadersAreSetCorrectly() throws {
        let expectation = XCTestExpectation(description: "Headers set correctly")
        let headers = [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3",
        ]
        let endpoint = MockEndpoint(_headers: headers)

        sut.request(endpoint)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected error: \(error)")
                }
            }, receiveValue: { request in
                headers.forEach {
                    XCTAssertEqual(request.allHTTPHeaderFields?[$0.key], $0.value)
                }
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testMultipleQueryParametersAreAddedCorrectly() throws {
        let expectation = XCTestExpectation(description: "Query parameters added correctly")
        let parameters = [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3",
        ]
        let endpoint = MockEndpoint(_parameters: parameters)

        sut.request(endpoint)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected error: \(error)")
                }
            }, receiveValue: { request in
                parameters.forEach {
                    XCTAssertTrue(request.url?.absoluteString.contains("\($0.key)=\($0.value)") ?? false)
                }
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testCachePolicy() throws {
        let expectation = XCTestExpectation(description: "Cache policy is correct")
        let endpoint = MockEndpoint()

        sut.request(endpoint)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected error: \(error)")
                }
            }, receiveValue: { request in
                XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRequestBodyEncoding() throws {
        let expectation = XCTestExpectation(description: "Body encoding is correct")
        struct MockData: Codable {
            let name: String
        }

        let endpoint = MockEndpoint(_method: .post)
        let data = MockData(name: "Test")

        sut.request(endpoint, with: data)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Unexpected error: \(error)")
                }
            }, receiveValue: { request in
                guard let bodyData = request.httpBody else {
                    XCTFail("Body data is nil")
                    return
                }

                let decodedData = try? JSONDecoder().decode(MockData.self, from: bodyData)
                XCTAssertEqual(decodedData?.name, "Test")
                expectation.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testEncodingErrorReturnsFailure() throws {
        let expectation = XCTestExpectation(description: "Encoding error returns failure")
        struct UnencodableMockData: Codable {
            let data: Data

            init() {
                self.data = Data()
            }

            func encode(to encoder: Encoder) throws {
                throw EncodingError.invalidValue(data, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode Data directly"))
            }
        }

        let endpoint = MockEndpoint(_method: .post)
        let data = UnencodableMockData()

        sut.request(endpoint, with: data)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                } else {
                    XCTFail("Expected failure, but got success")
                }
            }, receiveValue: { _ in
                XCTFail("Expected failure, but received a value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }
}

//MARK: - MockEndpoint

extension HTTPRequestBuilderTests {
    
    struct MockEndpoint: HTTPEndpoint {
        var _method: HTTPMethod = .get
        var _parameters: [String : Any]? = ["key": "value"]
        var _headers: [String : String]? = ["Content-Type": "application/json"]
        
        // MARK: - HTTPEndpoint
        var baseURL: URL { return URL(string: "https://example.com")! }
        var path: String { return "/path" }
        var method: HTTPMethod { return _method }
        var headers: [String : String]? { return _headers }
        var parameters: [String : Any]? { return _parameters }
        var timeout: TimeInterval { 30 }
    }
    
}

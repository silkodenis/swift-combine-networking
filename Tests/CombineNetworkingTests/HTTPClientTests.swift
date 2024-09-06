//
//  HTTPClient.swift
//  CombineNetworking
//
//  Created by Denis Silko on 30.04.2024.
//

import XCTest
import Combine
import CombineNetworking

final class HTTPClientTests: XCTestCase {
   
    func testInvalidHTTPResponseStatus() throws {
        struct MockSession: HTTPSession {
            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil,
                                               headerFields: ["Content-Type": "application/json"])!
                return Result.Publisher((data: Data(), response: response)).eraseToAnyPublisher()
            }
        }

        let sut = HTTPClient(jsonDecoder: JSONDecoder(), session: MockSession())
        let requestURL = URL(string: "https://example.com")!
        let request = URLRequest(url: requestURL)
        let expectation = XCTestExpectation(description: "Invalid response status test")

        let cancellable = sut.executeJsonRequest(request)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    if let httpClientError = error as? HTTPClientError,
                       case .invalidResponse(let details) = httpClientError {
                        XCTAssertEqual(details.statusCode, 404, "Expected status code 404")
                        XCTAssertEqual(details.url, requestURL, "Expected URL to match request URL")
                        XCTAssertNotNil(details.description, "Expected description to be non-nil")
                        XCTAssertEqual(details.headers?["Content-Type"], "application/json", "Expected correct content type header")
                        
                        expectation.fulfill()
                    } else {
                        XCTFail("Expected HTTPClientError.invalidResponse with status code 404")
                    }
                } else {
                    XCTFail("Expected failure due to invalid response status, but got success")
                }
            }, receiveValue: { (_: Data) in
                XCTFail("Expected failure due to invalid response status, but received data")
            })

        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }

    func testSuccessfulDataFetch() throws {
        struct MockResponse: Codable, Equatable {
            let id: Int
            let name: String
        }

        struct MockSession: HTTPSession {
            let responseData: Data

            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return Result.Publisher((data: responseData, response: response)).eraseToAnyPublisher()
            }
        }

        let mockResponse = MockResponse(id: 1, name: "Test")
        let mockSession = MockSession(responseData: try! JSONEncoder().encode(mockResponse))
        let sut = HTTPClient(jsonDecoder: JSONDecoder(), session: mockSession)
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let expectation = XCTestExpectation(description: "Successful data fetch")

        let cancellable = sut.executeJsonRequest(request)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Request failed when success was expected")
                }
            }, receiveValue: { (decodedData: MockResponse) in
                XCTAssertEqual(decodedData, mockResponse)
                expectation.fulfill()
            })

        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
    
    func testSuccessfulDataRequest() throws {
        struct MockSession: HTTPSession {
            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let mockData = "Test data".data(using: .utf8)!
                return Result.Publisher((data: mockData, response: response)).eraseToAnyPublisher()
            }
        }
        
        let sut = HTTPClient(session: MockSession())
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let expectation = XCTestExpectation(description: "Successful data request")
        
        let cancellable = sut.executeDataRequest(request)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Expected success, but request failed")
                }
            }, receiveValue: { data in
                XCTAssertEqual(String(data: data, encoding: .utf8), "Test data", "Expected correct data to be returned")
                expectation.fulfill()
            })
        
        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
    
    func testDataRequestServerError() throws {
        struct MockSession: HTTPSession {
            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return Result.Publisher((data: Data(), response: response)).eraseToAnyPublisher()
            }
        }
        
        let sut = HTTPClient(session: MockSession())
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let expectation = XCTestExpectation(description: "Server error handling test")
        
        let cancellable = sut.executeDataRequest(request)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion, let httpClientError = error as? HTTPClientError,
                   case .invalidResponse(let details) = httpClientError {
                    XCTAssertEqual(details.statusCode, 404, "Expected status code 404")
                    expectation.fulfill()
                } else {
                    XCTFail("Expected HTTPClientError.invalidResponse with status code 404")
                }
            }, receiveValue: { _ in
                XCTFail("Expected failure due to server error, but received data")
            })
        
        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }

    func testNetworkErrorHandling() throws {
        struct MockSession: HTTPSession {
            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                return Fail(error: URLError(.notConnectedToInternet)).eraseToAnyPublisher()
            }
        }

        let sut = HTTPClient(jsonDecoder: JSONDecoder(), session: MockSession())
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let expectation = XCTestExpectation(description: "Network error handling test")

        let cancellable = sut.executeJsonRequest(request)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion, let httpClientError = error as? HTTPClientError,
                    case .networkError(let error) = httpClientError {
                    let urlError = error as? URLError
                    XCTAssertEqual(urlError?.code, .notConnectedToInternet)
                    expectation.fulfill()
                } else {
                    XCTFail("Expected HTTPClientError.networkError with URLError.notConnectedToInternet")
                }
            }, receiveValue: { (_: String) in
                XCTFail("Expected failure due to network error, but received data")
            })

        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
    
    func testInvalidJSONDecoding() throws {
        struct MockSession: HTTPSession {
            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let invalidJSONData = "invalid-json".data(using: .utf8)!
                return Result.Publisher((data: invalidJSONData, response: response)).eraseToAnyPublisher()
            }
        }

        let sut = HTTPClient(jsonDecoder: JSONDecoder(), session: MockSession())
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let expectation = XCTestExpectation(description: "Invalid JSON decoding test")

        let cancellable = sut.executeJsonRequest(request)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    expectation.fulfill()
                } else {
                    XCTFail("Expected failure due to invalid JSON, but got success")
                }
            }, receiveValue: { (_: String) in
                XCTFail("Expected decoding failure, but received data")
            })

        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
    
    func testDecodingErrorHandling() throws {
        struct MockSession: HTTPSession {
            func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
                let invalidJSONData = "{".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return Just((data: invalidJSONData, response: response))
                    .setFailureType(to: URLError.self)
                    .eraseToAnyPublisher()
            }
        }

        let sut = HTTPClient(jsonDecoder: JSONDecoder(), session: MockSession())
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let expectation = XCTestExpectation(description: "Decoding error handling test")

        let cancellable = sut.executeJsonRequest(request)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Expected decoding error due to invalid JSON, but got success")
                case .failure(let error):
                    guard case let HTTPClientError.decodingError(decodingError) = error else {
                        XCTFail("Expected HTTPClientError.decodingError, received \(error)")
                        return
                    }
                    XCTAssertTrue(decodingError is DecodingError, "Expected .decodingError received \(type(of: decodingError))")
                    expectation.fulfill()
                }
            }, receiveValue: { (_: Data) in
                XCTFail("Expected no data due to decoding error, but received data")
            })

        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
}

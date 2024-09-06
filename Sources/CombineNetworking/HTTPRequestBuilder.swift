/*
 * Copyright (c) [2024] [Denis Silko]
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Combine

/// A class responsible for constructing HTTP requests based on specified endpoints and parameters.
/// This class provides a declarative way to build and issue network requests using the Combine framework.
public final class HTTPRequestBuilder<T: HTTPEndpoint> {
    /// JSON encoder to encode request data.
    private let jsonEncoder: JSONEncoder
    
    /// Initializes a new HTTPRequestBuilder with the given JSON encoder.
    /// - Parameter jsonEncoder: A `JSONEncoder` used to encode the data to be sent in network requests. Defaults to a new instance of `JSONEncoder()`.
    public init(jsonEncoder: JSONEncoder = JSONEncoder()) {
        self.jsonEncoder = jsonEncoder
    }

    /// Creates a URLRequest configured with endpoint details and optional data.
    /// This method builds the request and returns a publisher that emits either the URLRequest or an error.
    /// - Parameters:
    ///   - endpoint: The endpoint defining URL and method.
    ///   - data: Optional Codable data to be included in the request body.
    /// - Returns: A publisher that emits a URLRequest or an error.
    public func request(_ endpoint: T, with data: Codable? = nil) -> AnyPublisher<URLRequest, Error> {
        do {
            let request = try buildRequest(for: endpoint, with: data)
            return Just(request)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    /// Constructs a URLRequest with provided endpoint and data.
    /// - Parameters:
    ///   - endpoint: The endpoint containing all necessary information to build the URL.
    ///   - data: Optional Codable data to be included as the HTTP body.
    /// - Throws: An error if the URL cannot be constructed or the data cannot be encoded.
    /// - Returns: A configured URLRequest ready to be executed.
    public func buildRequest(for endpoint: T, with data: Codable? = nil) throws -> URLRequest {
        let url = endpoint.baseURL.appendingPathComponent(endpoint.path)
        
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)?
                .addingQueryItems(endpoint.parameters), let finalURL = urlComponents.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers
        request.timeoutInterval = endpoint.timeout
        
        if let data = data {
            request.httpBody = try jsonEncoder.encode(data)
        }

        return request
    }
}

// MARK: - fileprivate

/// Extension to handle the addition of query items to URLComponents.
fileprivate extension URLComponents {
    /// Adds query items to the URLComponents instance from a dictionary of parameters.
    /// - Parameter queryItems: A dictionary containing the query parameters.
    /// - Returns: A modified URLComponents instance including the new query items.
    func addingQueryItems(_ queryItems: [String: Any]?) -> URLComponents {
        var copy = self
        copy.queryItems = queryItems?.compactMap { key, value in
            if let value = value as? CustomStringConvertible {
                return URLQueryItem(name: key, value: value.description)
            }
            
            return nil
        }
        
        return copy
    }
}

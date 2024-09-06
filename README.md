[![License](https://img.shields.io/github/license/silkodenis/swift-combine-networking.svg)](https://github.com/silkodenis/swift-combine-networking/blob/main/LICENSE)
![swift](https://github.com/silkodenis/swift-combine-networking/actions/workflows/swift.yml/badge.svg?branch=main)

# Combine Networking

CombineNetworking is a robust and flexible HTTP networking package for Swift, designed to leverage the Combine framework for handling network requests in a declarative way. This package simplifies the process of making HTTP requests, decoding responses, and handling errors.

## Core Features

- **Flexible and Declarative Networking**: Use Swift enums and protocols to define and configure various network operations, simplifying and clarifying the setup of HTTP requests.
- **Combine Integration**: Take full advantage of Swift's Combine framework for managing asynchronous network requests and handling responses.
- **Mockable HTTP Sessions**: Provides the ability to mock HTTP sessions, which is crucial for unit testing and ensuring that your application behaves as expected under various network conditions without relying on live network calls.
- **Robust Error Handling**: Includes comprehensive error handling mechanisms to manage and respond to different network and decoding errors effectively.


## Installation

### Requirements

- **Swift 5.1**+
- **Xcode 11**+
- **iOS**: iOS 13.0+
- **macOS**: macOS 10.15+
- **watchOS**: watchOS 6.0+
- **tvOS**: tvOS 13.0+

### Using Swift Package Manager from Xcode
To add CombineNetworking to your project in Xcode:
1. Open your project in Xcode.
2. Navigate to `File` → `Swift Packages` → `Add Package Dependency...`.
3. Paste the repository URL: `https://github.com/silkodenis/swift-combine-networking.git`.
4. Choose the version you want to use (you can specify a version, a commit, or a branch).
5. Click `Next` and Xcode will download the package and add it to your project.

### Using Swift Package Manager from the Command Line

If you are managing your Swift packages manually or through a package.swift file, add CombineNetworking as a dependency:

1. Open your `Package.swift`.
2. Add `CombineNetworking` to your package's dependencies:

```swift
let package = Package(
    name: "YourProjectName",
    dependencies: [
        .package(url: "https://github.com/silkodenis/swift-combine-networking.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "YourTargetName",
            dependencies: ["CombineNetworking"]
        )
    ]
)
```

This setup specifies that CombineNetworking should be pulled from the master branch and included in the YourTargetName target of your project.

## Components

- **[HTTPSession](https://github.com/silkodenis/swift-combine-networking/blob/main/Sources/CombineNetworking/HTTPSession.swift) Protocol**: Allows for mocking of session behavior in unit tests, making it easier to test network interactions.
- **[HTTPEndpoint](https://github.com/silkodenis/swift-combine-networking/blob/main/Sources/CombineNetworking/HTTPEndpoint.swift) Protocol**: Facilitates the construction of different HTTP requests using a clear and concise interface.
- **[HTTPRequestBuilder](https://github.com/silkodenis/swift-combine-networking/blob/main/Sources/CombineNetworking/HTTPRequestBuilder.swift)**: Provides a declarative API for building URL requests from HTTPEndpoint instances.
- **[HTTPClient](https://github.com/silkodenis/swift-combine-networking/blob/main/Sources/CombineNetworking/HTTPClient.swift)**: Executes network requests and processes the responses, supporting generic decoding.
- **[HTTPClientError](https://github.com/silkodenis/swift-combine-networking/blob/main/Sources/CombineNetworking/HTTPClient.swift)**: Manages error states that can occur during the execution of HTTP requests. This enumeration helps in categorizing and handling different types of errors, such as:
  - **invalidResponse**: Indicates that the HTTP response was not valid or did not meet expected criteria, containing details about the response.
  - **decodingError**: Occurs when there is a failure in decoding the response data, providing the underlying error for more context.
  - **networkError**: Represents errors related to network connectivity issues or problems with the network request itself.
  
## Usage
Here’s how to use CombineNetworking in your project:

<details>
<summary>Define an Endpoint</summary>
    
First, define your endpoints using the HTTPEndpoint protocol:

```swift
enum Endpoint {
    case createUser
    case fetchUser(id: Int)
    case updateUser(id: Int)
    case deleteUser(id: Int)
}

extension Endpoint: HTTPEndpoint {
    var baseURL: URL {
        return URL(string: "https://api.example.com")!
    }
    
    var path: String {
        switch self {
        case .createUser:
            return "/users"
        case .fetchUser(let id), .updateUser(let id), .deleteUser(let id):
            return "/users/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .createUser:
            return .post
        case .fetchUser:
            return .get
        case .updateUser:
            return .put
        case .deleteUser:
            return .delete
        }
    }
    
    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .createUser, .updateUser:
            return ["param": "value"]  // Example parameters.
        default:
            return nil
        }
    }
    
    var timeout: TimeInterval {
        return 30
    }
}
```
</details>

<details>
<summary>Create and Execute a Request</summary>
    
```swift
struct UserDataDTO: Codable {
    let name: String
}

let builder = HTTPRequestBuilder<Endpoint>(jsonEncoder: JSONEncoder())
let client = HTTPClient(jsonDecoder: JSONDecoder(), session: URLSession.shared)

func fetchUser(id: Int) -> AnyPublisher<UserDataDTO, Error> {
        builder.request(.fetchUser(id: id))
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
}
```

Replace `UserDataDTO` with the appropriate data model expected from the API. Ensure that this model conforms to the `Codable` protocol, which enables it to be easily decoded from JSON or encoded to JSON, depending on your needs.
</details>


<details>
<summary>Error Handling</summary>
Here's how you might call fetchUser and handle various potential errors:
  
```swift
fetchUser(id: 123)
    .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
            print("Fetch completed successfully.")
        case .failure(let error):
            switch error {
            case let HTTPClientError.invalidResponse(details):
                print("Invalid response: Status code \(details.statusCode). Description: \(details.description ?? "No description")")
            case let HTTPClientError.decodingError(decodingError):
                print("Decoding error: \(decodingError.localizedDescription)")
            case let HTTPClientError.networkError(networkError):
                print("Network error: \(networkError.localizedDescription)")
            default:
                print("An unexpected error occurred: \(error.localizedDescription)")
            }
        }
    }, receiveValue: { userData in
        print("Received user data: \(userData)")
    })
    .store(in: &cancellables)
```

### Understanding the Errors
- **Invalid Response**: Occurs when the server's response doesn't meet the expected criteria, such as an incorrect status code or malformed headers.
- **Decoding Error**: Happens if the JSONDecoder cannot decode the response data into the expected UserDataDTO format.
- **Network Error**: Includes all errors related to connectivity issues, such as timeouts or lack of internet connection.
This approach ensures that your application can gracefully handle different error scenarios, providing a better user experience by dealing with errors appropriately.

</details>
  
<details>
<summary>Mocking HTTPSession for Testing</summary>
You can create a mock session that simulates network responses for testing. This approach is beneficial for unit tests where you want to control the inputs and outputs strictly:

```swift
struct MockSession: HTTPSession {
    func dataTask(for request: URLRequest) -> AnyPublisher<HTTPResponse, URLError> {
        return Fail(error: URLError(.notConnectedToInternet)).eraseToAnyPublisher()
    }
}

// Example of using a mock session:
let mock = HTTPClient(jsonDecoder: JSONDecoder(), session: MockSession())
let real = HTTPClient(jsonDecoder: JSONDecoder(), session: URLSession.shared)
```

</details>

## Examples
- [MoviesAPI Service](https://github.com/silkodenis/swift-combine-networking/tree/main/Examples/MoviesAPI)
- [SwiftUI App](https://github.com/silkodenis/swiftui-moviesdb-redux-app)

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License
This project is licensed under the [Apache License, Version 2.0](LICENSE).

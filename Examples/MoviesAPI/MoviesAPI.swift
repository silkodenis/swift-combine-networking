//
//  MoviesService.swift
//  MoviesAPI
//
//  Created by Denis Silko on 09.04.2024.
//  Copyright © 2024 Denis Silko. All rights reserved.
//

import Foundation
import Combine
import CombineNetworking

protocol MoviesAPI {
    func authentication() -> AnyPublisher<TokenDTO, Error>
    func validation(username: String, password: String, token: String) -> AnyPublisher<TokenDTO, Error>
    func session(with token: String) -> AnyPublisher<SessionDTO, Error>
    func guestSession() -> AnyPublisher<SessionDTO, Error>
    func deleteSession(with id: String) -> AnyPublisher<SessionDTO, Error>
    func configuration() -> AnyPublisher<ConfigurationDTO, Error>
    func trending() -> AnyPublisher<PageDTO<MovieDTO>, Error>
    func movieDetail(id: Int) -> AnyPublisher<MovieDetailDTO, Error>
}

class MoviesAPIService: MoviesAPI {
    typealias Endpoint = MoviesEndpoint
    
    private let client: HTTPClient
    private let builder: HTTPRequestBuilder<Endpoint>
    
    init(httpClient: HTTPClient, requestBuilder: HTTPRequestBuilder<Endpoint>) {
        self.client = httpClient
        self.builder = requestBuilder
    }
    
    func authentication() -> AnyPublisher<TokenDTO, Error> {
        builder.request(.authentication)
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
    
    func validation(username: String, password: String, token: String) -> AnyPublisher<TokenDTO, Error> {
        builder.request(.validation, with: Login(username: username,
                                                 password: password,
                                            request_token: token))
        .flatMap(client.executeJsonRequest)
        .eraseToAnyPublisher()
    }
    
    func session(with token: String) -> AnyPublisher<SessionDTO, Error> {
        builder.request(.session, with: Token(request_token: token))
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
    
    func guestSession() -> AnyPublisher<SessionDTO, Error> {
        builder.request(.guestSession)
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
    
    func deleteSession(with id: String) -> AnyPublisher<SessionDTO, Error> {
        builder.request(.deleteSession, with: Session(session_id: id))
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
    
    func configuration() -> AnyPublisher<ConfigurationDTO, Error> {
        builder.request(.configuration)
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
    
    func trending() -> AnyPublisher<PageDTO<MovieDTO>, Error> {
        builder.request(.trending(.week))
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
    
    func movieDetail(id: Int) -> AnyPublisher<MovieDetailDTO, Error> {
        builder.request(.movieDetail(id: id))
            .flatMap(client.executeJsonRequest)
            .eraseToAnyPublisher()
    }
}

// MARK: - fileprivate inner types

fileprivate extension MoviesAPIService {
    struct Login: Codable {
        let username: String
        let password: String
        let request_token: String
    }
    
    struct Token: Codable {
        let request_token: String
    }
    
    struct Session: Codable {
        let session_id: String
    }
}

import Foundation

public final class HTTPClient {
    public init(
        baseURL: String,
        commonHeaders: [(String, String)] = [],
        dataLoader: DataLoader = .init(),
        errorResponseHandler: ErrorResponseHandler? = nil
    ) {
        self.baseURL = baseURL
        headers = commonHeaders
        self.dataLoader = dataLoader
        self.errorResponseHandler = errorResponseHandler
    }

    public typealias ErrorResponseHandler = (Data, HTTPURLResponse, JSONDecoder) throws -> String

    enum HTTPMethod: String {
        case GET, POST, PUT, PATCH, DELETE
    }

    private let baseURL: String
    private let headers: [(String, String)]
    private let dataLoader: DataLoader
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let errorResponseHandler: ErrorResponseHandler?

    private struct Empty: Decodable {}

    public func get<T: Decodable>(
        from path: String,
        headers: [(String, String)] = [],
        query: [(String, String)] = []
    ) async throws -> T {
        let request = try makeRequest(.GET, path: path, headers: headers, query: query)
        return try await loadData(request)
    }

    public func post<T: Decodable>(
        _ body: some Encodable,
        to path: String,
        headers: [(String, String)] = []
    ) async throws -> T {
        try await perform(.POST, with: body, path: path, headers: headers)
    }

    public func post(
        _ body: some Encodable,
        to path: String,
        headers: [(String, String)] = []
    ) async throws {
        let _: Empty = try await post(body, to: path, headers: headers)
    }

    public func put<T: Decodable>(
        _ body: some Encodable,
        to path: String,
        headers: [(String, String)] = []
    ) async throws -> T {
        try await perform(.PUT, with: body, path: path, headers: headers)
    }

    public func put(
        _ body: some Encodable,
        to path: String,
        headers: [(String, String)] = []
    ) async throws {
        let _: Empty = try await put(body, to: path, headers: headers)
    }

    public func patch<T: Decodable>(
        _ path: String,
        with body: some Encodable,
        headers: [(String, String)] = []
    ) async throws -> T {
        try await perform(.PATCH, with: body, path: path, headers: headers)
    }

    public func patch(
        _ path: String,
        with body: some Encodable,
        headers: [(String, String)] = []
    ) async throws {
        let _: Empty = try await patch(path, with: body, headers: headers)
    }

    public func delete(
        from path: String,
        headers: [(String, String)] = []
    ) async throws {
        let request = try makeRequest(.DELETE, path: path, headers: headers)
        let _: Empty = try await loadData(request)
    }

    private func perform<T: Decodable>(
        _ httpMethod: HTTPMethod,
        with body: some Encodable,
        path: String,
        headers: [(String, String)]
    ) async throws -> T {
        var request = try makeRequest(httpMethod, path: path, headers: headers)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await loadData(request)
    }

    private func makeURL(
        _ path: String,
        query: [(String, String)] = []
    ) throws -> URL {
        guard let baseURL = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        if !query.isEmpty {
            components.queryItems = query.map(URLQueryItem.init)
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func makeRequest(
        _ httpMethod: HTTPMethod,
        path: String,
        headers: [(String, String)],
        query: [(String, String)] = []
    ) throws -> URLRequest {
        let url = try makeURL(path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for header in headers + self.headers {
            request.setValue(header.1, forHTTPHeaderField: header.0)
        }
        return request
    }

    private func loadData<O: Decodable>(_ request: URLRequest) async throws -> O {
        let (data, response) = try await dataLoader.loadData(request)

        switch response.statusCode {
        case 200 ..< 300:
            let _data = data.isEmpty ? Data("{}".utf8) : data
            do {
                return try decoder.decode(O.self, from: _data)
            } catch let error as DecodingError {
                throw ResponseDecodingError(error)
            } catch {
                throw error
            }
        default:
            let message: String = try {
                guard let handler = errorResponseHandler else {
                    return response.description
                }
                return try handler(data, response, decoder)
            }()
            throw ResponseError(statusCode: response.statusCode, message: message)
        }
    }
}

import Foundation

public protocol DataLoaderAuthDelegate: AnyObject {
    func authorize(_ request: inout URLRequest) async throws
    func isUnauthorized(_ response: HTTPURLResponse) -> Bool
    func refreshToken() async throws
}

public extension DataLoaderAuthDelegate {
    func isUnauthorized(_ response: HTTPURLResponse) -> Bool {
        response.statusCode == 401
    }
}

public final class DataLoader {
    public weak var authDelegate: DataLoaderAuthDelegate?

    public init() {}

    private let session = URLSession.shared

    func loadData(_ urlRequest: URLRequest, allowRetry: Bool = true) async throws -> (Data, HTTPURLResponse) {
        var request = urlRequest
        if let authDelegate {
            try await authDelegate.authorize(&request)
        }

        #if DEBUG
        printRequest(request)
        #endif

        let (data, urlResponse): (Data, URLResponse) = try await session.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        #if DEBUG
        printResponse(httpResponse, request: request, data: data)
        #endif

        if allowRetry, let delegate = authDelegate, delegate.isUnauthorized(httpResponse) {
            try await delegate.refreshToken()
            return try await loadData(urlRequest, allowRetry: false)
        }

        return (data, httpResponse)
    }

    #if DEBUG
    private func printRequest(_ request: URLRequest) {
        printKeyedValues([
            (request.httpMethod!, request.url!.absoluteString),
        ], andJson: {
            guard let body = request.httpBody else {
                return nil
            }
            return try? JSONSerialization.jsonObject(with: body)
        }())
    }

    private func printResponse(_ response: HTTPURLResponse, request: URLRequest, data: Data) {
        printKeyedValues([
            (request.httpMethod!, request.url!.absoluteString),
            ("response.statusCode", "\(response.statusCode)"),
        ], andJson: try? JSONSerialization.jsonObject(with: data))
    }

    private func printKeyedValues(_ keyedValues: [(String, String)], andJson json: Any?) {
        print("===")
        for (key, value) in keyedValues {
            print("\(key): \(value)")
        }
        if let json {
            print(json)
        }
        print("===")
    }
    #endif
}

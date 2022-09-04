import Foundation

public final class DataLoader {
    public init() {}

    private let session = URLSession.shared

    func loadData(_ request: URLRequest, allowRetry: Bool = true) async throws -> (Data, HTTPURLResponse) {
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

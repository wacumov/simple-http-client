import Foundation

public struct ResponseError: Error, CustomStringConvertible, LocalizedError {
    public let statusCode: Int
    public let message: String

    public var description: String {
        #if DEBUG
        "code: \(statusCode), message: \(message)"
        #else
        message
        #endif
    }

    public var errorDescription: String? {
        description
    }
}

public struct ResponseDecodingError: Error, CustomStringConvertible, LocalizedError {
    let error: DecodingError

    init(_ error: DecodingError) {
        self.error = error
    }

    public var description: String {
        error.context.debugDescription
    }

    public var errorDescription: String? {
        description
    }
}

private extension DecodingError {
    var context: Context? {
        switch self {
        case let .dataCorrupted(context): context
        case let .keyNotFound(_, context): context
        case let .typeMismatch(_, context): context
        case let .valueNotFound(_, context): context
        @unknown default: nil
        }
    }
}

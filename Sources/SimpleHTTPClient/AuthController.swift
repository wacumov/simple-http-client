import Foundation

public protocol AuthToken {
    var isValid: Bool { get }
    func authorize(_ request: inout URLRequest)
}

public protocol TokenStore {
    associatedtype Token: AuthToken

    func setToken(_ token: Token?) throws
    func getToken() throws -> Token?
}

public protocol TokenRefresher {
    associatedtype Token: AuthToken
    func refresh(_ token: Token) async throws -> Token
}

public enum AuthError: Error {
    case noToken
}

// MARK: - AuthController

public actor AuthController<Token: AuthToken> {
    public init<Store: TokenStore, Refresher: TokenRefresher>(store: Store, refresher: Refresher) where Store.Token == Token, Refresher.Token == Token {
        self.store = AnyTokenStore(store)
        self.refresher = AnyTokenRefresher(refresher)
    }

    public func logIn(_ token: Token) throws {
        refreshTask?.cancel()
        try setToken(token)
    }

    public func logOut() throws {
        refreshTask?.cancel()
        try setToken(nil)
    }

    // MARK: - Private

    private var token: Token?

    private let store: AnyTokenStore<Token>

    private let refresher: AnyTokenRefresher<Token>
    private var refreshTask: Task<Token, Error>?

    private func setToken(_ token: Token?) throws {
        self.token = token
        try store.setToken(token)
    }

    private func getToken() async throws -> Token {
        if let task = refreshTask {
            return try await task.value
        }

        let _token: Token? = try {
            if let token = self.token {
                return token
            }
            self.token = try store.getToken()
            return self.token
        }()

        guard let token = _token else {
            throw AuthError.noToken
        }

        guard token.isValid else {
            return try await refresh(token)
        }
        return token
    }

    private func refresh(_ token: Token) async throws -> Token {
        if let task = refreshTask {
            return try await task.value
        }

        let task: Task<Token, Error> = Task {
            try await refresher.refresh(token)
        }
        refreshTask = task

        do {
            let token = try await task.value
            self.token = token
            try setToken(token)
            refreshTask = nil
            return token
        } catch {
            self.token = nil
            refreshTask = nil
            throw error
        }
    }
}

// MARK: - DataLoaderAuthDelegate

extension AuthController: DataLoaderAuthDelegate {
    public func authorize(_ request: inout URLRequest) async throws {
        let token = try await getToken()
        token.authorize(&request)
    }

    public func refreshToken() async throws {
        let token = try await getToken()
        _ = try await refresh(token)
    }
}

// MARK: - AnyTokenRefresher

private final class AnyTokenRefresher<Token: AuthToken>: TokenRefresher {
    private let _refresh: (Token) async throws -> Token

    init<Refresher: TokenRefresher>(_ refresher: Refresher) where Refresher.Token == Token {
        _refresh = refresher.refresh
    }

    func refresh(_ token: Token) async throws -> Token {
        try await _refresh(token)
    }
}

// MARK: - AnyTokenStore

private final class AnyTokenStore<Token: AuthToken>: TokenStore {
    private let _setToken: (Token?) throws -> Void
    private let _getToken: () throws -> Token?

    init<Store: TokenStore>(_ store: Store) where Store.Token == Token {
        _setToken = store.setToken
        _getToken = store.getToken
    }

    func setToken(_ token: Token?) throws {
        try _setToken(token)
    }

    func getToken() throws -> Token? {
        try _getToken()
    }
}

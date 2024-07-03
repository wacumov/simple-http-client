import SimpleHTTPClient
import XCTest

final class AuthControllerTests: XCTestCase {
    private let store = StoreMock()
    private let refresher = RefresherMock()
    private lazy var sut = AuthController(store: store, refresher: refresher)

    func testNoTokenInStore() async throws {
        await XCTAssertThrowsError(
            try await sut.authorize(&request)
        )
    }

    func testTokenInStore() async throws {
        try store.setToken(validToken)

        await XCTAssertNoThrow(
            try await sut.authorize(&request)
        )
    }

    func testSignIn() async throws {
        try await sut.logIn(validToken)

        await XCTAssertNoThrow(
            try await sut.authorize(&request)
        )
    }

    func testSignOut() async throws {
        try await sut.logIn(validToken)

        try await sut.logOut()

        await XCTAssertThrowsError(
            try await sut.authorize(&request)
        )
    }

    func testStoreAfterSignOut() async throws {
        try await sut.logIn(validToken)

        try await sut.logOut()

        let token = try store.getToken()
        XCTAssertNil(token)
    }

    func testRefresh() async throws {
        let token = invalidRefreshableToken

        try store.setToken(token)

        await XCTAssertNoThrow(
            try await sut.authorize(&request)
        )
    }

    func testRefreshFailure() async throws {
        let token = invalidNonRefreshableToken

        try store.setToken(token)

        await XCTAssertThrowsError(
            try await sut.authorize(&request)
        )
    }

    func testStoreAfterRefresh() async throws {
        let token = invalidRefreshableToken
        try store.setToken(token)

        try await sut.authorize(&request)

        let newToken = try store.getToken()
        XCTAssertNotNil(newToken)
        XCTAssertNotEqual(token.value, newToken?.value)
    }

    func testConcurrentRefresherCalls() async throws {
        try await sut.logIn(invalidRefreshableToken)
        refresher.delay = 10000

        let task1 = Task {
            try await sut.authorize(&request)
        }
        let task2 = Task {
            try await sut.authorize(&request)
        }
        _ = try await (task1.value, task2.value)

        XCTAssertEqual(refresher.refreshCalls, 1)
    }

    func testConsequetiveRefresherCalls() async throws {
        try await sut.logIn(invalidRefreshableToken)
        refresher.delay = 10000

        let task1 = Task {
            try await sut.authorize(&request)
        }
        let task2 = Task {
            try await Task.sleep(nanoseconds: 5000)
            try await sut.authorize(&request)
        }
        _ = try await (task1.value, task2.value)

        XCTAssertEqual(refresher.refreshCalls, 1)
    }

    func testConcurrentRefresherCallsFromDetachedTasks() async throws {
        try await sut.logIn(invalidRefreshableToken)
        refresher.delay = 10000

        let task1 = Task.detached {
            try await self.sut.authorize(&self.request)
        }
        let task2 = Task.detached {
            try await self.sut.authorize(&self.request)
        }
        _ = try await (task1.value, task2.value)

        XCTAssertEqual(refresher.refreshCalls, 1)
    }

    func testConcurrentRefresherCallsFromDifferentQueues() async throws {
        try await sut.logIn(invalidRefreshableToken)
        refresher.delay = 10000

        let expectation1 = XCTestExpectation(), expectation2 = XCTestExpectation()

        DispatchQueue(label: "queue1", qos: .background).async { @Sendable in
            Task.detached {
                try await self.sut.authorize(&self.request)
                expectation1.fulfill()
            }
        }
        DispatchQueue(label: "queue2", qos: .userInitiated).async { @Sendable in
            Task.detached {
                try await self.sut.authorize(&self.request)
                expectation2.fulfill()
            }
        }

        await fulfillment(of: [expectation1, expectation2], timeout: 0.5)
        XCTAssertEqual(refresher.refreshCalls, 1)
    }

    // MARK: -

    private let validToken = TestToken(value: "A", isValid: true, isRefreshable: true)
    private let invalidRefreshableToken = TestToken(value: "B", isValid: false, isRefreshable: true)
    private let invalidNonRefreshableToken = TestToken(value: "B", isValid: false, isRefreshable: false)
    private var request = URLRequest(url: URL(string: "https://a.b")!)
}

// MARK: - TestToken

private struct TestToken: AuthToken {
    let value: String
    let isValid: Bool
    let isRefreshable: Bool

    func authorize(_: inout URLRequest) {}
}

// MARK: - StoreMock

private final class StoreMock: TokenStore {
    typealias Token = TestToken

    var token: TestToken?

    func setToken(_ token: TestToken?) throws {
        self.token = token
    }

    func getToken() throws -> TestToken? {
        token
    }
}

// MARK: - RefresherMock

private final class RefresherMock: TokenRefresher {
    typealias Token = TestToken

    var delay: UInt64?
    var refreshCalls = 0

    func refresh(_ token: TestToken) async throws -> TestToken {
        refreshCalls += 1
        if let delay {
            try await Task.sleep(nanoseconds: delay)
        }
        guard token.isRefreshable else {
            throw Error.couldNotRefreshToken
        }
        return TestToken(value: token.value + "+", isValid: true, isRefreshable: true)
    }

    enum Error: Swift.Error {
        case couldNotRefreshToken
    }
}

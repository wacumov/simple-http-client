import SimpleHTTPClient
import XCTest

final class HTTPClientTests: XCTestCase {
    private lazy var sut = HTTPClient(baseURL: "https://jsonplaceholder.typicode.com")

    func testGet() async throws {
        let posts: [Post] = try await sut.get(from: "/posts")
        XCTAssertFalse(posts.isEmpty)
    }

    func testPost() async throws {
        try await sut.post(Post(title: "a"), to: "/posts")
    }

    func testPut() async throws {
        try await sut.put(Post(title: "a"), to: "/posts/1")
    }

    func testPatch() async throws {
        try await sut.patch("/posts/1", with: Post(title: "a"))
    }

    func testDelete() async throws {
        try await sut.delete(from: "/posts/1")
    }
}

private struct Post: Codable {
    let title: String
}

import Foundation

/// Answers requests by URL path, so tests running in parallel can each register their own route
/// instead of sharing one global handler.
final class RoutedURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: Handler] = [:]

    static func register(path: String, handler: @escaping Handler) {
        lock.withLock { routes[path] = handler }
    }

    static func unregister(path: String) {
        lock.withLock { routes[path] = nil }
    }

    /// A route that always answers `status` with `data`.
    static func respond(path: String, status: Int = 200, data: Data) {
        register(path: path) { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, data)
        }
    }

    /// A route that fails like a dropped connection.
    static func fail(path: String, with error: URLError = URLError(.notConnectedToInternet)) {
        register(path: path) { _ in throw error }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        guard let handler = Self.lock.withLock({ Self.routes[path] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

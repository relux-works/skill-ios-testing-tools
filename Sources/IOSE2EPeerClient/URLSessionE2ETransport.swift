import Foundation

final class URLSessionE2ETransport: UITestE2ETransport, @unchecked Sendable {
    private var task: URLSessionWebSocketTask?

    func connect(url: URL) async throws {
        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    func send(_ text: String) async throws {
        guard let task else {
            throw UITestE2EClientError.unexpectedMessage("notConnected")
        }

        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        guard let task else {
            throw UITestE2EClientError.unexpectedMessage("notConnected")
        }

        let message = try await task.receive()
        switch message {
        case let .string(value):
            return value
        case let .data(value):
            return String(decoding: value, as: UTF8.self)
        @unknown default:
            throw UITestE2EClientError.unexpectedMessage("unknownWebSocketMessage")
        }
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}

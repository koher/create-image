import Foundation
import Network
import os

private let logger = Logger(subsystem: "create-image", category: "connection")

enum TimeoutError: LocalizedError {
    case serverConnection
    case imageCreation

    var errorDescription: String? {
        switch self {
        case .serverConnection:
            "Timeout: could not connect to runner"
        case .imageCreation:
            "Timeout waiting for image generation"
        }
    }
}

extension CreateImage {
    func connectToRunner(port: UInt16, deadline: Date) async throws -> NWConnection {

        while Date() < deadline {
            let connection = NWConnection(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            do {
                try await connect(connection)
                logger.info("Connected to runner")
                return connection
            } catch {
                connection.cancel()
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        throw TimeoutError.serverConnection
    }

    private func connect(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    cont.resume()
                case .waiting(let error):
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                    cont.resume(throwing: error)
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

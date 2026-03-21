import CreateImageLogics
import Foundation
import Network
import os

private let logger = Logger(subsystem: "create-image", category: "launcher")

public struct ImageLauncher: Sendable {
    public let runnerPath: String
    public let port: UInt16
    public let timeout: Int

    public init(runnerPath: String, port: UInt16 = 51573, timeout: Int = 120) {
        self.runnerPath = runnerPath
        self.port = port
        self.timeout = timeout
    }

    public func run(request: ImageRequest) async throws -> ImageResponse {
        // 1. Launch runner binary directly via Process
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))

        logger.info("Launching runner on port \(port)...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: runnerPath)
        process.arguments = ["--port", String(port)]
        try process.run()

        defer {
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
            logger.info("Runner process exited (PID: \(process.processIdentifier))")
        }

        // 2. Connect to runner (retry until it's listening)
        let connection = try await connectToRunner(port: port, deadline: deadline)
        defer { connection.cancel() }

        // 3. Send request
        try await connection.sendMessage(request)
        logger.info("Sent request")

        // 4. Receive response (with timeout)
        let response: ImageResponse = try await withThrowingTaskGroup(of: ImageResponse.self) { group in
            group.addTask {
                try await connection.receiveMessage()
            }
            group.addTask {
                let remaining = deadline.timeIntervalSinceNow
                if remaining > 0 {
                    try await Task.sleep(for: .seconds(remaining))
                }
                throw TimeoutError.imageCreation
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        return response
    }

    // MARK: - TCP Connection

    private func connectToRunner(port: UInt16, deadline: Date) async throws -> NWConnection {
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

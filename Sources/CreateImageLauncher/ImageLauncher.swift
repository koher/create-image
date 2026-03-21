import AppKit
import CreateImageLogics
import Foundation
import Network
import os

private let logger = Logger(subsystem: "create-image", category: "launcher")

public struct ImageLauncher: Sendable {
    public let runnerPath: String
    public let port: UInt16
    public let timeout: Int
    public let keepApp: Bool

    public init(runnerPath: String, port: UInt16 = 51573, timeout: Int = 120, keepApp: Bool = false) {
        self.runnerPath = runnerPath
        self.port = port
        self.timeout = timeout
        self.keepApp = keepApp
    }

    public func run(request: ImageRequest) async throws -> ImageResponse {
        // 1. Create temp .app bundle
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageRunner-\(UUID().uuidString)")
        let appDir = bundleDir.appendingPathComponent("CreateImageRunner.app")
        let contentsDir = appDir.appendingPathComponent("Contents")
        let macOSDir = contentsDir.appendingPathComponent("MacOS")

        let bundleId = UUID().uuidString

        try FileManager.default.createDirectory(
            at: macOSDir, withIntermediateDirectories: true
        )

        defer {
            // Terminate runner process by bundle ID
            let runningApps = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId
            )
            for app in runningApps {
                app.terminate()
                logger.info("Terminated runner process (PID: \(app.processIdentifier))")
            }

            if !keepApp {
                do {
                    try FileManager.default.removeItem(at: bundleDir)
                    logger.info("Cleaned up temp bundle")
                } catch {
                    logger.error("Failed to clean up temp bundle: \(error)")
                }
            } else {
                logger.info("Keeping app at: \(bundleDir.path, privacy: .public)")
            }
        }

        // Copy executable
        let destExecutable = macOSDir.appendingPathComponent("CreateImageRunner")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: runnerPath), to: destExecutable
        )

        // Write Info.plist
        let infoPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CreateImageRunner</string>
    <key>CFBundleIdentifier</key>
    <string>\(bundleId)</string>
    <key>CFBundleName</key>
    <string>CreateImageRunner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
</dict>
</plist>
"""
        try infoPlist.write(
            to: contentsDir.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        logger.info("Created bundle: \(appDir.path, privacy: .public)")

        // 2. Launch runner via Launch Services
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))

        logger.info("Launching app on port \(port)...")
        let launchConfig = NSWorkspace.OpenConfiguration()
        launchConfig.createsNewApplicationInstance = true
        launchConfig.activates = true
        launchConfig.arguments = ["--port", String(port)]
        // NSApplication.shared must be initialized before NSWorkspace can
        // properly launch an app via Launch Services.
        await MainActor.run { _ = NSApplication.shared }
        try await NSWorkspace.shared.openApplication(at: appDir, configuration: launchConfig)

        // 3. Connect to runner (retry until it's listening)
        let connection = try await connectToRunner(port: port, deadline: deadline)
        defer { connection.cancel() }

        // 4. Send request
        try await connection.sendMessage(request)
        logger.info("Sent request")

        // 5. Receive response (with timeout)
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

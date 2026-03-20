import AppKit
import ArgumentParser
import Foundation
import ImageCreatorLogics
import Network
import os

private let logger = Logger(subsystem: "create-image", category: "launcher")

@main
struct CreateImage: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate images using Apple Image Playground"
    )

    @Argument(help: "Text description of the image to generate")
    var prompt: String

    @Option(name: [.short, .long], help: "Output file path")
    var output: String = "output.png"

    @Option(name: [.short, .long], help: "Image style (animation, illustration, sketch)")
    var style: String = "animation"

    @Option(name: [.short, .long], help: "Number of images to generate")
    var limit: Int = 1

    @Option(name: .long, help: "Path to a source image (e.g. a face photo)")
    var sourceImage: String?

    @Option(help: "Max seconds to wait for image generation")
    var timeout: Int = 120

    @Option(name: [.short, .long], help: "TCP port for runner communication")
    var port: UInt16 = 51573

    @Flag(help: "Keep the temporary .app bundle for debugging")
    var keepApp: Bool = false

    func run() async throws {
        let executablePath = Self.autoDetectRunner()
        guard !executablePath.isEmpty else {
            throw ValidationError(
                "Could not find ImageCreatorRunner. Run 'swift build' first."
            )
        }

        // 2. Create temp .app bundle
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageRunner-\(UUID().uuidString)")
        let appDir = bundleDir.appendingPathComponent("ImageCreatorRunner.app")
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
        let destExecutable = macOSDir.appendingPathComponent("ImageCreatorRunner")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: executablePath), to: destExecutable
        )

        // Write Info.plist
        let infoPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ImageCreatorRunner</string>
    <key>CFBundleIdentifier</key>
    <string>\(bundleId)</string>
    <key>CFBundleName</key>
    <string>ImageCreatorRunner</string>
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

        // 3. Launch runner via Launch Services
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

        // 4. Connect to runner (retry until it's listening)
        let connection = try await connectToRunner(port: port, deadline: deadline)
        defer { connection.cancel() }

        // 5. Send request
        let outputPath = URL(fileURLWithPath: output).path
        let sourceImageData: Data?
        if let sourceImage {
            let url = URL(fileURLWithPath: sourceImage)
            sourceImageData = try Data(contentsOf: url)
        } else {
            sourceImageData = nil
        }
        let request = ImageRequest(
            prompt: prompt,
            output: outputPath,
            style: style,
            limit: limit,
            sourceImage: sourceImageData
        )
        try await sendMessage(request, on: connection)
        logger.info("Sent request")

        // 6. Receive response (with timeout)
        let response: ImageResponse = try await withThrowingTaskGroup(of: ImageResponse.self) { group in
            group.addTask {
                try await receiveMessage(from: connection)
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

        // 7. Report result
        if response.success {
            print("Saved: \(response.output ?? output)")
        } else {
            let errorMsg = response.error ?? "unknown"
            if errorMsg.contains("backgroundCreationForbidden") {
                throw CleanExit.message(
                    "ImageCreator rejected generation because the app was not considered foreground/active enough."
                )
            }
            throw CleanExit.message("Error: \(errorMsg)")
        }
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

    // MARK: - Helpers

    private static func autoDetectRunner() -> String {
        let selfURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let sibling = selfURL.deletingLastPathComponent()
            .appendingPathComponent("ImageCreatorRunner")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling.path
        }
        return ""
    }
}

private enum TimeoutError: LocalizedError {
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

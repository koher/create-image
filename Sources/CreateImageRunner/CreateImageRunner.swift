import AppKit
import CreateImageLogics
import ImagePlayground
import Network
import os
import SwiftUI

private let logger = Logger(subsystem: "create-image", category: "runner")

@main
struct CreateImageRunner: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("Generating image...")
                .padding(24)
                .frame(minWidth: 300, minHeight: 100)
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var listener: NWListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        for window in NSApp.windows { window.orderOut(nil) }

        let args = ProcessInfo.processInfo.arguments
        guard let portStr = flagValue(args, "--port"),
              let port = UInt16(portStr)
        else {
            logger.error("Missing --port argument")
            NSApp.terminate(nil)
            return
        }

        startServer(port: port)
    }

    private func startServer(port: UInt16) {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { state in
                logger.info("Listener state: \(String(describing: state), privacy: .public)")
            }
            listener.newConnectionHandler = { connection in
                Task { @MainActor [weak self] in
                    self?.handleConnection(connection)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
            logger.info("Listening on port \(port)")
        } catch {
            logger.error("Failed to start listener: \(error)")
            NSApp.terminate(nil)
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        Task {
            defer {
                connection.cancel()
                NSApp.terminate(nil)
            }

            do {
                let request: ImageRequest = try await receiveMessage(from: connection)
                logger.info("Received request: \(request.prompt, privacy: .public)")
                let response = await processRequest(request)
                try await sendMessage(response, on: connection)
            } catch {
                logger.error("Connection error: \(error)")
            }
        }
    }

    private func processRequest(_ request: ImageRequest) async -> ImageResponse {
        do {
            logger.info("Initializing ImageCreator...")
            let creator = try await ImageCreator()
            logger.info("ImageCreator initialized")

            var concepts: [ImagePlaygroundConcept] = [.text(request.prompt)]
            if let imageData = request.sourceImage,
               let nsImage = NSImage(data: imageData),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            {
                concepts.append(.image(cgImage))
                logger.info("Added source image to concepts")
            }
            let style: ImagePlaygroundStyle = switch request.style {
            case "animation": .animation
            case "illustration": .illustration
            case "sketch": .sketch
            default: .animation
            }

            let maxAttempts = max(1, request.maxRetries)
            var lastError: String = ""

            for attempt in 1...maxAttempts {
                do {
                    logger.info("Starting image generation (attempt \(attempt)/\(maxAttempts))...")
                    let sequence = creator.images(
                        for: concepts,
                        style: style,
                        limit: request.limit
                    )

                    var index = 0
                    for try await created in sequence {
                        index += 1
                        let path = request.limit == 1
                            ? request.output
                            : numberedPath(request.output, index)

                        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
                        try FileManager.default.createDirectory(
                            at: dir, withIntermediateDirectories: true
                        )

                        try saveCGImage(created.cgImage, to: path)
                        logger.info("Saved image \(index): \(path, privacy: .public)")
                    }

                    return ImageResponse(success: true, output: request.output)
                } catch {
                    lastError = "\(type(of: error)).\(error): \(error.localizedDescription)"
                    logger.warning("Attempt \(attempt) failed: \(lastError)")
                    if attempt < maxAttempts {
                        logger.info("Retrying...")
                    }
                }
            }

            logger.error("All \(maxAttempts) attempts failed")
            return ImageResponse(success: false, error: lastError)
        } catch {
            let detail = "\(type(of: error)).\(error): \(error.localizedDescription)"
            logger.error("Error: \(detail)")
            return ImageResponse(success: false, error: detail)
        }
    }
}

// MARK: - Helpers

private func flagValue(_ args: [String], _ flag: String) -> String? {
    guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else {
        return nil
    }
    return args[idx + 1]
}

private func saveCGImage(_ cgImage: CGImage, to path: String) throws {
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw ImageSaveError.pngConversionFailed
    }
    try pngData.write(to: URL(fileURLWithPath: path))
}

private func numberedPath(_ path: String, _ index: Int) -> String {
    let url = URL(fileURLWithPath: path)
    let ext = url.pathExtension
    let base = url.deletingPathExtension().path
    return "\(base)-\(index).\(ext)"
}

private enum ImageSaveError: LocalizedError {
    case pngConversionFailed
    var errorDescription: String? { "Failed to convert image to PNG format" }
}

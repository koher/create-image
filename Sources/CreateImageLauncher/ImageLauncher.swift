import AppKit
import CreateImageLogics
import Foundation
import ImagePlayground
import os

private let logger = Logger(subsystem: "create-image", category: "launcher")

public struct ImageLauncher: Sendable {

    public init() {}

    public func run(request: ImageRequest) async throws -> ImageResponse {
        // Set up NSApplication as a foreground app
        await MainActor.run {
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            app.activate()
        }

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
                            : URL(fileURLWithPath: request.output).numbered(index).path

                        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
                        try FileManager.default.createDirectory(
                            at: dir, withIntermediateDirectories: true
                        )

                        try created.cgImage.savePNG(to: path)
                        logger.info("Saved image \(index): \(path, privacy: .public)")
                    }

                    return ImageResponse(success: true, output: request.output)
                } catch {
                    lastError = "\(type(of: error)).\(error): \(error.localizedDescription)"
                    logger.warning("Attempt \(attempt) failed: \(lastError)")
                }
            }

            return ImageResponse(success: false, error: lastError)
        } catch {
            let detail = "\(type(of: error)).\(error): \(error.localizedDescription)"
            logger.error("Error: \(detail)")
            return ImageResponse(success: false, error: detail)
        }
    }
}

// MARK: - CGImage + PNG

private enum ImageSaveError: LocalizedError {
    case pngConversionFailed
    var errorDescription: String? { "Failed to convert image to PNG format" }
}

extension CGImage {
    fileprivate func savePNG(to path: String) throws {
        let bitmap = NSBitmapImageRep(cgImage: self)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageSaveError.pngConversionFailed
        }
        try pngData.write(to: URL(fileURLWithPath: path))
    }
}

extension URL {
    fileprivate func numbered(_ index: Int) -> URL {
        let ext = pathExtension
        let base = deletingPathExtension().path
        return URL(fileURLWithPath: "\(base)-\(index).\(ext)")
    }
}

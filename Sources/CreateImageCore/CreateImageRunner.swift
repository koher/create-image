import AppKit
import CreateImageLogics
import Foundation
import ImagePlayground
import os

private let logger = Logger(subsystem: "create-image", category: "runner")

public struct CreateImageRunner: Sendable {

    public init() {}

    public func run(request: ImageRequest) async throws -> ImageResponse {
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

                        try created.cgImage.save(to: path, format: request.format, quality: request.quality)
                        logger.info("Saved image \(index): \(path, privacy: .public)")
                    }

                    return .success(output: request.output)
                } catch {
                    lastError = "\(type(of: error)).\(error): \(error.localizedDescription)"
                    logger.warning("Attempt \(attempt) failed: \(lastError)")
                }
            }

            return .failure(error: lastError)
        } catch {
            let detail = "\(type(of: error)).\(error): \(error.localizedDescription)"
            logger.error("Error: \(detail)")
            return .failure(error: detail)
        }
    }
}

// MARK: - CGImage + Save

private enum ImageSaveError: LocalizedError {
    case conversionFailed(OutputFormat)
    var errorDescription: String? {
        switch self {
        case .conversionFailed(let format):
            "Failed to convert image to \(format.rawValue.uppercased()) format"
        }
    }
}

extension CGImage {
    fileprivate func save(to path: String, format: OutputFormat, quality: Double?) throws {
        let bitmap = NSBitmapImageRep(cgImage: self)
        let fileType: NSBitmapImageRep.FileType
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]

        switch format {
        case .png:
            fileType = .png
        case .jpg:
            fileType = .jpeg
            if let quality {
                properties[.compressionFactor] = quality
            }
        }

        guard let data = bitmap.representation(using: fileType, properties: properties) else {
            throw ImageSaveError.conversionFailed(format)
        }
        try data.write(to: URL(fileURLWithPath: path))
    }
}

extension URL {
    fileprivate func numbered(_ index: Int) -> URL {
        let ext = pathExtension
        let base = deletingPathExtension().path
        return URL(fileURLWithPath: "\(base)-\(index).\(ext)")
    }
}

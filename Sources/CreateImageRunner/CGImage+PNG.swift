import AppKit
import Foundation

// MARK: - CGImage + PNG

private enum ImageSaveError: LocalizedError {
    case pngConversionFailed
    var errorDescription: String? { "Failed to convert image to PNG format" }
}

extension CGImage {
    func savePNG(to path: String) throws {
        let bitmap = NSBitmapImageRep(cgImage: self)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageSaveError.pngConversionFailed
        }
        try pngData.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - URL + Numbering

extension URL {
    func numbered(_ index: Int) -> URL {
        let ext = pathExtension
        let base = deletingPathExtension().path
        return URL(fileURLWithPath: "\(base)-\(index).\(ext)")
    }
}

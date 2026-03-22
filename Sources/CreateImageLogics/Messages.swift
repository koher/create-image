import Foundation

public enum OutputFormat: String, Sendable {
    case png
    case jpg
}

public enum ImageRequestError: LocalizedError {
    case qualityOutOfRange(Double)
    case qualityNotApplicable

    public var errorDescription: String? {
        switch self {
        case .qualityOutOfRange(let value):
            "quality must be between 0.0 and 1.0 (got \(value))"
        case .qualityNotApplicable:
            "quality can only be used with jpg format"
        }
    }
}

public struct ImageRequest: Sendable {
    public let prompt: String
    public let output: String
    public let style: String
    public let limit: Int
    public let sourceImage: Data?
    public let maxRetries: Int
    public let format: OutputFormat
    public let quality: Double?

    public init(prompt: String, output: String, style: String, limit: Int, sourceImage: Data? = nil, maxRetries: Int = 3, format: OutputFormat = .png, quality: Double? = nil) throws {
        if let quality {
            guard format == .jpg else {
                throw ImageRequestError.qualityNotApplicable
            }
            guard quality >= 0 && quality <= 1 else {
                throw ImageRequestError.qualityOutOfRange(quality)
            }
        }
        self.prompt = prompt
        self.output = output
        self.style = style
        self.limit = limit
        self.sourceImage = sourceImage
        self.maxRetries = maxRetries
        self.format = format
        self.quality = quality
    }
}

public enum ImageResponse: Sendable {
    case success(output: String)
    case failure(error: String)
}

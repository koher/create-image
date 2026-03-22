import Foundation

public enum OutputFormat: String, Sendable {
    case png
    case jpg
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

    public init(prompt: String, output: String, style: String, limit: Int, sourceImage: Data? = nil, maxRetries: Int = 3, format: OutputFormat = .png, quality: Double? = nil) {
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

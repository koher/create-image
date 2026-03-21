import Foundation

public struct ImageRequest: Sendable {
    public let prompt: String
    public let output: String
    public let style: String
    public let limit: Int
    public let sourceImage: Data?
    public let maxRetries: Int

    public init(prompt: String, output: String, style: String, limit: Int, sourceImage: Data? = nil, maxRetries: Int = 3) {
        self.prompt = prompt
        self.output = output
        self.style = style
        self.limit = limit
        self.sourceImage = sourceImage
        self.maxRetries = maxRetries
    }
}

public enum ImageResponse: Sendable {
    case success(output: String)
    case failure(error: String)
}

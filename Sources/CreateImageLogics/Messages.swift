import Foundation

// MARK: - Messages

public struct ImageRequest: Codable, Sendable {
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

public struct ImageResponse: Codable, Sendable {
    public let success: Bool
    public let output: String?
    public let error: String?

    public init(success: Bool, output: String? = nil, error: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
    }
}

public enum ProtocolError: Error {
    case noData
}

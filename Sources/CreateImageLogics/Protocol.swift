import Foundation
import Network

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

// MARK: - Length-prefixed messaging

public enum ProtocolError: Error {
    case noData
}

public func sendMessage<T: Encodable>(_ value: T, on connection: NWConnection) async throws {
    let data = try JSONEncoder().encode(value)
    var length = UInt32(data.count).bigEndian
    let header = withUnsafeBytes(of: &length) { Data($0) }

    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
        connection.send(content: header + data, completion: .contentProcessed { error in
            if let error { cont.resume(throwing: error) }
            else { cont.resume() }
        })
    }
}

public func receiveMessage<T: Decodable>(
    _: T.Type = T.self, from connection: NWConnection
) async throws -> T {
    let headerData = try await receiveData(exactly: 4, from: connection)
    let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    let body = try await receiveData(exactly: Int(length), from: connection)
    return try JSONDecoder().decode(T.self, from: body)
}

private func receiveData(exactly count: Int, from connection: NWConnection) async throws -> Data {
    try await withCheckedThrowingContinuation { cont in
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
            if let error { cont.resume(throwing: error) }
            else if let data { cont.resume(returning: data) }
            else { cont.resume(throwing: ProtocolError.noData) }
        }
    }
}

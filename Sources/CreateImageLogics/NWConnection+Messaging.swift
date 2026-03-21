import Foundation
import Network

// MARK: - Length-prefixed messaging

extension NWConnection {
    package func sendMessage<T: Encodable>(_ value: T) async throws {
        let data = try JSONEncoder().encode(value)
        var length = UInt32(data.count).bigEndian
        let header = withUnsafeBytes(of: &length) { Data($0) }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            send(content: header + data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    package func receiveMessage<T: Decodable>(
        _: T.Type = T.self
    ) async throws -> T {
        let headerData = try await receiveData(exactly: 4)
        let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let body = try await receiveData(exactly: Int(length))
        return try JSONDecoder().decode(T.self, from: body)
    }

    private func receiveData(exactly count: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let error { cont.resume(throwing: error) }
                else if let data { cont.resume(returning: data) }
                else { cont.resume(throwing: ProtocolError.noData) }
            }
        }
    }
}

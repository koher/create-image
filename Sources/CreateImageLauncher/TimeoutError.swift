import Foundation

public enum TimeoutError: LocalizedError {
    case serverConnection
    case imageCreation

    public var errorDescription: String? {
        switch self {
        case .serverConnection:
            "Timeout: could not connect to runner"
        case .imageCreation:
            "Timeout waiting for image generation"
        }
    }
}

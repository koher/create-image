import CreateImageLauncher
import CreateImageLogics
import Foundation
import Testing

private func findRunnerBinary() throws -> String {
    let sourceFile = URL(fileURLWithPath: #filePath)
    var dir = sourceFile.deletingLastPathComponent()
    while !FileManager.default.fileExists(
        atPath: dir.appendingPathComponent("Package.swift").path
    ) {
        let parent = dir.deletingLastPathComponent()
        guard parent != dir else {
            throw RunnerNotFound()
        }
        dir = parent
    }
    let path = dir.appendingPathComponent(".build/debug/CreateImageRunner").path
    guard FileManager.default.fileExists(atPath: path) else {
        throw RunnerNotFound()
    }
    return path
}

private struct RunnerNotFound: LocalizedError {
    var errorDescription: String? {
        "CreateImageRunner not found. Run 'swift build' first."
    }
}

@Suite
struct ImageLauncherTests {
    @Test func imageGeneration() async throws {
        let runnerPath = try findRunnerBinary()

        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).png")
            .path

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let request = ImageRequest(
            prompt: "a cat sitting on a rainbow",
            output: outputPath,
            style: "animation",
            limit: 1
        )

        let launcher = ImageLauncher(
            runnerPath: runnerPath,
            port: 51574,
            timeout: 120
        )

        let response = try await launcher.run(request: request)

        #expect(response.success)
        #expect(response.error == nil)
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
}

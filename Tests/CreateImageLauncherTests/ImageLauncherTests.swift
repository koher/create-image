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

@Suite(.serialized)
struct ImageLauncherTests {
    private let runnerPath: String

    init() throws {
        runnerPath = try findRunnerBinary()
    }

    // MARK: - Style variations

    @Test(arguments: ["animation", "illustration", "sketch"])
    func style(_ style: String) async throws {
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-style-\(UUID().uuidString).png")
            .path

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let request = ImageRequest(
            prompt: "a blue sky with clouds",
            output: outputPath,
            style: style,
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

    // MARK: - Multiple images

    @Test func multipleImages() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-multi-\(UUID().uuidString).png")

        let outputPath = outputURL.path
        let expectedPaths = [
            URL(fileURLWithPath: outputURL.deletingPathExtension().path + "-1.png").path,
            URL(fileURLWithPath: outputURL.deletingPathExtension().path + "-2.png").path,
        ]

        defer {
            for path in expectedPaths {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        let request = ImageRequest(
            prompt: "a simple star",
            output: outputPath,
            style: "animation",
            limit: 2
        )

        let launcher = ImageLauncher(
            runnerPath: runnerPath,
            port: 51574,
            timeout: 120
        )

        let response = try await launcher.run(request: request)

        #expect(response.success)
        #expect(response.error == nil)
        for path in expectedPaths {
            #expect(FileManager.default.fileExists(atPath: path))
        }
    }

    // MARK: - Output in subdirectory

    @Test func outputInSubdirectory() async throws {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-subdir-\(UUID().uuidString)")
        let outputPath = baseDir
            .appendingPathComponent("nested/output.png")
            .path

        defer { try? FileManager.default.removeItem(at: baseDir) }

        let request = ImageRequest(
            prompt: "a green tree",
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
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    // MARK: - Timeout

    @Test func timeoutOnInvalidRunner() async throws {
        let invalidPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-runner")
            .path

        let launcher = ImageLauncher(
            runnerPath: invalidPath,
            port: 51574,
            timeout: 120
        )

        let request = ImageRequest(
            prompt: "anything",
            output: "/tmp/unused.png",
            style: "animation",
            limit: 1
        )

        await #expect(throws: (any Error).self) {
            try await launcher.run(request: request)
        }
    }
}

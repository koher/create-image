import CreateImageCore
import CreateImageLogics
import Foundation
import Testing

@Suite(.serialized)
struct CreateImageRunnerTests {

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

        let launcher = CreateImageRunner()
        let response = try await launcher.run(request: request)

        guard case .success = response else {
            Issue.record("Expected success, got \(response)")
            return
        }
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

        let launcher = CreateImageRunner()
        let response = try await launcher.run(request: request)

        guard case .success = response else {
            Issue.record("Expected success, got \(response)")
            return
        }
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

        let launcher = CreateImageRunner()
        let response = try await launcher.run(request: request)

        guard case .success = response else {
            Issue.record("Expected success, got \(response)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    // MARK: - Source image

    @Test func sourceImage() async throws {
        let imageURL = Bundle.module.url(forResource: "HumanFace", withExtension: "jpg")!
        let sourceImageData = try Data(contentsOf: imageURL)

        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-face-\(UUID().uuidString).png")
            .path

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let request = ImageRequest(
            prompt: "a person walking in a park",
            output: outputPath,
            style: "animation",
            limit: 1,
            sourceImage: sourceImageData
        )

        let launcher = CreateImageRunner()
        let response = try await launcher.run(request: request)

        guard case .success = response else {
            Issue.record("Expected success, got \(response)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: outputPath))
    }
}

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

        let request = try ImageRequest(
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

        let request = try ImageRequest(
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

        let request = try ImageRequest(
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

    // MARK: - Output format

    @Test func jpgOutput() async throws {
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-jpg-\(UUID().uuidString).jpg")
            .path

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let request = try ImageRequest(
            prompt: "a blue sky",
            output: outputPath,
            style: "animation",
            limit: 1,
            format: .jpg,
            quality: 0.8
        )

        let runner = CreateImageRunner()
        let response = try await runner.run(request: request)

        guard case .success = response else {
            Issue.record("Expected success, got \(response)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: outputPath))

        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        // JPEG files start with FF D8
        #expect(data[0] == 0xFF && data[1] == 0xD8)
    }

    @Test func pngOutput() async throws {
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-png-\(UUID().uuidString).png")
            .path

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let request = try ImageRequest(
            prompt: "a blue sky",
            output: outputPath,
            style: "animation",
            limit: 1,
            format: .png
        )

        let runner = CreateImageRunner()
        let response = try await runner.run(request: request)

        guard case .success = response else {
            Issue.record("Expected success, got \(response)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: outputPath))

        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        // PNG files start with 89 50 4E 47
        #expect(data[0] == 0x89 && data[1] == 0x50)
    }

    // MARK: - Quality validation

    @Test func qualityOutOfRange() {
        #expect(throws: ImageRequestError.self) {
            try ImageRequest(
                prompt: "test", output: "/tmp/test.jpg", style: "animation",
                limit: 1, format: .jpg, quality: 1.5
            )
        }
    }

    @Test func qualityNegative() {
        #expect(throws: ImageRequestError.self) {
            try ImageRequest(
                prompt: "test", output: "/tmp/test.jpg", style: "animation",
                limit: 1, format: .jpg, quality: -0.1
            )
        }
    }

    @Test func qualityWithPng() {
        #expect(throws: ImageRequestError.self) {
            try ImageRequest(
                prompt: "test", output: "/tmp/test.png", style: "animation",
                limit: 1, format: .png, quality: 0.5
            )
        }
    }

    @Test func qualityValidRange() throws {
        let request = try ImageRequest(
            prompt: "test", output: "/tmp/test.jpg", style: "animation",
            limit: 1, format: .jpg, quality: 0.5
        )
        #expect(request.quality == 0.5)
    }

    @Test func qualityOmittedForJpg() throws {
        let request = try ImageRequest(
            prompt: "test", output: "/tmp/test.jpg", style: "animation",
            limit: 1, format: .jpg
        )
        #expect(request.quality == nil)
    }

    // MARK: - Source image

    @Test func sourceImage() async throws {
        let imageURL = Bundle.module.url(forResource: "HumanFace", withExtension: "jpg")!
        let sourceImageData = try Data(contentsOf: imageURL)

        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-face-\(UUID().uuidString).png")
            .path

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let request = try ImageRequest(
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

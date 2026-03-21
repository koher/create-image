import ArgumentParser
import CreateImageLauncher
import CreateImageLogics
import Foundation

@main
struct CreateImage: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate images using Apple Image Playground"
    )

    @Argument(help: "Text description of the image to generate")
    var prompt: String

    @Option(name: [.short, .long], help: "Output file path")
    var output: String = "output.png"

    @Option(name: [.short, .long], help: "Image style (animation, illustration, sketch)")
    var style: String = "animation"

    @Option(name: [.short, .long], help: "Number of images to generate")
    var limit: Int = 1

    @Option(name: .long, help: "Path to a source image (e.g. a face photo)")
    var sourceImage: String?

    @Option(help: "Max retries on image generation failure")
    var retry: Int = 3

    @Option(help: "Max seconds to wait for image generation")
    var timeout: Int = 120

    @Option(name: [.short, .long], help: "TCP port for runner communication")
    var port: UInt16 = 51573

    func run() async throws {
        let runnerPath = Self.autoDetectRunner()
        guard !runnerPath.isEmpty else {
            throw ValidationError(
                "Could not find CreateImageRunner. Run 'swift build' first."
            )
        }

        let outputPath = URL(fileURLWithPath: output).path
        let sourceImageData: Data?
        if let sourceImage {
            sourceImageData = try Data(contentsOf: URL(fileURLWithPath: sourceImage))
        } else {
            sourceImageData = nil
        }

        let request = ImageRequest(
            prompt: prompt,
            output: outputPath,
            style: style,
            limit: limit,
            sourceImage: sourceImageData,
            maxRetries: retry
        )

        let launcher = ImageLauncher(
            runnerPath: runnerPath,
            port: port,
            timeout: timeout
        )

        let response = try await launcher.run(request: request)

        if response.success {
            print("Saved: \(response.output ?? output)")
        } else {
            let errorMsg = response.error ?? "unknown"
            if errorMsg.contains("backgroundCreationForbidden") {
                throw CleanExit.message(
                    "ImageCreator rejected generation because the app was not considered foreground/active enough."
                )
            }
            throw CleanExit.message("Error: \(errorMsg)")
        }
    }

    // MARK: - Helpers

    private static func autoDetectRunner() -> String {
        let selfURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let sibling = selfURL.deletingLastPathComponent()
            .appendingPathComponent("CreateImageRunner")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling.path
        }
        return ""
    }
}

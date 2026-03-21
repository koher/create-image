import ArgumentParser
import CreateImageCore
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

    func run() async throws {
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

        let launcher = CreateImageRunner()
        switch try await launcher.run(request: request) {
        case .success(let output):
            print("Saved: \(output)")
        case .failure(let error):
            throw CleanExit.message("Error: \(error)")
        }
    }
}

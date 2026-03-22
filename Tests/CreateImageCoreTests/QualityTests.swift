import CreateImageLogics
import Testing

@Suite
struct QualityTests {
    @Test func outOfRange() {
        #expect(throws: ImageRequestError.self) {
            try ImageRequest(
                prompt: "test", output: "/tmp/test.jpg", style: "animation",
                limit: 1, format: .jpg, quality: 1.5
            )
        }
    }

    @Test func negative() {
        #expect(throws: ImageRequestError.self) {
            try ImageRequest(
                prompt: "test", output: "/tmp/test.jpg", style: "animation",
                limit: 1, format: .jpg, quality: -0.1
            )
        }
    }

    @Test func withPng() {
        #expect(throws: ImageRequestError.self) {
            try ImageRequest(
                prompt: "test", output: "/tmp/test.png", style: "animation",
                limit: 1, format: .png, quality: 0.5
            )
        }
    }

    @Test func validRange() throws {
        let request = try ImageRequest(
            prompt: "test", output: "/tmp/test.jpg", style: "animation",
            limit: 1, format: .jpg, quality: 0.5
        )
        #expect(request.quality == 0.5)
    }

    @Test func omittedForJpg() throws {
        let request = try ImageRequest(
            prompt: "test", output: "/tmp/test.jpg", style: "animation",
            limit: 1, format: .jpg
        )
        #expect(request.quality == nil)
    }
}

import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectEqual(_ actual: ModelBrand?, _ expected: ModelBrand, _ message: String) {
    guard actual == expected else {
        fail("\(message): expected \(expected.rawValue), got \(actual?.rawValue ?? "nil")")
    }
}

@main
private struct ModelBrandTests {
    static func main() {
        expectEqual(
            ModelBrand.resolve(model: "", providerType: "Codex", provider: "lyclaude-Codex-Pro"),
            .openai,
            "provider type should beat claude in provider name"
        )
        expectEqual(
            ModelBrand.resolve(model: "claude-opus-4.5", providerType: "OpenAI", provider: "lyclaude-Codex-Pro"),
            .openai,
            "provider rows should prefer explicit provider type over model text"
        )
        expectEqual(
            ModelBrand.resolve(model: "claude-opus-4.5", provider: "openai-compatible"),
            .claude,
            "log rows without provider type should prefer actual model text"
        )
        expectEqual(
            ModelBrand.resolve(model: "gpt-5", provider: "claude-proxy"),
            .openai,
            "openai model text should beat claude in provider name"
        )
    }
}

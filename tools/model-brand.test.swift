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

private func expectNil(_ actual: ModelBrand?, _ message: String) {
    guard actual == nil else {
        fail("\(message): expected nil, got \(actual?.rawValue ?? "nil")")
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
        expectEqual(
            ModelBrand.resolve(model: "glm-4-plus"),
            .glm,
            "plain glm-* model text should resolve to glm"
        )
        expectEqual(
            ModelBrand.resolve(model: "chatglm-4"),
            .glm,
            "chatglm-* model text should resolve to glm"
        )
        expectEqual(
            ModelBrand.resolve(model: "", providerType: "ChatGLM", provider: "any"),
            .glm,
            "ChatGLM provider type should resolve to glm"
        )
        expectEqual(
            ModelBrand.resolve(model: "glm-4v", provider: "openai-compatible"),
            .glm,
            "glm model text should beat openai-compatible provider name"
        )
        expectNil(
            ModelBrand.resolve(model: "foo3-router"),
            "plain names ending with 3 should not resolve to OpenAI"
        )
        expectNil(
            ModelBrand.resolve(model: "hello1-provider"),
            "plain names ending with 1 should not resolve to OpenAI"
        )
        expectNil(
            ModelBrand.resolve(model: "gptx-router"),
            "gpt-like prefixes without a boundary should not resolve to OpenAI"
        )
    }
}

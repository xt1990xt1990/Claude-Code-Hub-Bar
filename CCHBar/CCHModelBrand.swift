import Foundation

enum ModelBrand: String {
    case openai
    case claude
    case deepseek
    case glm
    case gemini

    var assetName: String {
        switch self {
        case .openai: return "model-openai"
        case .claude: return "model-claude"
        case .deepseek: return "model-deepseek"
        case .glm: return "model-glm"
        case .gemini: return "model-gemini"
        }
    }

    static func resolve(
        model: String,
        providerType: String = "",
        provider: String = ""
    ) -> ModelBrand? {
        resolveProviderType(providerType)
            ?? resolveModelText(model)
            ?? resolveProviderName(provider)
    }

    private static func resolveProviderType(_ value: String) -> ModelBrand? {
        let text = normalized(value)
        if text.isEmpty { return nil }
        if text.contains("deepseek") { return .deepseek }
        if isGLMText(text) { return .glm }
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if text.contains("openai") || text.contains("codex") { return .openai }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        return nil
    }

    private static func resolveModelText(_ value: String) -> ModelBrand? {
        let text = normalized(value)
        if text.isEmpty { return nil }
        if text.contains("deepseek") { return .deepseek }
        if isGLMText(text) { return .glm }
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        if isOpenAIText(text) { return .openai }
        return nil
    }

    private static func resolveProviderName(_ value: String) -> ModelBrand? {
        let text = normalized(value)
        if text.isEmpty { return nil }
        if text.contains("deepseek") { return .deepseek }
        if isGLMText(text) { return .glm }
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if isOpenAIText(text) { return .openai }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        return nil
    }

    private static func isGLMText(_ text: String) -> Bool {
        text.contains("glm")
            || text.contains("zhipu")
            || text.contains("bigmodel")
    }

    private static func isOpenAIText(_ text: String) -> Bool {
        if text.contains("openai") || text.contains("codex") { return true }
        let tokens = modelTokens(from: text)
        return tokens.contains { token in
            token == "gpt"
                || token.hasPrefix("gpt-")
                || token.range(of: #"^gpt[0-9]"#, options: .regularExpression) != nil
                || token == "o1"
                || token.hasPrefix("o1-")
                || token == "o3"
                || token.hasPrefix("o3-")
                || token == "o4"
                || token.hasPrefix("o4-")
                || token == "o5"
                || token.hasPrefix("o5-")
        }
    }

    private static func modelTokens(from text: String) -> [String] {
        text.split { character in
            !(character.isLetter || character.isNumber || character == "-")
        }
        .map(String.init)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

import Foundation

enum ModelBrand: String {
    case openai
    case claude
    case deepseek
    case gemini

    var assetName: String {
        switch self {
        case .openai: return "model-openai"
        case .claude: return "model-claude"
        case .deepseek: return "model-deepseek"
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
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if text.contains("openai") || text.contains("codex") { return .openai }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        return nil
    }

    private static func resolveModelText(_ value: String) -> ModelBrand? {
        let text = normalized(value)
        if text.isEmpty { return nil }
        if text.contains("deepseek") { return .deepseek }
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        if isOpenAIText(text) { return .openai }
        return nil
    }

    private static func resolveProviderName(_ value: String) -> ModelBrand? {
        let text = normalized(value)
        if text.isEmpty { return nil }
        if text.contains("deepseek") { return .deepseek }
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if isOpenAIText(text) { return .openai }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        return nil
    }

    private static func isOpenAIText(_ text: String) -> Bool {
        text.contains("openai")
            || text.contains("codex")
            || text.contains("gpt")
            || text.contains("o1")
            || text.contains("o3")
            || text.contains("o4")
            || text.contains("o5")
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

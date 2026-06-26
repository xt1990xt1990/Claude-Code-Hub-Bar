import Foundation

struct CCHProviderMiniProbeAverageTTFBInput: Equatable {
    let isEnabled: Bool
    let maxCount: Int
    let samples: [CCHProviderMiniProbeSample]
}

enum CCHProviderMiniProbeMetricsBuilder {
    static func averageTTFB(_ input: CCHProviderMiniProbeAverageTTFBInput) -> Double? {
        guard input.isEnabled else { return nil }
        let samples = input.samples.sorted { $0.createdAt < $1.createdAt }
        return providerMiniProbeAverageSuccessTTFB(
            samples,
            maxCount: input.maxCount,
            isSuccess: { $0.status == .success },
            ttfbMs: { $0.ttfbMs }
        )
    }
}

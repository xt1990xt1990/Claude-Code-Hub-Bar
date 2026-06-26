import Foundation

private let cchProviderDefaultMultiplierQuickValues: [Double] = [0, 0.05, 0.1, 0.2, 0.5, 1, 2]
private let cchProviderUpstreamMultiplierMarkupFactors: [Double] = [1, 1.2, 1.5, 1.8, 2, 2.2, 2.5]

func providerMultiplierQuickValues(upstreamRate: Double?) -> [Double] {
    guard let upstreamRate, upstreamRate > 0 else {
        return cchProviderDefaultMultiplierQuickValues
    }

    var seen: Set<Int> = []
    return cchProviderUpstreamMultiplierMarkupFactors.compactMap { factor in
        let cents = Int((upstreamRate * factor * 100 + 0.000_000_1).rounded())
        guard cents > 0, seen.insert(cents).inserted else { return nil }
        return Double(cents) / 100
    }
}

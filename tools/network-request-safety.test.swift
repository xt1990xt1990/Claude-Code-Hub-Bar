import Darwin
import Foundation

@main
private struct NetworkRequestSafetyTests {
    static func main() async throws {
        try testPollingConfigurationDisablesCaching()
        try await testConcurrentMapHonorsLimit()
    }

    private static func testPollingConfigurationDisablesCaching() throws {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared

        configuration.cchDisableURLCaching()

        try expect(
            configuration.requestCachePolicy == .reloadIgnoringLocalCacheData,
            "polling requests should bypass the local URL cache"
        )
        try expect(configuration.urlCache == nil, "polling sessions should not retain a URL cache")
    }

    private static func testConcurrentMapHonorsLimit() async throws {
        let probe = ConcurrencyProbe()
        let inputs = Array(0..<16)
        let outputs = await cchBoundedConcurrentMap(
            inputs,
            maxConcurrentTasks: CCHUpstreamRequestLimits.maxConcurrentTasks
        ) { value in
            await probe.run(value)
        }

        let peak = await probe.peakConcurrentTasks
        try expect(outputs.sorted() == inputs, "bounded map should process every input exactly once")
        try expect(
            peak <= CCHUpstreamRequestLimits.maxConcurrentTasks,
            "bounded map should never exceed the configured concurrency limit"
        )
        try expect(peak > 1, "bounded map should retain useful parallelism")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw NSError(
                domain: "NetworkRequestSafetyTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}

private actor ConcurrencyProbe {
    private var activeTasks = 0
    private(set) var peakConcurrentTasks = 0

    func run(_ value: Int) async -> Int {
        activeTasks += 1
        peakConcurrentTasks = max(peakConcurrentTasks, activeTasks)
        try? await Task.sleep(nanoseconds: 20_000_000)
        activeTasks -= 1
        return value
    }
}

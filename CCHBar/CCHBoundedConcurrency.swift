import Foundation

enum CCHUpstreamRequestLimits {
    static let maxConcurrentTasks = 4
}

/// Runs a collection of async operations with a fixed number of in-flight tasks.
/// Results are returned in completion order because callers can apply their own ordering.
func cchBoundedConcurrentMap<Input: Sendable, Output: Sendable>(
    _ inputs: [Input],
    maxConcurrentTasks: Int,
    operation: @escaping @Sendable (Input) async -> Output
) async -> [Output] {
    guard !inputs.isEmpty else { return [] }

    let limit = max(1, min(maxConcurrentTasks, inputs.count))
    return await withTaskGroup(of: Output.self) { group in
        var nextIndex = 0
        for _ in 0..<limit {
            let input = inputs[nextIndex]
            nextIndex += 1
            group.addTask {
                await operation(input)
            }
        }

        var outputs: [Output] = []
        outputs.reserveCapacity(inputs.count)
        while let output = await group.next() {
            outputs.append(output)
            guard nextIndex < inputs.count else { continue }
            guard !Task.isCancelled else {
                group.cancelAll()
                continue
            }
            let input = inputs[nextIndex]
            nextIndex += 1
            group.addTask {
                await operation(input)
            }
        }
        return outputs
    }
}

extension URLSessionConfiguration {
    func cchDisableURLCaching() {
        requestCachePolicy = .reloadIgnoringLocalCacheData
        urlCache = nil
    }
}

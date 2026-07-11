# Upstream Wake Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh expired upstream login state once the network is ready after macOS wakes from sleep.

**Architecture:** Add a pure-state coordinator that coalesces duplicate wake/network notifications and decides when one refresh task should run. `MonitorState` reuses its existing `NWPathMonitor`, waits for the existing 1.2-second network-settle window, and calls `refreshUpstreamBalances`, which already renews and persists Sub2API credentials.

**Tech Stack:** Swift, AppKit wake notifications, Network `NWPathMonitor`, Swift concurrency, standalone Swift tests, Xcode macOS Release build.

---

## File Map

- Create `CCHBar/CCHUpstreamWakeRefreshCoordinator.swift`: wake/network scheduling state machine.
- Create `tools/upstream-wake-refresh-coordinator.test.swift`: executable state-transition regression test.
- Modify `CCHBar/MonitorState.swift`: connect wake and network events to one delayed balance refresh.
- Modify `CCHBar.xcodeproj/project.pbxproj`: compile the coordinator in the app target.

### Task 1: Coordinator TDD

**Files:**
- Create: `tools/upstream-wake-refresh-coordinator.test.swift`
- Create: `CCHBar/CCHUpstreamWakeRefreshCoordinator.swift`
- Modify: `CCHBar.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing test**

```swift
import Darwin
import Foundation

@main
private struct UpstreamWakeRefreshCoordinatorTests {
    static func main() {
        var coordinator = CCHUpstreamWakeRefreshCoordinator()
        expect(!coordinator.systemDidWake(networkIsSatisfied: false), "offline wake waits")
        expect(coordinator.hasPendingWake, "offline wake stays pending")
        expect(coordinator.networkDidBecomeSatisfied(), "network restoration schedules")
        expect(!coordinator.networkDidBecomeSatisfied(), "duplicate network event is coalesced")
        expect(
            !coordinator.systemDidWake(networkIsSatisfied: true),
            "duplicate wake is coalesced while scheduled"
        )
        coordinator.refreshDidFinish()
        expect(coordinator.systemDidWake(networkIsSatisfied: true), "later wake schedules again")
        coordinator.refreshDidFinish()
        expect(!coordinator.hasPendingWake, "completion clears pending")
        expect(!coordinator.isRefreshScheduled, "completion clears scheduled")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
```

- [ ] **Step 2: Verify RED**

Run:

```bash
xcrun swiftc tools/upstream-wake-refresh-coordinator.test.swift -o /tmp/upstream-wake-refresh-coordinator.test
```

Expected: `cannot find 'CCHUpstreamWakeRefreshCoordinator' in scope`.

- [ ] **Step 3: Implement the coordinator**

```swift
import Foundation

struct CCHUpstreamWakeRefreshCoordinator {
    static let networkSettleDelayNanoseconds: UInt64 = 1_200_000_000

    private(set) var hasPendingWake = false
    private(set) var isRefreshScheduled = false

    mutating func systemDidWake(networkIsSatisfied: Bool) -> Bool {
        guard !isRefreshScheduled else { return false }
        hasPendingWake = true
        return scheduleIfPossible(networkIsSatisfied: networkIsSatisfied)
    }

    mutating func networkDidBecomeSatisfied() -> Bool {
        scheduleIfPossible(networkIsSatisfied: true)
    }

    mutating func refreshDidFinish() {
        hasPendingWake = false
        isRefreshScheduled = false
    }

    private mutating func scheduleIfPossible(networkIsSatisfied: Bool) -> Bool {
        guard hasPendingWake, networkIsSatisfied, !isRefreshScheduled else { return false }
        hasPendingWake = false
        isRefreshScheduled = true
        return true
    }
}
```

- [ ] **Step 4: Verify GREEN**

```bash
xcrun swiftc CCHBar/CCHUpstreamWakeRefreshCoordinator.swift tools/upstream-wake-refresh-coordinator.test.swift -o /tmp/upstream-wake-refresh-coordinator.test
/tmp/upstream-wake-refresh-coordinator.test
```

Expected: exit 0 with no output.

- [ ] **Step 5: Add the file to Xcode**

Add build file `A1000036` referring to file reference `A2000036`, add `A2000036` to the CCHBar group, and add `A1000036` to Sources:

```text
A1000036 = {isa = PBXBuildFile; fileRef = A2000036; };
A2000036 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CCHUpstreamWakeRefreshCoordinator.swift; sourceTree = "<group>"; };
```

### Task 2: MonitorState wiring

**Files:**
- Modify: `CCHBar/MonitorState.swift:290-313`
- Modify: `CCHBar/MonitorState.swift:563-576`
- Modify: `CCHBar/MonitorState.swift:1343-1353`
- Modify: `CCHBar/MonitorState.swift:2281-2313`

- [ ] **Step 1: Add state and teardown**

Add:

```swift
private var upstreamWakeRefreshCoordinator = CCHUpstreamWakeRefreshCoordinator()
private var upstreamWakeRefreshTask: Task<Void, Never>?
```

Cancel `upstreamWakeRefreshTask` in `deinit`.

- [ ] **Step 2: Connect the network-ready event**

After the existing mini-probe resume call in the `.satisfied` transition, add:

```swift
self.runUpstreamBalanceRefreshAfterNetworkRestoredIfNeeded()
```

- [ ] **Step 3: Connect the wake event**

After existing wake actions, add:

```swift
self.runUpstreamBalanceRefreshAfterSystemResumeIfNeeded()
```

- [ ] **Step 4: Add scheduling methods**

```swift
private func runUpstreamBalanceRefreshAfterSystemResumeIfNeeded() {
    let shouldSchedule = upstreamWakeRefreshCoordinator.systemDidWake(
        networkIsSatisfied: providerMiniProbeNetworkStatus == .satisfied
    )
    guard shouldSchedule else { return }
    scheduleUpstreamBalanceRefreshAfterSystemResume()
}

private func runUpstreamBalanceRefreshAfterNetworkRestoredIfNeeded() {
    guard upstreamWakeRefreshCoordinator.networkDidBecomeSatisfied() else { return }
    scheduleUpstreamBalanceRefreshAfterSystemResume()
}

private func scheduleUpstreamBalanceRefreshAfterSystemResume() {
    guard upstreamWakeRefreshTask == nil else { return }
    upstreamWakeRefreshTask = Task { @MainActor [weak self] in
        try? await Task.sleep(
            nanoseconds: CCHUpstreamWakeRefreshCoordinator.networkSettleDelayNanoseconds
        )
        guard let self, !Task.isCancelled else { return }
        await self.refreshUpstreamBalances(silent: true)
        self.upstreamWakeRefreshCoordinator.refreshDidFinish()
        self.upstreamWakeRefreshTask = nil
    }
}
```

- [ ] **Step 5: Verify coordinator and whitespace**

```bash
xcrun swiftc CCHBar/CCHUpstreamWakeRefreshCoordinator.swift tools/upstream-wake-refresh-coordinator.test.swift -o /tmp/upstream-wake-refresh-coordinator.test
/tmp/upstream-wake-refresh-coordinator.test
git diff --check
```

Expected: all commands exit 0.

### Task 3: Verification, install, restart

**Files:**
- Verify: coordinator plus existing upstream auth suites
- Build: `CCHBar.xcodeproj`
- Install: `/Applications/Claude Code Hub Bar.app`

- [ ] **Step 1: Run Swift regressions**

```bash
xcrun swiftc CCHBar/CCHUpstreamWakeRefreshCoordinator.swift tools/upstream-wake-refresh-coordinator.test.swift -o /tmp/upstream-wake-refresh-coordinator.test
/tmp/upstream-wake-refresh-coordinator.test
xcrun swiftc CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-cloudflare-challenge.test.swift -o /tmp/upstream-rate-cloudflare-challenge.test
/tmp/upstream-rate-cloudflare-challenge.test
xcrun swiftc CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-sub2-cloudflare-cookie.test.swift -o /tmp/upstream-rate-sub2-cloudflare-cookie.test
/tmp/upstream-rate-sub2-cloudflare-cookie.test
xcrun swiftc CCHBar/UpstreamRateModels.swift tools/upstream-rate-stale-snapshot.test.swift -o /tmp/upstream-rate-stale-snapshot.test
/tmp/upstream-rate-stale-snapshot.test
```

Expected: all four executables exit 0.

- [ ] **Step 2: Run Node regressions**

```bash
node --test tools/new-api-rate-watch/core.test.mjs tools/sub2-rate-watch/core.test.mjs
```

Expected: 11 tests pass and zero fail.

- [ ] **Step 3: Build Release**

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Release -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Install and restart**

Quit `app.cchbar.CCHBar`, stage the signed Release app under `/Applications`, atomically replace `/Applications/Claude Code Hub Bar.app`, launch it, then verify exactly one process:

```bash
open -na '/Applications/Claude Code Hub Bar.app'
pgrep -fl '^/Applications/Claude Code Hub Bar.app/Contents/MacOS/Claude Code Hub Bar$'
```

- [ ] **Step 5: Commit**

```bash
git add CCHBar/CCHUpstreamWakeRefreshCoordinator.swift CCHBar/MonitorState.swift CCHBar.xcodeproj/project.pbxproj tools/upstream-wake-refresh-coordinator.test.swift docs/superpowers/plans/2026-07-11-upstream-wake-refresh.md
git commit -m "Refresh upstream login state after wake"
```

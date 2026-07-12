# Provider Search Focus Dismissal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dismiss the Providers tab's search-field focus after any click outside the complete search control while retaining the query and preserving the clicked control's normal behavior.

**Architecture:** A pure geometry policy decides whether a tap should dismiss focus. `ProvidersTabView` owns transient SwiftUI focus state, measures the search control in a named coordinate space, and observes a simultaneous spatial tap without intercepting group chips, provider rows, or other controls.

**Tech Stack:** Swift 5, SwiftUI on macOS 14, Foundation geometry types, standalone `swiftc` tests, Xcode Debug build.

---

### Task 1: Add the pure focus-dismissal policy

**Files:**
- Create: `CCHBar/CCHProviderSearchFocusPolicy.swift`
- Create: `tools/provider-search-focus-policy.test.swift`
- Modify: `CCHBar.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing standalone policy test**

Create `tools/provider-search-focus-policy.test.swift`:

```swift
import Darwin
import Foundation

@main
private struct ProviderSearchFocusPolicyTests {
    static func main() {
        let searchFrame = CGRect(x: 100, y: 20, width: 150, height: 28)

        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: true,
                searchFrame: searchFrame,
                tapLocation: CGPoint(x: 90, y: 30)
            ),
            true,
            "a focused search should dismiss after an outside tap"
        )
        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: true,
                searchFrame: searchFrame,
                tapLocation: CGPoint(x: 125, y: 30)
            ),
            false,
            "a tap inside the complete search control should keep focus"
        )
        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: false,
                searchFrame: searchFrame,
                tapLocation: CGPoint(x: 90, y: 30)
            ),
            false,
            "an unfocused search needs no dismissal"
        )
        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: true,
                searchFrame: .zero,
                tapLocation: CGPoint(x: 90, y: 30)
            ),
            false,
            "an unavailable layout frame must not dismiss focus"
        )
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
```

- [ ] **Step 2: Run the policy test and verify RED**

Run:

```bash
xcrun swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-policy.test.swift -o /tmp/provider-search-focus-policy.test
```

Expected: compilation fails because `CCHBar/CCHProviderSearchFocusPolicy.swift` does not exist.

- [ ] **Step 3: Implement the minimal policy**

Create `CCHBar/CCHProviderSearchFocusPolicy.swift`:

```swift
import Foundation

enum CCHProviderSearchFocusPolicy {
    static func shouldDismiss(
        isFocused: Bool,
        searchFrame: CGRect,
        tapLocation: CGPoint
    ) -> Bool {
        isFocused && !searchFrame.isEmpty && !searchFrame.contains(tapLocation)
    }
}
```

- [ ] **Step 4: Add the source to the Xcode target**

Add the following project entries after the existing `A1000037` and `A2000037` entries:

```text
A1000038 = {isa = PBXBuildFile; fileRef = A2000038; };
A2000038 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CCHProviderSearchFocusPolicy.swift; sourceTree = "<group>"; };
```

Add `A2000038` to the `A5000002` CCHBar group and `A1000038` to the `A7000001` Sources build phase.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
xcrun swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-policy.test.swift -o /tmp/provider-search-focus-policy.test
/tmp/provider-search-focus-policy.test
```

Expected: both commands exit 0 with no failure output.

- [ ] **Step 6: Check and commit the policy checkpoint**

Run:

```bash
git diff --check -- CCHBar/CCHProviderSearchFocusPolicy.swift CCHBar.xcodeproj/project.pbxproj tools/provider-search-focus-policy.test.swift
git add CCHBar/CCHProviderSearchFocusPolicy.swift CCHBar.xcodeproj/project.pbxproj tools/provider-search-focus-policy.test.swift
git commit -m "Add provider search focus policy"
```

Expected: the diff check exits 0 and the commit contains only the policy, its test, and Xcode target registration.

### Task 2: Connect outside taps to SwiftUI focus

**Files:**
- Modify: `CCHBar/MenuBarView.swift:1340-1425`

- [ ] **Step 1: Define the coordinate-space and frame preference types**

Immediately before `ProvidersTabView`, add:

```swift
private enum ProviderSearchFocusLayout {
    static let coordinateSpaceName = "provider-search-focus"
}

private struct ProviderSearchFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
```

- [ ] **Step 2: Own focus and the measured frame in `ProvidersTabView`**

Add state directly below `@ObservedObject var state`:

```swift
@FocusState private var isProviderSearchFocused: Bool
@State private var providerSearchFrame: CGRect = .zero
```

Replace the current search-field call with:

```swift
ProviderNameSearchField(
    text: $state.providerSearchText,
    isFocused: $isProviderSearchFocused
)
.background {
    GeometryReader { proxy in
        Color.clear.preference(
            key: ProviderSearchFramePreferenceKey.self,
            value: proxy.frame(in: .named(ProviderSearchFocusLayout.coordinateSpaceName))
        )
    }
}
```

- [ ] **Step 3: Observe all Providers-tab taps without intercepting controls**

Apply these modifiers to the outer `VStack` in `ProvidersTabView`:

```swift
.coordinateSpace(name: ProviderSearchFocusLayout.coordinateSpaceName)
.onPreferenceChange(ProviderSearchFramePreferenceKey.self) { frame in
    providerSearchFrame = frame
}
.contentShape(Rectangle())
.simultaneousGesture(
    SpatialTapGesture(coordinateSpace: .named(ProviderSearchFocusLayout.coordinateSpaceName))
        .onEnded { tap in
            guard CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: isProviderSearchFocused,
                searchFrame: providerSearchFrame,
                tapLocation: tap.location
            ) else { return }
            isProviderSearchFocused = false
        }
)
```

The simultaneous gesture must remain on the outer tab container so group chips, provider-row controls, blank spacing, and the “打开” button all dismiss focus while receiving their original click.

- [ ] **Step 4: Bind the `TextField` to the parent focus state**

Extend `ProviderNameSearchField` with the focus binding:

```swift
private struct ProviderNameSearchField: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    @Environment(\.cchTheme) private var theme
```

Apply it to the existing `TextField`:

```swift
TextField("搜索渠道", text: $text)
    .focused(isFocused)
    .textFieldStyle(.plain)
    .font(.system(size: 11, weight: .medium))
```

- [ ] **Step 5: Verify the focused policy and complete app build**

Run:

```bash
xcrun swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-policy.test.swift -o /tmp/provider-search-focus-policy.test
/tmp/provider-search-focus-policy.test
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug build -quiet
```

Expected: the test and macOS Debug build exit 0. The known local CoreSimulator version warning is acceptable because the macOS target completes successfully.

- [ ] **Step 6: Check and commit the UI checkpoint**

Run:

```bash
git diff --check -- CCHBar/MenuBarView.swift
git add CCHBar/MenuBarView.swift
git commit -m "Dismiss provider search focus on outside click"
```

Expected: the diff check exits 0 and the commit contains only the focus wiring in `MenuBarView.swift`.

### Task 3: Full verification and local Debug replacement

**Files:**
- Verify all source and test files
- Replace: `/Applications/Claude Code Hub Bar.app`

- [ ] **Step 1: Run all 18 standalone Swift tests**

Run:

```bash
set -euo pipefail
run_swift_test() {
  local name="$1"
  shift
  xcrun swiftc "$@" -o "/tmp/$name.test"
  "/tmp/$name.test"
}

run_swift_test active-session-refresh-interval CCHBar/CCHActiveSessionRefreshInterval.swift tools/active-session-refresh-interval.test.swift
run_swift_test display-sanitizer CCHBar/CCHDisplaySanitizer.swift tools/display-sanitizer.test.swift
run_swift_test model-brand CCHBar/CCHModelBrand.swift tools/model-brand.test.swift
run_swift_test provider-dispatch-settings CCHBar/CCHProviderDispatchSettings.swift tools/provider-dispatch-settings.test.swift
run_swift_test provider-mini-probe-timing CCHBar/CCHProviderMiniProbeTiming.swift tools/provider-mini-probe-timing.test.swift
run_swift_test provider-model-test-parser CCHBar/CCHProviderModelTestParser.swift tools/provider-model-test-parser.test.swift
run_swift_test provider-multiplier-presets CCHBar/CCHProviderMultiplierPresets.swift tools/provider-multiplier-presets.test.swift
run_swift_test provider-name-search CCHBar/CCHProviderNameSearch.swift tools/provider-name-search.test.swift
run_swift_test provider-search-focus-policy CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-policy.test.swift
run_swift_test refresh-freshness-policy CCHBar/CCHStatusBarPollingPolicy.swift tools/refresh-freshness-policy.test.swift
run_swift_test status-bar-polling-policy CCHBar/CCHStatusBarPollingPolicy.swift tools/status-bar-polling-policy.test.swift
run_swift_test status-bar-snapshot CCHBar/CCHDisplaySanitizer.swift CCHBar/CCHProviderDispatchSettings.swift CCHBar/CCHProviderModelTestParser.swift CCHBar/APIService.swift tools/status-bar-snapshot.test.swift
run_swift_test upstream-rate-auto-sync-timing CCHBar/UpstreamRateAutoSyncTiming.swift tools/upstream-rate-auto-sync-timing.test.swift
run_swift_test upstream-rate-cloudflare-challenge CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-cloudflare-challenge.test.swift
run_swift_test upstream-rate-inventory CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-inventory.test.swift
run_swift_test upstream-rate-stale-snapshot CCHBar/UpstreamRateModels.swift tools/upstream-rate-stale-snapshot.test.swift
run_swift_test upstream-rate-sub2-cloudflare-cookie CCHBar/UpstreamRateModels.swift CCHBar/UpstreamRateCredentials.swift CCHBar/UpstreamRateService.swift CCHBar/UpstreamRateBrowserAuth.swift tools/upstream-rate-sub2-cloudflare-cookie.test.swift
run_swift_test upstream-wake-refresh-coordinator CCHBar/CCHUpstreamWakeRefreshCoordinator.swift tools/upstream-wake-refresh-coordinator.test.swift
printf 'Swift standalone tests: 18/18\n'
```

Expected: all 18 executables exit 0 and the final count is `18/18`.

- [ ] **Step 2: Run both Node test suites**

Run:

```bash
node --test tools/new-api-rate-watch/core.test.mjs tools/sub2-rate-watch/core.test.mjs
```

Expected: 11 tests pass and 0 fail.

- [ ] **Step 3: Run final formatting and clean Debug build checks**

Run:

```bash
git diff --check
git status --short
rm -rf /tmp/CCHBarFinalDerivedData
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug -derivedDataPath /tmp/CCHBarFinalDerivedData clean build -quiet
```

Expected: no formatting errors, a clean worktree after the implementation commits, and a successful macOS Debug build. The known CoreSimulator warning remains non-blocking.

- [ ] **Step 4: Replace and restart the single local Debug app**

Run:

```bash
set -euo pipefail
product="/tmp/CCHBarFinalDerivedData/Build/Products/Debug/Claude Code Hub Bar.app"
installed="/Applications/Claude Code Hub Bar.app"
product_hash="$(shasum -a 256 "$product/Contents/MacOS/Claude Code Hub Bar" | awk '{print $1}')"
old_pids="$(pgrep -f '^/Applications/Claude Code Hub Bar[.]app/Contents/MacOS/Claude Code Hub Bar$' || true)"
if [[ -n "$old_pids" ]]; then
  kill $old_pids
fi
rm -rf "$installed"
ditto "$product" "$installed"
codesign --verify --deep --strict --verbose=2 "$installed"
installed_hash="$(shasum -a 256 "$installed/Contents/MacOS/Claude Code Hub Bar" | awk '{print $1}')"
[[ "$product_hash" == "$installed_hash" ]]
find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name 'Claude Code Hub Bar.app' -prune -exec rm -rf '{}' '+'
rm -rf /tmp/CCHBarFinalDerivedData
open "$installed"
```

Expected: signature validation succeeds, installed and built executable hashes match, build-product duplicates are removed, and the `/Applications` copy launches.

- [ ] **Step 5: Verify the process and unique app count**

Run:

```bash
pgrep -fl '^/Applications/Claude Code Hub Bar[.]app/Contents/MacOS/Claude Code Hub Bar$'
mdfind "kMDItemCFBundleIdentifier == 'app.cchbar.CCHBar'" | while IFS= read -r app; do test -d "$app" && printf '%s\n' "$app"; done | sort -u
find /Applications "$HOME/Applications" "$HOME/Library/Developer/Xcode/DerivedData" /tmp -type d -name 'Claude Code Hub Bar.app' -prune 2>/dev/null | sort -u
```

Expected: one running process from `/Applications/Claude Code Hub Bar.app` and exactly that one existing app bundle.

- [ ] **Step 6: Manual behavior check**

Open the Providers tab, focus the search field, and verify each case:

1. Click a group chip: the group changes and the blue insertion caret disappears while the query remains.
2. Click a provider row control: the control still works and the caret disappears.
3. Click blank space or the statistics area: the caret disappears and the query remains.
4. Click inside the field or its clear button: the outside-tap policy does not dismiss that internal interaction.

# Provider Name Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an immediate provider-name search field immediately left of the Providers tab's “打开” button, filtering only providers already included by the selected group chips.

**Architecture:** A small pure `CCHProviderNameSearch` utility owns normalization and name matching. `MonitorState` keeps the transient query and rebuilds the existing `CCHProviderFilterSnapshot` in the order group filter → provider ordering → name filter, so searching cannot corrupt the stored provider order. `ProvidersTabView` only renders and binds the compact search control.

**Tech Stack:** Swift 6, SwiftUI for macOS, existing standalone `swiftc` tests, Xcode Debug build.

---

### Task 1: Pure provider-name filtering

**Files:**
- Create: `CCHBar/CCHProviderNameSearch.swift`
- Create: `tools/provider-name-search.test.swift`
- Modify: `CCHBar.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing standalone test**

Create `tools/provider-name-search.test.swift`:

```swift
import Darwin
import Foundation

private struct Item {
    let id: Int
    let name: String
}

@main
private struct ProviderNameSearchTests {
    static func main() {
        let items = [
            Item(id: 1, name: "K12-Codex"),
            Item(id: 2, name: "codex plus"),
            Item(id: 3, name: "Café Claude")
        ]

        expectEqual(
            CCHProviderNameSearch.filter(items, query: "  CODEX ", name: \.name).map(\.id),
            [1, 2],
            "search should trim whitespace and ignore case"
        )
        expectEqual(
            CCHProviderNameSearch.filter(items, query: "cafe", name: \.name).map(\.id),
            [3],
            "search should ignore diacritics"
        )
        expectEqual(
            CCHProviderNameSearch.filter(items, query: "   ", name: \.name).map(\.id),
            [1, 2, 3],
            "blank search should preserve the input"
        )
        expectEqual(
            CCHProviderNameSearch.filter([items[1]], query: "codex", name: \.name).map(\.id),
            [2],
            "search should never add values outside its group-filtered input"
        )
        expectEqual(CCHProviderNameSearch.isActive("  "), false, "blank search should be inactive")
        expectEqual(CCHProviderNameSearch.isActive(" codex "), true, "text search should be active")
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
xcrun swiftc CCHBar/CCHProviderNameSearch.swift tools/provider-name-search.test.swift -o /tmp/provider-name-search.test
```

Expected: compilation fails because `CCHBar/CCHProviderNameSearch.swift` does not exist.

- [ ] **Step 3: Implement the minimal pure filter**

Create `CCHBar/CCHProviderNameSearch.swift`:

```swift
import Foundation

enum CCHProviderNameSearch {
    static func isActive(_ query: String) -> Bool {
        !normalized(query).isEmpty
    }

    static func filter<Value>(
        _ values: [Value],
        query: String,
        name: (Value) -> String
    ) -> [Value] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return values }
        return values.filter { normalized(name($0)).contains(needle) }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
```

- [ ] **Step 4: Add the source to the Xcode target**

Add `A1000037`/`A2000037` entries to the PBX build-file and file-reference sections, add `A2000037` to the `CCHBar` group, and add `A1000037` to `A7000001` Sources:

```text
A1000037 = {isa = PBXBuildFile; fileRef = A2000037; };
A2000037 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CCHProviderNameSearch.swift; sourceTree = "<group>"; };
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
xcrun swiftc CCHBar/CCHProviderNameSearch.swift tools/provider-name-search.test.swift -o /tmp/provider-name-search.test
/tmp/provider-name-search.test
```

Expected: both commands exit 0 with no failure output.

- [ ] **Step 6: Record the checkpoint without staging shared dirty files**

Run:

```bash
git diff --check -- CCHBar/CCHProviderNameSearch.swift CCHBar.xcodeproj/project.pbxproj tools/provider-name-search.test.swift
```

Expected: exit 0. Do not commit at this checkpoint because the shared worktree contains pre-existing uncommitted performance work.

### Task 2: Integrate search into provider state

**Files:**
- Modify: `CCHBar/APIService.swift:288-293`
- Modify: `CCHBar/MonitorState.swift:191-205`
- Modify: `CCHBar/MonitorState.swift:2580-2615`

- [ ] **Step 1: Extend the filter snapshot with pre-search group count**

Update `CCHProviderFilterSnapshot`:

```swift
struct CCHProviderFilterSnapshot: Equatable {
    var groups: [String] = ["全部"]
    var providers: [CCHProvider] = []
    var groupProviderCount = 0
    var enabledCount = 0
    var unhealthyCount = 0
}
```

- [ ] **Step 2: Add transient query state and empty-state text**

Add alongside `selectedProviderGroups`:

```swift
@Published var providerSearchText = "" {
    didSet {
        guard providerSearchText != oldValue else { return }
        rebuildProviderFilterSnapshot()
    }
}
```

Add alongside the filtered provider count accessors:

```swift
var providerEmptyStateText: String {
    if providerFilterSnapshot.groupProviderCount > 0,
       CCHProviderNameSearch.isActive(providerSearchText) {
        return "没有匹配的渠道"
    }
    return "暂无渠道"
}
```

- [ ] **Step 3: Apply name search after full group ordering**

Refactor `rebuildProviderFilterSnapshot` so `providerSortState` always receives the entire selected-group result, then search that ordered result:

```swift
let groupFiltered: [CCHProvider]
if selectedProviderGroups.isEmpty {
    groupFiltered = providers
} else {
    groupFiltered = providers.filter { provider in
        displayGroupTitles(for: provider).contains { selectedProviderGroups.contains($0) }
    }
}

let orderedGroupProviders = providerSortState.order(groupFiltered, mode: sortMode) { provider in
    CCHProviderSortDescriptor(
        id: provider.id,
        isEnabled: provider.isEnabled,
        hasMiniProbe: providerMiniProbeSelectedProviderIds.contains(provider.id),
        isPinned: pinnedProviderIds.contains(provider.id)
    )
}
let filtered = CCHProviderNameSearch.filter(
    orderedGroupProviders,
    query: providerSearchText,
    name: \.name
)
```

Count `enabledCount` and `unhealthyCount` from `filtered`, remove the old second sort call, and construct the snapshot with `groupProviderCount: groupFiltered.count`.

- [ ] **Step 4: Compile the complete app**

Run:

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug build -quiet
```

Expected: exit 0. The known local CoreSimulator-version warning is acceptable because the macOS target builds successfully.

- [ ] **Step 5: Record the checkpoint without committing overlapping files**

Run:

```bash
git diff --check -- CCHBar/APIService.swift CCHBar/MonitorState.swift
```

Expected: exit 0. Do not commit because `MonitorState.swift` already contains pre-existing uncommitted performance changes.

### Task 3: Add the compact right-side search field

**Files:**
- Modify: `CCHBar/MenuBarView.swift:1340-1378`

- [ ] **Step 1: Place the search field before “打开”**

Update the Providers top row:

```swift
Spacer()
ProviderNameSearchField(text: $state.providerSearchText)
PanelLinkButton(title: "打开") {
    state.openCCH("/zh-CN/dashboard/providers")
}
```

- [ ] **Step 2: Use state-derived empty text**

Update the empty state:

```swift
if state.filteredProviders.isEmpty {
    EmptyStateView(text: state.providerEmptyStateText)
}
```

- [ ] **Step 3: Implement the compact search control**

Add near `ProvidersTabView`:

```swift
private struct ProviderNameSearchField: View {
    @Binding var text: String
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
            TextField("搜索渠道", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("清空搜索")
            }
        }
        .padding(.horizontal, 8)
        .frame(width: 150, height: 28)
        .background(theme.control)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border.opacity(0.5), lineWidth: 0.8)
        }
    }
}
```

- [ ] **Step 4: Build after the UI change**

Run:

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug build -quiet
```

Expected: exit 0 with only the known non-blocking CoreSimulator warning.

- [ ] **Step 5: Record the UI checkpoint**

Run:

```bash
git diff --check -- CCHBar/MenuBarView.swift
```

Expected: exit 0. Do not commit because this file already contains pre-existing uncommitted performance changes.

### Task 4: Full verification and local Debug installation

**Files:**
- Verify all modified source and test files
- Replace: `/Applications/Claude Code Hub Bar.app`

- [ ] **Step 1: Run all standalone Swift tests**

Compile and run the existing 16 Swift tests plus `tools/provider-name-search.test.swift` with their corresponding source dependencies.

Expected: 17/17 executables exit 0.

- [ ] **Step 2: Run Node rate-watch tests**

Run:

```bash
node --test tools/new-api-rate-watch/core.test.mjs tools/sub2-rate-watch/core.test.mjs
```

Expected: 11 tests pass, 0 fail.

- [ ] **Step 3: Run formatting and final Debug build checks**

Run:

```bash
git diff --check
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug build -quiet
```

Expected: both commands exit 0; the known CoreSimulator warning is non-blocking.

- [ ] **Step 4: Install exactly one latest Debug app**

Copy the verified Debug product to `/Applications/Claude Code Hub Bar.app`, verify its code signature and executable hash, remove DerivedData Debug/Release `.app` duplicates, and launch the `/Applications` copy.

- [ ] **Step 5: Verify the running app and duplicate count**

Run process, Spotlight, and filesystem checks.

Expected: one running process from `/Applications/Claude Code Hub Bar.app`, and exactly one indexed/local app bundle with bundle identifier `app.cchbar.CCHBar`.

- [ ] **Step 6: Manual interaction check**

Open the Providers tab and confirm: the field is immediately left of “打开”; typing filters only the selected group; stats update; switching groups preserves the query; the clear button restores the selected group; empty results use the specified text.

- [ ] **Step 7: Preserve the working tree for user review**

Run:

```bash
git status --short
```

Expected: the feature and pre-existing performance changes remain visible for user review. Do not commit shared implementation files without explicit user instruction.

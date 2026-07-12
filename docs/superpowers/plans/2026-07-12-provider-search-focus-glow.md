# Provider Search Focus Glow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a restrained, one-time blue focus glow to the provider-name search field without changing its layout or search behavior.

**Architecture:** Keep the SwiftUI rendering in `ProviderNameSearchField`. Put the small, pure focus-style resolver beside the existing provider-search focus policy so the animation values and reduced-motion behavior can be tested without launching the app. The existing AppKit outside-click monitor remains the sole source of focus dismissal.

**Tech Stack:** Swift 5, SwiftUI, CoreGraphics, AppKit, standalone `swiftc` tests, Xcode Debug build.

---

### Task 1: Define the expected focus-style states

**Files:**
- Create: `tools/provider-search-focus-glow.test.swift`
- Test: `CCHBar/CCHProviderSearchFocusPolicy.swift`

- [ ] **Step 1: Write the failing test**

Create a standalone test that expects the resolver to return the approved values for focused, blurred, and reduced-motion states:

```swift
import CoreGraphics
import Darwin

@main
private struct ProviderSearchFocusGlowTests {
    static func main() {
        let focused = CCHProviderSearchFocusGlowStyle.resolve(isFocused: true, reduceMotion: false)
        expectEqual(focused.strokeOpacity, 0.88, "focused state should show the blue ring")
        expectEqual(focused.glowOpacity, 0.26, "focused state should use the restrained glow")
        expectEqual(focused.scale, 1.01, "focused state should expand by one percent")
        expectEqual(focused.duration, 0.22, "focus should use the 0.22 second ease-out transition")

        let blurred = CCHProviderSearchFocusGlowStyle.resolve(isFocused: false, reduceMotion: false)
        expectEqual(blurred.strokeOpacity, 0, "blurred state should hide the ring")
        expectEqual(blurred.glowOpacity, 0, "blurred state should hide the glow")
        expectEqual(blurred.scale, 1, "blurred state should return to neutral scale")
        expectEqual(blurred.duration, 0.16, "blur should use the 0.16 second transition")

        let reduced = CCHProviderSearchFocusGlowStyle.resolve(isFocused: true, reduceMotion: true)
        expectEqual(reduced.scale, 1, "reduced motion should disable scaling")
        expectEqual(reduced.duration, 0.12, "reduced motion should use the short opacity transition")
        expectEqual(reduced.strokeOpacity, focused.strokeOpacity, "reduced motion should retain focus visibility")
        expectEqual(reduced.glowOpacity, focused.glowOpacity, "reduced motion should retain the glow")
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-glow.test.swift -o /tmp/provider-search-focus-glow.test
```

Expected: compilation fails because `CCHProviderSearchFocusGlowStyle` does not exist yet.

### Task 2: Implement the pure focus-style resolver

**Files:**
- Modify: `CCHBar/CCHProviderSearchFocusPolicy.swift`

- [ ] **Step 1: Add the minimal resolver implementation**

Add this type below `CCHProviderSearchFocusPolicy`:

```swift
struct CCHProviderSearchFocusGlowStyle: Equatable {
    let strokeOpacity: Double
    let glowOpacity: Double
    let scale: CGFloat
    let duration: Double

    static func resolve(isFocused: Bool, reduceMotion: Bool) -> Self {
        if reduceMotion {
            return Self(
                strokeOpacity: isFocused ? 0.88 : 0,
                glowOpacity: isFocused ? 0.26 : 0,
                scale: 1,
                duration: 0.12
            )
        }

        return Self(
            strokeOpacity: isFocused ? 0.88 : 0,
            glowOpacity: isFocused ? 0.26 : 0,
            scale: isFocused ? 1.01 : 1,
            duration: isFocused ? 0.22 : 0.16
        )
    }
}
```

- [ ] **Step 2: Run the focused test to verify it passes**

Run:

```bash
swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-glow.test.swift -o /tmp/provider-search-focus-glow.test && /tmp/provider-search-focus-glow.test
```

Expected: exit code 0 with no failure output.

### Task 3: Render the resolver state in the search field

**Files:**
- Modify: `CCHBar/MenuBarView.swift:1393-1425`

- [ ] **Step 1: Add the accessibility environment and derived style**

Add `@Environment(\\.accessibilityReduceMotion) private var accessibilityReduceMotion` beside the existing theme environment, then derive the current style inside `body`:

```swift
let glowStyle = CCHProviderSearchFocusGlowStyle.resolve(
    isFocused: isFocused.wrappedValue,
    reduceMotion: accessibilityReduceMotion
)
```

- [ ] **Step 2: Add the non-interactive focus overlay**

After the existing unfocused border overlay, add a rounded rectangle that uses the resolver values:

```swift
.overlay {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(theme.accentBlue.opacity(glowStyle.strokeOpacity), lineWidth: 1.2)
        .shadow(color: theme.accentBlue.opacity(glowStyle.glowOpacity), radius: 7)
        .scaleEffect(glowStyle.scale)
        .animation(
            accessibilityReduceMotion
                ? .easeInOut(duration: 0.12)
                : (isFocused.wrappedValue
                    ? .easeOut(duration: glowStyle.duration)
                    : .easeInOut(duration: glowStyle.duration)),
            value: isFocused.wrappedValue
        )
        .allowsHitTesting(false)
}
```

The base `150 x 28` frame and existing border remain unchanged. The transform affects only rendering, so the adjacent “打开” button keeps its position.

- [ ] **Step 3: Build the app target to catch SwiftUI integration errors**

Run:

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug -derivedDataPath /tmp/CCHBar-focus-glow-derived build
```

Expected: `** BUILD SUCCEEDED **`.

### Task 4: Run focused regression tests

**Files:**
- Test: `tools/provider-search-focus-glow.test.swift`
- Test: `tools/provider-name-search.test.swift`
- Test: `tools/provider-search-focus-policy.test.swift`
- Test: `tools/provider-search-outside-click-monitor.test.swift`

- [ ] **Step 1: Run the new style test**

```bash
swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-glow.test.swift -o /tmp/provider-search-focus-glow.test && /tmp/provider-search-focus-glow.test
```

Expected: exit code 0.

- [ ] **Step 2: Run the existing provider search and focus tests**

```bash
swiftc CCHBar/CCHProviderNameSearch.swift tools/provider-name-search.test.swift -o /tmp/provider-name-search.test && /tmp/provider-name-search.test
swiftc CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-policy.test.swift -o /tmp/provider-search-focus-policy.test && /tmp/provider-search-focus-policy.test
swiftc -framework AppKit CCHBar/CCHProviderSearchFocusPolicy.swift CCHBar/CCHProviderSearchOutsideClickMonitor.swift tools/provider-search-outside-click-monitor.test.swift -o /tmp/provider-search-outside-click-monitor.test && /tmp/provider-search-outside-click-monitor.test
```

Expected: all commands exit 0 with no failure output.

### Task 5: Rebuild, install, and manually verify the Debug app

**Files:**
- Product: `/Applications/Claude Code Hub Bar.app`

- [ ] **Step 1: Build the final Debug app**

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Debug -derivedDataPath /tmp/CCHBar-focus-glow-final build
```

Expected: `** BUILD SUCCEEDED **` and a fresh `Debug/Claude Code Hub Bar.app`.

- [ ] **Step 2: Replace the installed Debug app and restart it**

Quit the running `app.cchbar.CCHBar` process, replace `/Applications/Claude Code Hub Bar.app` with the freshly built app, and launch the installed app. Keep only this one local Debug copy.

- [ ] **Step 3: Verify the interaction contract manually**

In the Providers tab, focus the search field and confirm the blue ring expands once and settles into a faint glow. Click a group chip, provider row, control, and blank panel space to confirm the glow fades while the clicked action still works. Confirm the field remains `150 x 28` and the “打开” button does not move. With Reduce Motion enabled, confirm the color feedback remains but the ring does not scale.

### Task 6: Commit the implementation

- [ ] **Step 1: Review the diff**

Run:

```bash
git diff --check
git status --short
```

Expected: only the intended source and test files are changed, with no whitespace errors.

- [ ] **Step 2: Commit**

```bash
git add CCHBar/MenuBarView.swift CCHBar/CCHProviderSearchFocusPolicy.swift tools/provider-search-focus-glow.test.swift
git commit -m "Add provider search focus glow"
```


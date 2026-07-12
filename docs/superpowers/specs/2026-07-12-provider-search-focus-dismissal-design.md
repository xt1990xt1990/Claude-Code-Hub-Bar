# Provider Search Focus Dismissal Design

## Goal

When the provider-name search field is active, clicking anywhere else in the Providers tab dismisses its keyboard focus and removes the blinking insertion caret. The search query and filtered results remain unchanged.

## Interaction Contract

- Clicking inside the search field, including its clear button, does not dismiss search focus.
- Clicking outside the search field dismisses search focus across the entire Providers tab, including statistics, blank spacing, group chips, provider rows, empty state, and the “打开” button.
- The outside click continues to perform its original action. Group selection, provider-row controls, links, and other controls must not be intercepted.
- Dismissing focus changes only transient view focus. It does not clear `providerSearchText`, change the selected groups, or rebuild search behavior beyond any action caused by the clicked control.

## Architecture

`ProvidersTabView` owns a local `@FocusState` Boolean because focus belongs to the rendered tab rather than persistent application state. It passes the focus binding into `ProviderNameSearchField`, whose `TextField` adopts it with `.focused(...)`.

The Providers tab defines a named coordinate space and measures the complete search-control frame. A simultaneous `SpatialTapGesture` covers the tab’s rectangular content. Each tap is evaluated against the measured search frame:

- a tap inside the frame leaves focus unchanged;
- a tap outside the frame sets the focus binding to `false`;
- an unavailable or empty frame never dismisses focus, avoiding accidental behavior during initial layout.

The gesture is simultaneous rather than exclusive so existing buttons, chips, menus, and row interactions still receive the same click.

## Focus Policy

A small pure `CCHProviderSearchFocusPolicy` owns the geometric decision. It receives the current focus state, measured search frame, and tap location, and returns whether focus should be dismissed. Keeping this decision independent of SwiftUI makes the inside/outside boundary behavior directly testable.

The policy dismisses focus only when all three conditions hold:

1. the search field is currently focused;
2. the measured search frame is non-empty;
3. the tap location is outside that frame.

## Files

- Add `CCHBar/CCHProviderSearchFocusPolicy.swift` for the pure focus decision.
- Add `tools/provider-search-focus-policy.test.swift` for standalone policy tests.
- Update `CCHBar.xcodeproj/project.pbxproj` to compile the policy in the app target.
- Update `CCHBar/MenuBarView.swift` to bind focus, measure the search frame, and handle outside taps.

No change is required in `MonitorState` or the provider-search filtering logic.

## Verification

- Standalone tests cover focused outside taps, focused inside taps, unfocused taps, and missing-frame behavior.
- The existing provider-name search test remains green.
- The complete macOS Debug target builds successfully.
- After installing and restarting the single local Debug app, manual behavior checks confirm that group chips and provider controls still act normally while dismissing the caret.

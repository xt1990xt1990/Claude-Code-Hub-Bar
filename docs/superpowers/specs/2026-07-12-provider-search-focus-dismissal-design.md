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

`CCHProviderSearchOutsideClickMonitor` is an `NSViewRepresentable` placed behind the complete search control. Its AppKit view receives the same layout bounds without participating in hit testing. While the search field is focused, a local `NSEvent` monitor observes left mouse-down events in the panel window and converts each window location into the monitor view's coordinates:

- a tap inside the frame leaves focus unchanged;
- a tap outside the frame sets the focus binding to `false` and asks the window to resign its first responder;
- an event from another window, an unfocused search, or an unavailable frame is ignored.

The local event monitor always returns the original `NSEvent`, so existing buttons, nested scroll views, chips, menus, and row interactions still receive the click. This avoids relying on a parent SwiftUI gesture, which is not a reliable event path through the Providers tab's nested vertical and horizontal scroll views.

## Focus Policy

A small pure `CCHProviderSearchFocusPolicy` owns the geometric decision. It receives the current focus state, measured search frame, and tap location, and returns whether focus should be dismissed. Keeping this decision independent of SwiftUI makes the inside/outside boundary behavior directly testable.

The policy dismisses focus only when all three conditions hold:

1. the search field is currently focused;
2. the measured search frame is non-empty;
3. the tap location is outside that frame.

## Files

- Add `CCHBar/CCHProviderSearchFocusPolicy.swift` for the pure focus decision.
- Add `CCHBar/CCHProviderSearchOutsideClickMonitor.swift` for window event observation and first-responder dismissal.
- Add `tools/provider-search-focus-policy.test.swift` for standalone policy tests.
- Add `tools/provider-search-outside-click-monitor.test.swift` for event routing tests.
- Update `CCHBar.xcodeproj/project.pbxproj` to compile both focus components in the app target.
- Update `CCHBar/MenuBarView.swift` to bind focus and mount the event monitor behind the search control.

No change is required in `MonitorState` or the provider-search filtering logic.

## Verification

- Standalone tests cover focused outside taps, focused inside taps, unfocused taps, and missing-frame behavior.
- AppKit routing tests cover same-window outside events, inside events, unfocused state, and events from another window.
- The existing provider-name search test remains green.
- The complete macOS Debug target builds successfully.
- After installing and restarting the single local Debug app, manual behavior checks confirm that group chips and provider controls still act normally while dismissing the caret.

# Provider Search Focus Glow Design

## Goal

Give the provider-name search field a clear but restrained focus response. When the field gains keyboard focus, a blue outer ring softly brightens and expands once, then remains as a faint steady glow until focus is dismissed. The effect must not pulse, shift surrounding content, or alter search behavior.

## Visual Contract

- Keep the existing search control at `150 x 28` points with an 8-point continuous corner radius.
- Preserve the current control fill, placeholder, search icon, clear button, and unfocused border.
- Use `theme.accentBlue` for a focused 1.2-point outer stroke and its glow.
- Animate into focus over 0.22 seconds with `easeOut`: the focused treatment fades in while expanding to `1.01` scale.
- Hold the focused treatment at a restrained glow of 0.26 opacity with a 7-point blur radius. It does not loop or breathe.
- Animate out of focus over 0.16 seconds with `easeInOut`.
- Apply scaling as a render transform so the search field keeps its layout dimensions and the adjacent “打开” button does not move.

The focused ring sits outside the existing border. It should be visible against Endless Dark without becoming brighter than the selected tab or primary action accents.

## Interaction Contract

The effect is driven only by the existing `@FocusState` binding:

- clicking or tabbing into the text field starts the focus transition;
- clicking the clear button keeps focus and keeps the glow;
- clicking any location outside the complete search control uses the existing AppKit outside-click monitor to dismiss focus and fade the glow;
- changing the query, selected provider group, or filtered rows does not restart the animation while focus remains active.

No search query, group selection, provider data, or persistent application state changes as part of this effect.

## Accessibility

`ProviderNameSearchField` reads `accessibilityReduceMotion` from the SwiftUI environment. When reduced motion is enabled, the control does not scale. Focus is still communicated by the blue stroke and light glow using a 0.12-second opacity transition, so keyboard focus remains visually apparent without spatial motion.

## Implementation

Keep the change local to `ProviderNameSearchField` in `CCHBar/MenuBarView.swift`:

- retain its current base border overlay;
- add a second rounded-rectangle focus overlay using the same corner radius;
- derive the overlay opacity, shadow, and scale from `isFocused.wrappedValue` and `accessibilityReduceMotion`;
- select the 0.22-second focus animation or 0.16-second blur animation according to the new focus value.

The overlay is non-interactive and must not affect the hit area. `ProvidersTabView`, `MonitorState`, `CCHProviderSearchOutsideClickMonitor`, and `CCHProviderSearchFocusPolicy` require no behavioral changes.

## Verification

- Run the existing provider-name search, focus policy, and outside-click monitor tests.
- Build the complete macOS Debug target.
- Manually verify the one-time focus transition, steady focused state, and blur transition in Endless Dark.
- Confirm that the search field and “打开” button do not shift during either transition.
- Confirm that clicks on group chips, provider rows, controls, and blank space still dismiss focus while preserving their original actions.
- Enable macOS Reduce Motion and confirm that focus retains its blue visual state without scaling.

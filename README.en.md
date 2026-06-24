# Claude Code Hub Bar

An unofficial native macOS menu bar client for [Claude Code Hub](https://github.com/ding113/claude-code-hub).

It surfaces today’s usage, running requests, logs, leaderboards, and provider health directly in the menu bar.

## Usage

1. Launch the app.
2. Open Settings from the menu bar popover.
3. Enter your CCH URL and API Key.

Private configuration should be entered locally and should not be committed to the repository.

## Features

- Menu bar summary for today’s cost and request activity.
- Idle menu bar state shows today’s cost and request count, with cost rounded to three decimals.
- Running-request mode with provider, billing model, multiplier, elapsed time, and concurrent count.
- Rotation for multiple running requests, capped at 3 items in the menu bar to reduce jumping under higher concurrency.
- Running requests panel shows up to 3 rows and keeps the rest scrollable inside the list.
- Breathing cache indicator in the menu bar — slow green pulse, fast red flash on rebuild.
- Recent requests, log details, and running requests use the current provider multiplier consistently.
- Dashboard, leaderboard, logs, and providers panels with a sliding-pill tab switcher.
- Top-right navigation actions use button styling with hover feedback.
- Liquid Glass translucent panel on macOS 26, with an `ultraThinMaterial` fallback on older systems.
- Liquid Glass and Endless Dark themes.
- Log details with provider chain, TTFB, throughput, and cache tokens.
- Cache hit-rate display for logs and leaderboards.
- Compact recent-request rows on the dashboard, with adaptive truncation for long provider and model names.
- Provider group filters, provider group assignment, enable/disable, probe, and circuit reset controls.
- Provider model tests show first-byte timing and total latency when CCH returns timing data.
- Mini Probe monitoring for providers, with per-provider enablement, probe model overrides, compact interval controls, active-hour scheduling, and average first-byte statistics.
- Status bar polling now has separate idle/active refresh intervals and an optional reduced-motion mode.
- Upstream rate panel for Sub2API and new-api providers.
- Groups upstream providers by official website and matches local providers by key suffix.
- Upstream rate rows show provider groups and reuse the provider Mini Probe controls, status, and history.
- Chrome-based upstream login capture, with credentials stored locally for rate and balance refreshes.
- Manual and scheduled upstream rate refreshes, with automatic multiplier sync for selected providers.
- Upstream balance tracking with an independent background refresh cadence.
- Provider drawers reuse the existing endpoint and model test controls for upstream checks.
- Model branding now includes GLM and avoids broad OpenAI model-name false positives.
- Launch at login support.

## Build

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Release build
```

## Language

- [中文](./README.md)

## Credits

- Respect and thanks to `ding113`, author of [Claude Code Hub](https://github.com/ding113/claude-code-hub).
- Thanks to `mbot6183` for Codex-related support.
- Model icons are provided by [LobeHub Icons](https://github.com/lobehub/lobe-icons).

## License

MIT

Copyright (c) 2026 xt1990xt1990

If you copy, distribute, modify, fork, or build upon this project, please retain
the original copyright notice, the MIT License text, and the attribution and
acknowledgement information in [NOTICE](./NOTICE).

# Upstream Rate 1.2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lightweight CCH Bar upstream rate page for grouping providers by website host, showing match/sync state, and protecting selected keys from automatic sync.

**Architecture:** Put deterministic grouping and matching in a small Swift model file so it can be tested without SwiftUI. `MonitorState` owns persisted selection/ignored state and exposes view models. `MenuBarView` renders the new `上游倍率` tab and delegates updates back to state.

**Tech Stack:** Swift 5, SwiftUI, AppStorage/UserDefaults, existing CCH API methods.

---

### Task 1: Matching Model

- [ ] Add `CCHBar/UpstreamRateModels.swift` with source type detection, host grouping, default protection for `Group1`, and unknown-site rows.
- [ ] Add a command-line Swift test under `build/upstream_rate_model_test.swift`.
- [ ] Run the test and confirm it fails before implementation.
- [ ] Implement the model and rerun the test.

### Task 2: State Wiring

- [ ] Add selected-sync persistence to `MonitorState`.
- [ ] Add computed upstream site groups from current `providers`.
- [ ] Add manual sync and selected sync actions using existing multiplier update flow.

### Task 3: UI

- [ ] Add `upstreamRates` to `CCHPanelTab`.
- [ ] Add `UpstreamRatesTabView` with stats, recognized site groups, protected rows, and unknown site section.
- [ ] Use blue styling for website host badges and distinct group badges.

### Task 4: Version and Verification

- [ ] Set `MARKETING_VERSION` to `1.2.0`.
- [ ] Run Swift model test.
- [ ] Run existing JS core tests.
- [ ] Run `xcodebuild` for the macOS app.

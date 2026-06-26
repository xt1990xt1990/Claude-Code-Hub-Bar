import Combine
import SwiftUI

@MainActor
final class ProviderRowViewModel: ObservableObject, Identifiable {
    let id: Int

    @Published private(set) var provider: CCHProvider
    @Published private(set) var displayGroupTitles: [String] = ["默认"]
    @Published private(set) var assignedGroupNames: Set<String> = []
    @Published private(set) var isMultiplierUpdating = false
    @Published private(set) var isDispatchSettingsUpdating = false
    @Published private(set) var isModelTesting = false
    @Published private(set) var modelTestResult: CCHProviderModelTestResult?
    @Published private(set) var modelTestResultsByModel: [String: CCHProviderModelTestResult] = [:]
    @Published private(set) var modelTestProgress: CCHProviderModelTestProgress?
    @Published private(set) var customTestModels: [String] = []
    @Published private(set) var isMiniProbeEnabled = false
    @Published private(set) var isMiniProbeRunning = false
    @Published private(set) var miniProbeHistory: [CCHProviderMiniProbeSample] = []
    @Published private(set) var miniProbeAverageTTFB: Double?
    @Published private(set) var miniProbeModel: String = ""
    @Published private(set) var resolvedMiniProbeModel: String = ""

    private weak var state: MonitorState?
    private var cancellables = Set<AnyCancellable>()

    init(provider: CCHProvider, state: MonitorState) {
        self.id = provider.id
        self.provider = provider
        self.state = state
        self.assignedGroupNames = state.assignedGroupNames(for: provider)
        self.displayGroupTitles = state.displayGroupTitles(for: provider)
        self.isMultiplierUpdating = state.isProviderMultiplierUpdating(provider)
        self.isDispatchSettingsUpdating = state.isProviderDispatchSettingsUpdating(provider)
        self.isModelTesting = state.isProviderModelTesting(provider)
        self.modelTestResult = state.providerModelTestResult(for: provider)
        self.modelTestResultsByModel = state.providerModelTestResults(for: provider)
        self.modelTestProgress = state.providerModelTestProgress(for: provider)
        self.customTestModels = state.customTestModels(for: provider)
        self.isMiniProbeEnabled = state.isProviderMiniProbeEnabled(provider)
        self.isMiniProbeRunning = state.isProviderMiniProbeRunning(provider)
        self.miniProbeHistory = state.providerMiniProbeHistory(for: provider)
        self.miniProbeAverageTTFB = state.providerMiniProbeAverageTTFB(for: provider)
        self.miniProbeModel = state.providerMiniProbeModel(for: provider)
        self.resolvedMiniProbeModel = state.resolvedProviderMiniProbeModelTitle(for: provider)
        bind(to: state)
    }

    private func bind(to state: MonitorState) {
        let id = self.id

        state.$providers
            .map { providers in providers.first { $0.id == id } }
            .compactMap { $0 }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.provider = $0 }
            .store(in: &cancellables)

        Publishers.CombineLatest(state.$providers, state.$providerGroupAssignmentOverrides)
            .dropFirst()
            .sink { [weak self, weak state] _, _ in
                guard let self, let state else { return }
                guard let provider = state.providers.first(where: { $0.id == id }) else { return }
                let newAssigned = state.assignedGroupNames(for: provider)
                if self.assignedGroupNames != newAssigned {
                    self.assignedGroupNames = newAssigned
                }
                let newTitles = state.displayGroupTitles(for: provider)
                if self.displayGroupTitles != newTitles {
                    self.displayGroupTitles = newTitles
                }
            }
            .store(in: &cancellables)

        state.$modelTestingProviderIds
            .map { $0.contains(id) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.isModelTesting = $0 }
            .store(in: &cancellables)

        state.$providerModelTestResults
            .map { $0[id] }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.modelTestResult = $0 }
            .store(in: &cancellables)

        state.$providerModelTestResultsByModel
            .map { $0[id] ?? [:] }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.modelTestResultsByModel = $0 }
            .store(in: &cancellables)

        state.$providerModelTestProgress
            .map { $0[id] }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.modelTestProgress = $0 }
            .store(in: &cancellables)

        state.$providerCustomTestModels
            .map { $0[id] ?? [] }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.customTestModels = $0 }
            .store(in: &cancellables)

        state.$providerMiniProbeSelectedProviderIds
            .map { $0.contains(id) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.isMiniProbeEnabled = $0 }
            .store(in: &cancellables)

        state.$providerMiniProbeRunningIds
            .map { $0.contains(id) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] in self?.isMiniProbeRunning = $0 }
            .store(in: &cancellables)

        state.$providerMiniProbeHistories
            .map { $0[id] ?? [] }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self, weak state] history in
                guard let self else { return }
                self.miniProbeHistory = history
                guard let state,
                      let provider = state.providers.first(where: { $0.id == id }) else { return }
                let newAvg = state.providerMiniProbeAverageTTFB(for: provider)
                if self.miniProbeAverageTTFB != newAvg {
                    self.miniProbeAverageTTFB = newAvg
                }
            }
            .store(in: &cancellables)

        state.$providerMiniProbeModelOverrides
            .map { $0[id] ?? "" }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self, weak state] override in
                guard let self else { return }
                self.miniProbeModel = override
                guard let state,
                      let provider = state.providers.first(where: { $0.id == id }) else { return }
                let newResolved = state.resolvedProviderMiniProbeModelTitle(for: provider)
                if self.resolvedMiniProbeModel != newResolved {
                    self.resolvedMiniProbeModel = newResolved
                }
            }
            .store(in: &cancellables)

        state.$providerMultiplierUpdatingIds
            .map { $0.contains(id) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] updating in
                self?.isMultiplierUpdating = updating
                self?.isDispatchSettingsUpdating = updating
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func setEnabled(_ value: Bool) {
        guard let state else { return }
        let provider = provider
        Task { await state.setProvider(provider, enabled: value) }
    }

    func toggleGroup(_ group: CCHProviderGroup) {
        guard let state else { return }
        let provider = provider
        Task { await state.toggleProviderGroupAssignment(group, for: provider) }
    }

    func setMultiplier(_ multiplier: Double) {
        guard let state else { return }
        let provider = provider
        Task { await state.updateProviderMultiplier(provider, multiplier: multiplier) }
    }

    func setDispatchSettings(_ settings: CCHProviderDispatchSettings) {
        guard let state else { return }
        let provider = provider
        Task { await state.updateProviderDispatchSettings(provider, settings: settings) }
    }

    func probe() {
        guard let state else { return }
        let provider = provider
        Task { await state.probe(provider) }
    }

    func testModel(_ model: String) {
        guard let state else { return }
        let provider = provider
        Task { await state.testProviderModel(provider, model: model) }
    }

    func testModels(_ models: [String]) {
        guard let state else { return }
        let provider = provider
        Task { await state.testProviderModels(provider, models: models) }
    }

    func setMiniProbeEnabled(_ enabled: Bool) {
        state?.setProviderMiniProbe(provider, enabled: enabled)
    }

    func setMiniProbeModel(_ model: String) {
        state?.setProviderMiniProbeModel(model, for: provider)
    }

    func addCustomTestModel(_ model: String) {
        state?.addCustomTestModel(model, for: provider)
    }

    func removeCustomTestModel(_ model: String) {
        state?.removeCustomTestModel(model, for: provider)
    }

    func resetCircuit() {
        guard let state else { return }
        let provider = provider
        Task { await state.resetCircuit(provider) }
    }

    func commitProviderSortIfNeeded() {
        state?.commitProviderSortIfNeeded()
    }
}

#if canImport(SwiftUI)
import SwiftUI
import AbetaWatchKit

// MARK: - Theme Configuration

/// Visual theme tokens allowing Apple Watch & companion SwiftUI hosts to customize
/// `AbetaWatchSduiView`, `AbetaWatchMetricRow`, and `AbetaWatchActionCardView`.
public struct AbetaWatchTheme: Sendable {
    public let accentColor: Color
    public let offlineTint: Color
    public let toastTint: Color
    public let badgeColor: Color
    public let cardCornerRadius: CGFloat
    public let itemSpacing: CGFloat
    public let cardPadding: CGFloat
    public let contentHorizontalPadding: CGFloat
    public let contentVerticalPadding: CGFloat

    public init(
        accentColor: Color = .accentColor,
        offlineTint: Color = .orange,
        toastTint: Color = .green,
        badgeColor: Color = .green,
        cardCornerRadius: CGFloat = 10,
        itemSpacing: CGFloat = 8,
        cardPadding: CGFloat = 8,
        contentHorizontalPadding: CGFloat = 6,
        contentVerticalPadding: CGFloat = 4
    ) {
        self.accentColor = accentColor
        self.offlineTint = offlineTint
        self.toastTint = toastTint
        self.badgeColor = badgeColor
        self.cardCornerRadius = cardCornerRadius
        self.itemSpacing = itemSpacing
        self.cardPadding = cardPadding
        self.contentHorizontalPadding = contentHorizontalPadding
        self.contentVerticalPadding = contentVerticalPadding
    }

    /// Default watchOS-tuned compact spacing and semantic color palette.
    public static let `default` = AbetaWatchTheme()
}

// MARK: - View Model

/// Observable SwiftUI view model wrapping `AbetaWatchKit`'s `WatchCompanionHostHolder`
/// and bridging Kotlin `StateFlow<WatchUiState>` into Swift Concurrency `AsyncStream`.
@MainActor
public final class AbetaWatchViewModel: ObservableObject {
    private let holder: WatchCompanionHostHolder
    private var observeTask: Task<Void, Never>?

    @Published public private(set) var metrics: [WatchMetricGlance] = []
    @Published public private(set) var cards: [WatchActionCard] = []
    @Published public private(set) var titleText: String = "Abeta Watch"
    @Published public private(set) var activeScreenId: String
    @Published public private(set) var isOffline: Bool = false
    @Published public private(set) var isLoading: Bool = true
    @Published public private(set) var errorMessage: String? = nil
    @Published public private(set) var toastMessage: String? = nil

    /// Creates a self-contained watch view model backed by `WatchAppleFactoryKt.createAppleWatchCompanionHost`.
    /// Pass `bffBaseUrl: nil` to use the built-in offline starter screen for simulator previews.
    public convenience init(
        bffBaseUrl: String? = nil,
        initialScreenId: String = "watch-status"
    ) {
        let createdHolder = WatchAppleFactoryKt.createAppleWatchCompanionHost(bffBaseUrl: bffBaseUrl)
        self.init(holder: createdHolder, initialScreenId: initialScreenId)
    }

    /// Creates a watch view model from a pre-configured `WatchCompanionHostHolder` (for custom TLS pins or DI).
    public init(
        holder: WatchCompanionHostHolder,
        initialScreenId: String = "watch-status"
    ) {
        self.holder = holder
        self.activeScreenId = initialScreenId
        holder.controller.loadScreen(screenId: initialScreenId)
        startObservingState()
    }

    deinit {
        observeTask?.cancel()
        holder.close()
    }

    /// Loads another SDUI watch screen by identifier.
    public func loadScreen(_ screenId: String) {
        let trimmed = screenId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activeScreenId = trimmed
        isLoading = true
        errorMessage = nil
        holder.controller.loadScreen(screenId: trimmed)
        syncFromControllerState()
    }

    /// Loads another SDUI watch screen and suspends until a settled `Ready` or `Error` state arrives.
    public func loadScreenAsync(_ screenId: String) async {
        let trimmed = screenId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activeScreenId = trimmed
        isLoading = true
        errorMessage = nil
        let settled = await holder.loadScreenAndAwaitReady(trimmed)
        apply(state: settled)
    }

    /// Reloads the currently active watch screen.
    public func refresh() {
        isLoading = true
        errorMessage = nil
        holder.controller.refresh()
        syncFromControllerState()
    }

    /// SwiftUI `.refreshable`-compatible `async`/`await` reload awaiting the next settled state.
    public func refreshAsync() async {
        isLoading = true
        errorMessage = nil
        let settled = await holder.refreshAndAwaitReady()
        apply(state: settled)
    }

    /// Dispatches a wearable `ActionRef` tap through `WatchCompanionController`.
    public func trigger(_ action: ActionRef?) {
        guard let action else { return }
        holder.controller.onAction(action: action)
        syncFromControllerState()
    }

    /// Dismisses the active transient toast message.
    public func dismissToast() {
        holder.controller.dismissToast()
        toastMessage = nil
    }

    /// Synchronously pulls the latest snapshot from `WatchCompanionController.uiState`.
    public func syncFromControllerState() {
        apply(state: holder.controller.uiState.value)
    }

    private func apply(state rawState: Any?) {
        switch rawState {
        case is WatchUiStateIdle, is WatchUiStateLoading:
            isLoading = true
            errorMessage = nil

        case let ready as WatchUiStateReady:
            isLoading = false
            errorMessage = nil
            titleText = ready.page.title
            activeScreenId = ready.page.pageId
            isOffline = ready.page.isOffline
            metrics = ready.page.metrics
            cards = ready.page.cards
            toastMessage = ready.activeToast ?? ready.page.lastFeedbackMessage

        case let failed as WatchUiStateError:
            isLoading = false
            errorMessage = failed.error.message

        default:
            break
        }
    }

    private func startObservingState() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await state in holder.uiStateStream() {
                if Task.isCancelled { break }
                self.apply(state: state)
            }
        }
    }
}

// MARK: - Root SwiftUI View

/// Plug-and-play SwiftUI root view rendering SDUI watch screens powered by `AbetaWatchKit`.
/// Supports metrics, 1-tap action cards, offline cache indicator, `.refreshable` pull-to-refresh,
/// error retry state, and dismissible toast notifications.
public struct AbetaWatchSduiView: View {
    @StateObject private var viewModel: AbetaWatchViewModel
    private let theme: AbetaWatchTheme

    public init(
        bffBaseUrl: String? = nil,
        initialScreenId: String = "watch-status",
        theme: AbetaWatchTheme = .default
    ) {
        _viewModel = StateObject(
            wrappedValue: AbetaWatchViewModel(
                bffBaseUrl: bffBaseUrl,
                initialScreenId: initialScreenId
            )
        )
        self.theme = theme
    }

    public init(
        viewModel: @autoclosure @escaping () -> AbetaWatchViewModel,
        theme: AbetaWatchTheme = .default
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.theme = theme
    }

    public var body: some View {
        navigationContainer {
            contentBody
                .navigationTitle(viewModel.titleText)
                #if os(watchOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 16.0, watchOS 9.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            #if os(iOS)
            .navigationViewStyle(.stack)
            #endif
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.isLoading && viewModel.metrics.isEmpty && viewModel.cards.isEmpty {
            ProgressView("Loading…")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            errorStateView(message: errorMessage)
        } else {
            readyContentView
        }
    }

    private var readyContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.itemSpacing) {
                if viewModel.isOffline {
                    Label("Offline · Cached", systemImage: "wifi.slash")
                        .font(.caption2)
                        .foregroundStyle(theme.offlineTint)
                        .accessibilityLabel("Offline mode showing cached screen")
                }

                if let toast = viewModel.toastMessage, !toast.isEmpty {
                    Button {
                        viewModel.dismissToast()
                    } label: {
                        Text(toast)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.toastTint)
                    .accessibilityLabel(toast)
                    .accessibilityHint("Tap to dismiss notification")
                }

                ForEach(viewModel.metrics, id: \.id) { metric in
                    AbetaWatchMetricRow(metric: metric, theme: theme) { action in
                        viewModel.trigger(action)
                    }
                }

                ForEach(viewModel.cards, id: \.id) { card in
                    AbetaWatchActionCardView(card: card, theme: theme) { action in
                        viewModel.trigger(action)
                    }
                }
            }
            .padding(.horizontal, theme.contentHorizontalPadding)
            .padding(.vertical, theme.contentVerticalPadding)
        }
        .refreshable {
            await viewModel.refreshAsync()
        }
    }

    private func errorStateView(message: String) -> some View {
        VStack(spacing: theme.itemSpacing) {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentColor)
            .accessibilityLabel("Retry loading screen")
        }
        .padding()
    }
}

// MARK: - Reusable Building Blocks

/// Reusable SwiftUI glance metric row rendering a `WatchMetricGlance` with optional linear progress.
public struct AbetaWatchMetricRow: View {
    public let metric: WatchMetricGlance
    public let theme: AbetaWatchTheme
    public let onAction: (ActionRef?) -> Void

    public init(
        metric: WatchMetricGlance,
        theme: AbetaWatchTheme = .default,
        onAction: @escaping (ActionRef?) -> Void = { _ in }
    ) {
        self.metric = metric
        self.theme = theme
        self.onAction = onAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(metric.value)
                .font(.headline)
                .foregroundStyle(.primary)
            if let fraction = metric.progressFraction {
                ProgressView(value: Double(max(0, min(1, fraction.floatValue))))
                    .tint(theme.accentColor)
            }
            if let progressLabel = metric.progressLabel {
                Text(progressLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.cardPadding)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .onTapGesture {
            if let action = metric.onClick {
                onAction(action)
            }
        }
    }
}

/// Reusable SwiftUI action card rendering a `WatchActionCard` with optional badge, subtitle, and CTAs.
public struct AbetaWatchActionCardView: View {
    public let card: WatchActionCard
    public let theme: AbetaWatchTheme
    public let onAction: (ActionRef?) -> Void

    public init(
        card: WatchActionCard,
        theme: AbetaWatchTheme = .default,
        onAction: @escaping (ActionRef?) -> Void = { _ in }
    ) {
        self.card = card
        self.theme = theme
        self.onAction = onAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let badge = card.badgeLabel {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(theme.badgeColor)
                }
            }
            if let subtitle = card.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let primaryLabel = card.primaryActionLabel {
                Button {
                    onAction(card.primaryAction)
                } label: {
                    Text(primaryLabel)
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentColor)
                .disabled(card.primaryAction == nil)
                .accessibilityLabel(primaryLabel)
            }
            if let secondaryLabel = card.secondaryActionLabel {
                Button {
                    onAction(card.secondaryAction)
                } label: {
                    Text(secondaryLabel)
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(card.secondaryAction == nil)
                .accessibilityLabel(secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.cardPadding)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
        )
    }
}

// MARK: - Swift Concurrency Extensions

public extension WatchCompanionHostHolder {
    /// Emits `WatchUiState` updates as a cancellation-aware Swift `AsyncStream`.
    func uiStateStream(
        pollIntervalNanoseconds: UInt64 = 150_000_000
    ) -> AsyncStream<WatchUiState> {
        AsyncStream { continuation in
            let task = Task {
                var lastEmitted: WatchUiState?
                while !Task.isCancelled {
                    if let current = self.controller.uiState.value as? WatchUiState {
                        let changed = lastEmitted.map { !$0.isEqual(current) } ?? true
                        if changed {
                            lastEmitted = current
                            continuation.yield(current)
                        }
                    }
                    do {
                        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Triggers `loadScreen(screenId:)` and suspends until a settled `Ready` or `Error` state arrives.
    func loadScreenAndAwaitReady(
        _ screenId: String = "watch-status"
    ) async -> WatchUiState {
        controller.loadScreen(screenId: screenId)
        for await state in uiStateStream() {
            if state is WatchUiStateReady || state is WatchUiStateError {
                return state
            }
        }
        return (controller.uiState.value as? WatchUiState) ?? WatchUiStateIdle.shared
    }

    /// Triggers `refresh()` and suspends until the refreshed screen settles (`Ready` or `Error`).
    func refreshAndAwaitReady() async -> WatchUiState {
        controller.refresh()
        for await state in uiStateStream() {
            if state is WatchUiStateReady || state is WatchUiStateError {
                return state
            }
        }
        return (controller.uiState.value as? WatchUiState) ?? WatchUiStateIdle.shared
    }
}
#endif

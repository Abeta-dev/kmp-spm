#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import AbetaSduiKit

// MARK: - UIKit Bridge

/// Ready-to-use `UIViewControllerRepresentable` hosting an `AbetaSduiKit` Compose Multiplatform
/// SDUI screen inside SwiftUI on iOS / iPadOS 15+.
public struct AbetaIosSduiScreenView: UIViewControllerRepresentable {
    public let screenId: String
    public let bffBaseUrl: String?

    public init(
        screenId: String = "store-home",
        bffBaseUrl: String? = nil
    ) {
        self.screenId = screenId
        self.bffBaseUrl = bffBaseUrl
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        SduiViewControllerKt.createSduiViewController(
            screenId: screenId,
            bffBaseUrl: bffBaseUrl
        )
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Root App View

/// Plug-and-play SwiftUI root view embedding `AbetaIosSduiScreenView` inside a navigation container
/// with `.onOpenURL` deep-link routing (`abeta://screens/<id>`, `https://.../screens/<id>`, or `?screen=<id>`).
public struct AbetaIosRootAppView: View {
    @State private var activeScreenId: String
    private let bffBaseUrl: String?
    private let deepLinkResolver: (URL) -> String?

    public init(
        initialScreenId: String = "store-home",
        bffBaseUrl: String? = nil,
        deepLinkResolver: @escaping (URL) -> String? = AbetaIosRootAppView.defaultResolveScreenId(from:)
    ) {
        _activeScreenId = State(initialValue: initialScreenId)
        self.bffBaseUrl = bffBaseUrl
        self.deepLinkResolver = deepLinkResolver
    }

    public var body: some View {
        navigationContainer {
            screenContent
        }
        .onOpenURL { url in
            if let resolved = deepLinkResolver(url), !resolved.isEmpty {
                activeScreenId = resolved
            }
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
                    .toolbar(.hidden, for: .navigationBar)
            }
        } else {
            NavigationView {
                content()
                    .navigationBarHidden(true)
            }
            .navigationViewStyle(.stack)
        }
    }

    private var screenContent: some View {
        AbetaIosSduiScreenView(
            screenId: activeScreenId,
            bffBaseUrl: bffBaseUrl
        )
        .id(activeScreenId)
        .ignoresSafeArea(.container, edges: .all)
    }

    /// Resolves an SDUI `screenId` from custom-scheme or universal link URLs.
    public static func defaultResolveScreenId(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryScreen = components.queryItems?.first(where: { $0.name == "screen" })?.value,
           !queryScreen.isEmpty {
            return queryScreen
        }
        let pathSegments = url.pathComponents.filter { $0 != "/" }
        if let screensIndex = pathSegments.firstIndex(of: "screens"),
           pathSegments.indices.contains(screensIndex + 1) {
            return pathSegments[screensIndex + 1]
        }
        return pathSegments.last ?? url.host
    }
}
#endif

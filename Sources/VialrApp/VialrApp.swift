import SwiftUI
import DesignSystem

@main
public struct VialrApp: App {
    @State private var coordinator = AppCoordinator()
    private let container = AppContainer.shared

    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootNavigationView(coordinator: coordinator, container: container)
                .preferredColorScheme(.dark)
                .background(VialrColors.backgroundPrimary)
        }
    }
}

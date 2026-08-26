import SwiftUI
import Observation
import DesignSystem

/// View model managing the horizontally paging onboarding cards, swipe navigation,
/// and persistent local storage of the current page index.
@Observable
public final class OnboardingPagerViewModel: @unchecked Sendable {
    public static let pageIndexStorageKey = "vialr_onboarding_page_index"
    public static let onboardingCompletedStorageKey = "vialr_onboarding_completed"

    public let pages: [OnboardingPageItem]
    private let userDefaults: UserDefaults

    /// Current page index synchronized with persistent local storage
    public var currentPageIndex: Int {
        didSet {
            let clamped = max(0, min(pages.count - 1, currentPageIndex))
            if currentPageIndex != clamped {
                currentPageIndex = clamped
            }
            userDefaults.set(currentPageIndex, forKey: Self.pageIndexStorageKey)
        }
    }

    public var isLastPage: Bool {
        currentPageIndex >= pages.count - 1
    }

    public var totalPages: Int {
        pages.count
    }

    public init(
        pages: [OnboardingPageItem] = OnboardingPageItem.standardPages,
        userDefaults: UserDefaults = .standard
    ) {
        self.pages = pages
        self.userDefaults = userDefaults

        let storedIndex = userDefaults.integer(forKey: Self.pageIndexStorageKey)
        self.currentPageIndex = max(0, min(pages.count - 1, storedIndex))
    }

    // MARK: - Navigation Actions
    public func nextPage(onReachedEnd: () -> Void) {
        if currentPageIndex < pages.count - 1 {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                currentPageIndex += 1
            }
            VialrHaptics.lightImpact()
        } else {
            VialrHaptics.mediumImpact()
            onReachedEnd()
        }
    }

    public func previousPage() {
        guard currentPageIndex > 0 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            currentPageIndex -= 1
        }
        VialrHaptics.lightImpact()
    }

    public func goToPage(index: Int) {
        guard index >= 0 && index < pages.count else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            currentPageIndex = index
        }
        VialrHaptics.selection()
    }

    public func skipToAuth(onTransition: () -> Void) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentPageIndex = pages.count - 1
        }
        VialrHaptics.mediumImpact()
        onTransition()
    }

    public func reset() {
        currentPageIndex = 0
        userDefaults.removeObject(forKey: Self.pageIndexStorageKey)
    }
}

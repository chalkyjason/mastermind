import Foundation
import UIKit

// MARK: - Ad Manager
// Note: This is a stub implementation. To enable real ads:
// 1. Add Google Mobile Ads SDK via Swift Package Manager
// 2. Uncomment the GoogleMobileAds import and GAD* code
// 3. Configure your Ad Unit IDs in App Store Connect

class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    // Ad Unit IDs - Replace with your own before release
    // Test ID: "ca-app-pub-3940256099942544/5224354917"
    // Production ID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/5224354917"

    // Published state
    @Published var isRewardedAdReady = false
    @Published var isLoadingAd = false

    // Completion handler for reward
    private var rewardCompletion: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - SDK Initialization

    static func configure() {
        // Stub: In production, initialize Google Mobile Ads SDK here
        // GADMobileAds.sharedInstance().start { status in ... }
        #if DEBUG
        print("AdManager: Stub mode - ads disabled")
        #endif

        // Simulate ad being ready after a delay (for testing UI flow)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AdManager.shared.isRewardedAdReady = true
        }
    }

    // MARK: - Rewarded Ad

    func loadRewardedAd() {
        guard !isLoadingAd else { return }

        isLoadingAd = true

        // Stub: Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoadingAd = false
            self?.isRewardedAdReady = true
            #if DEBUG
            print("AdManager: Stub - rewarded ad 'loaded'")
            #endif
        }
    }

    func showRewardedAd(from viewController: UIViewController? = nil, completion: @escaping (Bool) -> Void) {
        guard isRewardedAdReady else {
            #if DEBUG
            print("AdManager: Stub - rewarded ad not ready")
            #endif
            completion(false)
            loadRewardedAd()
            return
        }

        rewardCompletion = completion

        // Stub: Simulate showing an ad by immediately granting reward
        // In production, this would present the actual ad
        #if DEBUG
        print("AdManager: Stub - simulating ad view, granting reward")
        #endif

        // Simulate a brief delay as if watching an ad
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Trigger haptic feedback for reward
            HapticManager.shared.notification(.success)

            self?.rewardCompletion?(true)
            self?.rewardCompletion = nil
            self?.isRewardedAdReady = false

            // Pre-load next ad
            self?.loadRewardedAd()
        }
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        return topController
    }
}

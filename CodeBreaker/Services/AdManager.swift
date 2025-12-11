import Foundation
import GoogleMobileAds
import UIKit

// MARK: - Ad Manager

class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    // Ad Unit IDs
    private let rewardedAdUnitID = "ca-app-pub-3531459586407787/1644851557"

    // Published state
    @Published var isRewardedAdReady = false
    @Published var isLoadingAd = false

    // Rewarded ad instance
    private var rewardedAd: GADRewardedAd?

    // Completion handler for reward
    private var rewardCompletion: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - SDK Initialization

    static func configure() {
        GADMobileAds.sharedInstance().start { status in
            print("AdMob SDK initialized")
            // Pre-load rewarded ad after initialization
            AdManager.shared.loadRewardedAd()
        }
    }

    // MARK: - Rewarded Ad

    func loadRewardedAd() {
        guard !isLoadingAd else { return }

        isLoadingAd = true

        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                self?.isLoadingAd = false

                if let error = error {
                    print("Failed to load rewarded ad: \(error.localizedDescription)")
                    self?.isRewardedAdReady = false
                    return
                }

                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                self?.isRewardedAdReady = true
                print("Rewarded ad loaded successfully")
            }
        }
    }

    func showRewardedAd(from viewController: UIViewController? = nil, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd, isRewardedAdReady else {
            print("Rewarded ad not ready")
            completion(false)
            // Try to load a new ad for next time
            loadRewardedAd()
            return
        }

        rewardCompletion = completion

        // Get the root view controller if none provided
        let presentingVC = viewController ?? getRootViewController()

        guard let vc = presentingVC else {
            print("No view controller to present ad")
            completion(false)
            return
        }

        ad.present(fromRootViewController: vc) { [weak self] in
            // User earned reward
            let reward = ad.adReward
            print("User earned reward: \(reward.amount) \(reward.type)")

            // Trigger haptic feedback for reward
            HapticManager.shared.notification(.success)

            self?.rewardCompletion?(true)
            self?.rewardCompletion = nil
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

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Rewarded ad dismissed")
        isRewardedAdReady = false

        // If reward wasn't granted (user closed early), call completion with false
        if rewardCompletion != nil {
            rewardCompletion?(false)
            rewardCompletion = nil
        }

        // Pre-load next ad
        loadRewardedAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present rewarded ad: \(error.localizedDescription)")
        isRewardedAdReady = false
        rewardCompletion?(false)
        rewardCompletion = nil

        // Try to load a new ad
        loadRewardedAd()
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Rewarded ad will present")
    }
}

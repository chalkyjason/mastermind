import Foundation
import UIKit
import GoogleMobileAds

// MARK: - Ad Manager

class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    // MARK: - Ad Unit IDs

    // Production rewarded ad unit ID
    private let rewardedAdUnitID = "ca-app-pub-3531459586407787/1644851557"

    // Test ad unit ID (use during development)
    // private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    // MARK: - Published State

    @Published var isRewardedAdReady = false
    @Published var isLoadingAd = false

    // MARK: - Private Properties

    private var rewardedAd: GADRewardedAd?
    private var rewardCompletion: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - SDK Initialization

    static func configure() {
        GADMobileAds.sharedInstance().start { status in
            #if DEBUG
            print("AdManager: Google Mobile Ads SDK initialized")
            for adapter in status.adapterStatusesByClassName {
                print("  - \(adapter.key): \(adapter.value.state.rawValue)")
            }
            #endif

            // Load first rewarded ad after initialization
            AdManager.shared.loadRewardedAd()
        }
    }

    // MARK: - Rewarded Ad

    func loadRewardedAd() {
        guard !isLoadingAd else { return }

        isLoadingAd = true

        #if DEBUG
        print("AdManager: Loading rewarded ad...")
        #endif

        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoadingAd = false

                if let error = error {
                    #if DEBUG
                    print("AdManager: Failed to load rewarded ad: \(error.localizedDescription)")
                    #endif
                    self.isRewardedAdReady = false
                    return
                }

                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isRewardedAdReady = true

                #if DEBUG
                print("AdManager: Rewarded ad loaded successfully")
                #endif
            }
        }
    }

    func showRewardedAd(from viewController: UIViewController? = nil, completion: @escaping (Bool) -> Void) {
        guard isRewardedAdReady, let rewardedAd = rewardedAd else {
            #if DEBUG
            print("AdManager: Rewarded ad not ready")
            #endif
            completion(false)
            loadRewardedAd()
            return
        }

        rewardCompletion = completion

        guard let rootVC = viewController ?? getRootViewController() else {
            #if DEBUG
            print("AdManager: Could not find root view controller")
            #endif
            completion(false)
            return
        }

        rewardedAd.present(fromRootViewController: rootVC) { [weak self] in
            // User earned reward
            let reward = rewardedAd.adReward
            #if DEBUG
            print("AdManager: User earned reward - \(reward.amount) \(reward.type)")
            #endif

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
        #if DEBUG
        print("AdManager: Ad dismissed")
        #endif

        // Reset state and pre-load next ad
        isRewardedAdReady = false
        rewardedAd = nil
        loadRewardedAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("AdManager: Failed to present ad: \(error.localizedDescription)")
        #endif

        rewardCompletion?(false)
        rewardCompletion = nil
        isRewardedAdReady = false
        rewardedAd = nil
        loadRewardedAd()
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        #if DEBUG
        print("AdManager: Ad will present")
        #endif
    }
}

import Foundation
import GoogleMobileAds

// MARK: - Ad Manager

class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published var isRewardedAdReady = false
    @Published var isInterstitialAdReady = false
    
    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?
    
    // Ad Unit IDs - Replace with your actual ad unit IDs
    #if DEBUG
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // Test ID
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Test ID
    #else
    private let rewardedAdUnitID = "YOUR_REWARDED_AD_UNIT_ID" // Production ID
    private let interstitialAdUnitID = "YOUR_INTERSTITIAL_AD_UNIT_ID" // Production ID
    #endif
    
    private var rewardCompletion: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    static func configure() {
        MobileAds.shared.start { status in
            print("Google Mobile Ads SDK initialized")
            AdManager.shared.loadRewardedAd()
            AdManager.shared.loadInterstitialAd()
        }
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Rewarded Ads
    
    func loadRewardedAd() {
        let request = Request()
        RewardedAd.load(
            with: rewardedAdUnitID,
            request: request
        ) { [weak self] ad, error in
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
    
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            print("Rewarded ad not ready")
            completion(false)
            return
        }
        
        rewardCompletion = completion
        rewardedAd.present(from: viewController) { [weak self] in
            let reward = rewardedAd.adReward
            print("User earned reward: \(reward.amount) \(reward.type)")
            self?.rewardCompletion?(true)
            self?.rewardCompletion = nil
            
            // Load next ad
            self?.loadRewardedAd()
        }
    }
    
    // MARK: - Interstitial Ads
    
    func loadInterstitialAd() {
        let request = Request()
        InterstitialAd.load(
            with: interstitialAdUnitID,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
                self?.isInterstitialAdReady = false
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            self?.isInterstitialAdReady = true
            print("Interstitial ad loaded successfully")
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        guard let interstitialAd = interstitialAd else {
            print("Interstitial ad not ready")
            completion?()
            return
        }
        
        interstitialAd.present(from: viewController)
        completion?()
        
        // Load next ad
        loadInterstitialAd()
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("Ad recorded impression")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("Ad recorded click")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present: \(error.localizedDescription)")
        
        if ad === rewardedAd {
            isRewardedAdReady = false
            rewardCompletion?(false)
            rewardCompletion = nil
            loadRewardedAd()
        } else if ad === interstitialAd {
            isInterstitialAdReady = false
            loadInterstitialAd()
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will present")
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will dismiss")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad dismissed")
        
        if ad === rewardedAd {
            isRewardedAdReady = false
            // Note: We already loaded the next ad in showRewardedAd's completion
        } else if ad === interstitialAd {
            isInterstitialAdReady = false
            loadInterstitialAd()
        }
    }
}

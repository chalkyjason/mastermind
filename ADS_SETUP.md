# Google Mobile Ads SDK Setup

This project requires the Google Mobile Ads SDK to display rewarded ads. Follow these steps to complete the setup.

## Required Setup Steps

### 1. Add Google Mobile Ads SDK via Swift Package Manager

1. Open `CodeBreaker.xcodeproj` in Xcode
2. Go to **File > Add Package Dependencies...**
3. Enter the package URL: `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`
4. Select version `11.0.0` or later
5. Add the package to your `CodeBreaker` target
6. Build the project to verify the package is installed correctly

### 2. Verify Info.plist Configuration

The `Info.plist` file already contains the required configuration:

- **GADApplicationIdentifier**: `ca-app-pub-3531459586407787~3141766059`
- **SKAdNetworkItems**: Pre-configured with AdMob's required identifiers
- **NSUserTrackingUsageDescription**: Permission message for personalized ads

⚠️ **Important**: Update the `GADApplicationIdentifier` with your own AdMob App ID before deploying to production.

### 3. Ad Unit Configuration

The project uses the following ad unit:

- **Rewarded Ad Unit ID**: `ca-app-pub-3531459586407787/1644851557`
  - Located in: `CodeBreaker/Services/AdManager.swift` (line 11)
  - Used for: Extra life rewards after game over

⚠️ **Important**: Replace with your own Ad Unit ID from AdMob console before production release.

### 4. Test Ads

For testing purposes, you can use Google's test ad units:

```swift
// In AdManager.swift, replace the production ad unit ID with:
private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // Test ad unit
```

Remember to revert to your production ad unit ID before App Store submission.

## Integration Overview

The ad integration consists of:

1. **AdManager.swift** - Handles loading and presenting rewarded ads
   - Initializes Google Mobile Ads SDK in `configure()`
   - Pre-loads ads for better user experience
   - Integrates with HapticManager for feedback

2. **LivesManager.swift** - Manages the lives system and ad rewards
   - `requestAdForLife()` - Triggers ad display and rewards a life
   - `isAdAvailable` - Checks if an ad is ready to show

3. **GameView.swift** - Game screen that triggers ads
   - Observes `AdManager.shared` for ad readiness
   - Calls `handleWatchAd()` when user opts to watch an ad
   - Grants extra life on successful ad completion

4. **GameOverlays.swift** - Lose screen showing ad button
   - Displays "Watch Ad for Extra Life" button when available
   - Shows loading state while ad is presenting
   - Integrates with lives system

## Testing the Implementation

1. Build and run the app on a physical device or simulator
2. Play a level until you lose (run out of attempts)
3. The "Watch Ad for Extra Life" button should appear on the lose overlay
4. Tap the button to watch an ad
5. Complete the ad to receive an extra life
6. The game should allow you to continue playing

## Troubleshooting

### "Cannot find 'GADMobileAds' in scope"
- Ensure Google Mobile Ads SDK is added via Swift Package Manager
- Clean build folder (Cmd+Shift+K) and rebuild

### Ads not loading
- Check console logs for error messages
- Verify your AdMob App ID and Ad Unit ID are correct
- Ensure you're testing on a physical device (simulator may have issues)
- Check network connectivity

### "Ad not ready" message
- Ads take time to load; wait a few seconds after app launch
- Check AdMob console to ensure ad units are properly configured
- Verify your app is approved for serving ads in AdMob

## Production Checklist

Before submitting to the App Store:

- [ ] Replace test App ID with production App ID in `Info.plist`
- [ ] Replace test Ad Unit ID with production Ad Unit ID in `AdManager.swift`
- [ ] Test ads on multiple devices
- [ ] Verify App Tracking Transparency prompt displays correctly
- [ ] Ensure ads load and display properly
- [ ] Confirm life reward is granted after ad completion
- [ ] Test ad failure scenarios (no network, ad not ready)

## Additional Resources

- [Google Mobile Ads iOS Quickstart](https://developers.google.com/admob/ios/quick-start)
- [Rewarded Ads Implementation Guide](https://developers.google.com/admob/ios/rewarded)
- [AdMob Policy Guidelines](https://support.google.com/admob/answer/6128543)

# Quick Start: Adding Google Mobile Ads SDK

This is the **critical step** that must be done in Xcode to complete the ad integration. The code is ready, but the SDK package needs to be added.

## 5-Minute Setup

### Step 1: Open Project in Xcode
```bash
cd /path/to/mastermind
open CodeBreaker.xcodeproj
```

### Step 2: Add Swift Package
1. Click on your project in the navigator (CodeBreaker - blue icon at top)
2. Go to **File** menu → **Add Package Dependencies...**
3. In the search bar (top right), paste:
   ```
   https://github.com/googleads/swift-package-manager-google-mobile-ads.git
   ```
4. Click **Add Package**
5. Select **Version**: Up to Next Major Version → `11.0.0`
6. Click **Add Package** again
7. Ensure **CodeBreaker** target is checked
8. Click **Add Package** one more time

### Step 3: Build
- Press **Cmd+B** or go to **Product** → **Build**
- Wait for build to complete (1-2 minutes first time)
- Should succeed with no errors ✅

### Step 4: Run & Test
1. Select a device or simulator (physical device recommended)
2. Press **Cmd+R** or click the Play button
3. Play a level and intentionally lose
4. Tap "Watch Ad for Extra Life" button
5. Watch the ad (test ad will show)
6. Verify gameplay resumes with extra attempt

## Troubleshooting

### "Cannot find 'GADMobileAds' in scope"
**Solution**: Make sure you completed Step 2 above. The package must be added before building.

### Package won't resolve / download hangs
**Solutions**:
1. Check internet connection
2. Try: **File** → **Packages** → **Reset Package Caches**
3. Try: **File** → **Packages** → **Update to Latest Package Versions**

### Build errors about missing types
**Solution**: Clean build folder first:
- Press **Cmd+Shift+K** or go to **Product** → **Clean Build Folder**
- Then build again with **Cmd+B**

### Ads not showing on simulator
**Expected behavior**: Ads work better on physical devices. If using simulator:
- Ensure simulator has internet access
- Check console for error messages
- May need to wait 30 seconds for initial ad load

## Success Indicators

You'll know it's working when:
- ✅ Build succeeds without errors
- ✅ App launches on device/simulator
- ✅ Lose overlay shows "Watch Ad" button
- ✅ Button is enabled (not grayed out)
- ✅ Tapping button shows a test ad
- ✅ Completing ad grants extra life
- ✅ Gameplay resumes after ad

## What You Just Added

The Google Mobile Ads SDK provides:
- Ad loading and caching
- Ad presentation UI
- User tracking (with permission)
- Revenue attribution
- GDPR/CCPA compliance helpers

Our code (`AdManager.swift`) wraps this SDK to:
- Pre-load ads for better UX
- Integrate with our lives system
- Provide haptic feedback
- Handle errors gracefully

## Next: Production Setup

For production deployment, you'll need to:
1. Create AdMob account (if you haven't)
2. Register your app in AdMob console
3. Create rewarded ad unit
4. Replace test IDs with production IDs in code:
   - `Info.plist`: `GADApplicationIdentifier`
   - `AdManager.swift`: `rewardedAdUnitID`

See **ADS_SETUP.md** for detailed production setup.

## Still Having Issues?

Check these files:
- **ADS_SETUP.md** - Detailed setup guide
- **AD_IMPLEMENTATION_REVIEW.md** - Architecture overview
- **CODE_REVIEW_SUMMARY.md** - Complete review results

Or run the validation script:
```bash
./validate_ads.sh
```

## Support

- [Google Mobile Ads Documentation](https://developers.google.com/admob/ios/quick-start)
- [Swift Package Manager Guide](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
- [AdMob Support](https://support.google.com/admob)

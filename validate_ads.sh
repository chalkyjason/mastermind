#!/bin/bash
# Validation script for Code Breaker ad integration
# This script performs basic checks to validate the ad implementation

echo "================================================"
echo "Code Breaker - Ad Integration Validation Script"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for checks
PASSED=0
FAILED=0
WARNINGS=0

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} Found: $1"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} Missing: $1"
        ((FAILED++))
        return 1
    fi
}

check_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        ((FAILED++))
        return 1
    fi
}

warn_pattern() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} $description"
        ((WARNINGS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    fi
}

echo "1. Checking Core Files..."
echo "------------------------"
check_file "CodeBreaker/Services/AdManager.swift"
check_file "CodeBreaker/Services/LivesManager.swift"
check_file "CodeBreaker/Views/Game/GameView.swift"
check_file "CodeBreaker/Views/Game/GameOverlays.swift"
check_file "CodeBreaker/Models/MastermindGame.swift"
check_file "CodeBreaker/CodeBreakerApp.swift"
check_file "CodeBreaker/Info.plist"
echo ""

echo "2. Checking AdManager Implementation..."
echo "---------------------------------------"
check_pattern "CodeBreaker/Services/AdManager.swift" "import GoogleMobileAds" "Imports GoogleMobileAds SDK"
check_pattern "CodeBreaker/Services/AdManager.swift" "class AdManager.*ObservableObject" "AdManager is ObservableObject"
check_pattern "CodeBreaker/Services/AdManager.swift" "static let shared" "AdManager uses singleton pattern"
check_pattern "CodeBreaker/Services/AdManager.swift" "@Published.*isRewardedAdReady" "Publishes ad ready state"
check_pattern "CodeBreaker/Services/AdManager.swift" "func loadRewardedAd" "Has loadRewardedAd method"
check_pattern "CodeBreaker/Services/AdManager.swift" "func showRewardedAd" "Has showRewardedAd method"
check_pattern "CodeBreaker/Services/AdManager.swift" "GADFullScreenContentDelegate" "Implements ad delegate"
echo ""

echo "3. Checking LivesManager Integration..."
echo "---------------------------------------"
check_pattern "CodeBreaker/Services/LivesManager.swift" "func requestAdForLife" "Has requestAdForLife method"
check_pattern "CodeBreaker/Services/LivesManager.swift" "var isAdAvailable" "Has isAdAvailable property"
check_pattern "CodeBreaker/Services/LivesManager.swift" "AdManager.shared.showRewardedAd" "Calls AdManager for ads"
warn_pattern "CodeBreaker/Services/LivesManager.swift" "TODO.*[Aa]d" "No TODO comments for ad integration"
warn_pattern "CodeBreaker/Services/LivesManager.swift" "placeholder" "No placeholder code remaining"
echo ""

echo "4. Checking GameView Integration..."
echo "-----------------------------------"
check_pattern "CodeBreaker/Views/Game/GameView.swift" "@ObservedObject.*adManager.*AdManager" "Observes AdManager"
check_pattern "CodeBreaker/Views/Game/GameView.swift" "func handleWatchAd" "Has handleWatchAd method"
check_pattern "CodeBreaker/Views/Game/GameView.swift" "game.addExtraLife" "Calls addExtraLife on success"
check_pattern "CodeBreaker/Views/Game/GameView.swift" "showingLoseSheet.*false" "Dismisses overlay on success"
echo ""

echo "5. Checking GameOverlays UI..."
echo "------------------------------"
check_pattern "CodeBreaker/Views/Game/GameOverlays.swift" "struct LoseOverlayView" "Has LoseOverlayView"
check_pattern "CodeBreaker/Views/Game/GameOverlays.swift" "canWatchAd.*Bool" "Takes canWatchAd parameter"
check_pattern "CodeBreaker/Views/Game/GameOverlays.swift" "isAdReady.*Bool" "Takes isAdReady parameter"
check_pattern "CodeBreaker/Views/Game/GameOverlays.swift" "Watch Ad for Extra Life" "Has ad button text"
warn_pattern "CodeBreaker/Views/Game/GameOverlays.swift" "@State private var isLoadingAd = false.*@State private var isLoadingAd = false" "No duplicate state variables"
echo ""

echo "6. Checking MastermindGame Logic..."
echo "-----------------------------------"
check_pattern "CodeBreaker/Models/MastermindGame.swift" "func addExtraLife" "Has addExtraLife method"
check_pattern "CodeBreaker/Models/MastermindGame.swift" "var canUseExtraLife" "Has canUseExtraLife property"
check_pattern "CodeBreaker/Models/MastermindGame.swift" "bonusAttempts" "Tracks bonus attempts"
echo ""

echo "7. Checking App Initialization..."
echo "---------------------------------"
check_pattern "CodeBreaker/CodeBreakerApp.swift" "AdManager.configure" "Initializes AdManager in app init"
echo ""

echo "8. Checking Info.plist Configuration..."
echo "---------------------------------------"
check_pattern "CodeBreaker/Info.plist" "GADApplicationIdentifier" "Has AdMob App ID"
check_pattern "CodeBreaker/Info.plist" "SKAdNetworkItems" "Has SKAdNetwork items"
check_pattern "CodeBreaker/Info.plist" "NSUserTrackingUsageDescription" "Has tracking permission message"
echo ""

echo "9. Syntax Check (Basic)..."
echo "-------------------------"
# Check for common syntax errors
if grep -r "TODO" CodeBreaker/Services/AdManager.swift CodeBreaker/Services/LivesManager.swift 2>/dev/null | grep -i "ad"; then
    echo -e "${YELLOW}⚠${NC} Found TODO comments related to ads"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} No TODO comments for ad integration"
    ((PASSED++))
fi

# Check for duplicate imports
if [ $(grep -c "import GoogleMobileAds" CodeBreaker/Services/AdManager.swift 2>/dev/null) -gt 1 ]; then
    echo -e "${RED}✗${NC} Duplicate GoogleMobileAds imports"
    ((FAILED++))
else
    echo -e "${GREEN}✓${NC} No duplicate imports"
    ((PASSED++))
fi

echo ""
echo "10. Documentation Check..."
echo "-------------------------"
check_file "ADS_SETUP.md"
check_file "AD_IMPLEMENTATION_REVIEW.md"
echo ""

echo "================================================"
echo "Summary"
echo "================================================"
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Add Google Mobile Ads SDK in Xcode (see ADS_SETUP.md)"
    echo "2. Build project in Xcode"
    echo "3. Test on device or simulator"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the issues above.${NC}"
    echo ""
    exit 1
fi

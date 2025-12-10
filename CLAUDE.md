# CLAUDE.md - Code Breaker Project Guide

## Project Overview

**Code Breaker** is a modern iOS implementation of the classic Mastermind puzzle game, built with SwiftUI. Players deduce a secret color code through logical reasoning and feedback from their guesses.

- **Platform**: iOS 17.0+
- **Language**: Swift 5.0+
- **Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Bundle ID**: `com.yourname.CodeBreaker` (update before deployment)

## Project Structure

```
CodeBreaker/
├── CodeBreakerApp.swift          # App entry point, dependency injection
├── Models/                        # Data types and core game logic
│   ├── GameTypes.swift           # Enums, structs (PegColor, DifficultyTier, etc.)
│   └── MastermindGame.swift      # Core game logic, feedback algorithm
├── ViewModels/                    # State management
│   └── GameManager.swift         # Game state, persistence, progression
├── Views/                         # SwiftUI UI components
│   ├── ContentView.swift         # Main menu screen
│   ├── Game/
│   │   ├── GameView.swift        # Main gameplay screen
│   │   └── GameOverlays.swift    # Win/lose overlays
│   └── Menu/
│       ├── LevelSelectView.swift # Level selection
│       ├── DailyChallengeView.swift
│       ├── SettingsView.swift
│       └── HowToPlayView.swift
├── Services/                      # Peripheral services
│   ├── HapticManager.swift       # Haptic feedback patterns
│   └── GameCenterManager.swift   # Leaderboards & achievements
└── Resources/
    └── Assets.xcassets/          # Colors, icons, images
```

## Architecture & Design Patterns

### MVVM Pattern

1. **Models** (`Models/`):
   - Pure data types and business logic
   - No UI dependencies
   - Example: `MastermindGame` contains the core feedback algorithm

2. **ViewModels** (`ViewModels/`):
   - State management with `@Published` properties
   - Bridge between Models and Views
   - Example: `GameManager` handles progression, persistence, streaks

3. **Views** (`Views/`):
   - SwiftUI declarative UI
   - Observe ViewModels via `@EnvironmentObject` or `@StateObject`
   - Local state with `@State` for UI-only concerns

### Key Patterns

- **Singleton Pattern**: `HapticManager.shared`, `GameCenterManager.shared`
- **Environment Objects**: Dependency injection via `.environmentObject()`
- **ObservableObject**: State management (`@Published` properties)
- **Codable**: Persistence of game state via `JSONEncoder/JSONDecoder`
- **Seeded RNG**: Deterministic puzzle generation using `SeededRandomNumberGenerator`

### State Management

- **Global State**: `GameManager` (injected via `@EnvironmentObject`)
- **Local State**: Individual view controllers use `@State` for UI state
- **Persistence**: `UserDefaults` for game progress, settings
- **Keys**: Centralized in `GameManager.Keys` enum

## Core Game Mechanics

### Difficulty Tiers

Located in `GameTypes.swift:86-181`:

| Tier | Code Length | Colors | Attempts | Duplicates | Levels |
|------|-------------|--------|----------|------------|--------|
| Tutorial | 3 | 4 | 10 | No | 10 |
| Beginner | 4 | 5 | 10 | No | 30 |
| Intermediate | 4 | 6 | 8 | Yes | 50 |
| Advanced | 4 | 6 | 7 | Yes | 60 |
| Expert | 5 | 7 | 7 | Yes | 80 |
| Master | 5 | 8 | 6 | Yes | 100 |

**Total**: 330 levels

### Feedback Algorithm

Located in `MastermindGame.swift:119-163`:

The `calculateFeedback()` method implements the classic Mastermind algorithm:

1. **Black pegs**: Exact matches (correct color, correct position)
2. **White pegs**: Color matches (correct color, wrong position)
3. **Empty**: No match for remaining positions

**Algorithm Steps**:
1. Mark exact position matches as black, remove from consideration
2. Find color matches in remaining positions, mark as white
3. Fill remaining slots with empty pegs
4. Sort feedback (black, white, empty)

**Critical**: Feedback is sorted and doesn't reveal which positions are correct!

### Level Generation

Located in `MastermindGame.swift:38-73`:

- **Seeded Levels**: Use `SeededRandomNumberGenerator` with `levelId * 12345` for consistent puzzles
- **Random Practice**: No seed for truly random codes
- **Daily Challenge**: Seed based on date (`YYYYMMDD` format) for consistent daily puzzles

### Star Rating

Located in `GameTypes.swift:198-207`:

- **3 stars**: ≤40% of max attempts used
- **2 stars**: ≤70% of max attempts used
- **1 star**: Completed within max attempts

## Development Workflows

### Adding New Features

1. **Models First**: Define data structures in `Models/GameTypes.swift`
2. **Logic**: Implement core logic in appropriate model (e.g., `MastermindGame`)
3. **ViewModel**: Add state management to `GameManager` if needed
4. **Views**: Create/modify SwiftUI views
5. **Services**: Integrate peripheral features (haptics, Game Center)

### Modifying Difficulty

Edit `DifficultyTier` enum in `GameTypes.swift:86-181`:

```swift
var codeLength: Int { ... }     // Length of secret code
var colorCount: Int { ... }     // Number of available colors
var maxAttempts: Int { ... }    // Attempts allowed
var allowDuplicates: Bool { ... } // Allow repeated colors
var levelsCount: Int { ... }    // Levels in this tier
```

### Adding Haptic Feedback

Use `HapticManager.shared` (`Services/HapticManager.swift`):

```swift
HapticManager.shared.impact(.medium)        // Impact feedback
HapticManager.shared.notification(.success) // Notification feedback
HapticManager.shared.selection()            // Selection feedback
```

**Custom Patterns**: See game-specific haptics in `HapticManager.swift:43-109`

### Game Center Integration

Located in `Services/GameCenterManager.swift`:

**Leaderboard IDs** (`GameCenterManager.swift:14-19`):
- `com.codebreaker.totalstars`
- `com.codebreaker.longeststreak`
- `com.codebreaker.dailystreak`
- `com.codebreaker.levelscompleted`

**Achievement IDs** (`GameCenterManager.swift:22-49`):
Configure these in App Store Connect before release.

**Reporting**:
```swift
GameCenterManager.shared.reportScore(score, to: .totalStars)
GameCenterManager.shared.unlockAchievement(.firstWin)
GameCenterManager.shared.reportStreak(streak)
```

## Code Conventions

### Naming

- **Files**: PascalCase, descriptive (e.g., `GameCenterManager.swift`)
- **Types**: PascalCase (e.g., `DifficultyTier`, `PegColor`)
- **Variables/Functions**: camelCase (e.g., `currentGuess`, `submitGuess()`)
- **Constants**: camelCase (e.g., `maxAttempts`)
- **Private**: Use `private` or `private(set)` liberally

### Organization

- **MARK Comments**: All files use `// MARK: - Section Name` for organization
- **Sections**: Group related functionality (e.g., `// MARK: - Gameplay`)
- **Extensions**: Use extensions for protocol conformance, computed properties

### SwiftUI Patterns

1. **Property Wrappers**:
   - `@State`: Local view state
   - `@StateObject`: View owns the object lifecycle
   - `@ObservedObject`: View observes but doesn't own
   - `@EnvironmentObject`: Dependency injection from ancestor
   - `@Published`: ViewModel state that triggers view updates

2. **View Composition**:
   - Break complex views into smaller components
   - Each view component is a separate struct
   - Example: `GameView` uses `GuessRowView`, `ColorPickerView`, etc.

3. **Navigation**:
   - `NavigationStack` for hierarchical navigation
   - `.navigationDestination(isPresented:)` for programmatic navigation
   - `.sheet(isPresented:)` for modal sheets

4. **Styling**:
   - Custom `ButtonStyle` (e.g., `ScaleButtonStyle`)
   - Consistent corner radius: 12-16pt (continuous)
   - Consistent shadows: `radius: 4-8`, `y: 2-4`

### Color System

All colors defined in `Resources/Assets.xcassets/`:

**Peg Colors**: `PegRed`, `PegBlue`, `PegGreen`, `PegYellow`, `PegPurple`, `PegOrange`, `PegPink`, `PegCyan`

**Accent Colors**: `AccentBlue`, `AccentGreen`, `AccentOrange`, `AccentPurple`, `AccentGold`, `AccentYellow`, `AccentGray`

**Background**: `BackgroundTop`, `BackgroundBottom` (gradient)

**Usage**: `Color("PegRed")` or `pegColor.color`

## Persistence

### UserDefaults Keys

Located in `GameManager.Keys` enum (`GameManager.swift:18-24`):

- `savedLevels`: JSON-encoded `[GameLevel]`
- `currentStreak`: Int
- `longestStreak`: Int
- `lastPlayedDate`: Date
- `completedDailyChallenges`: JSON-encoded `[DailyChallenge]`
- `hapticsEnabled`: Bool

### Saving/Loading

```swift
// Save
if let encoded = try? JSONEncoder().encode(data) {
    defaults.set(encoded, forKey: key)
}

// Load
if let data = defaults.data(forKey: key),
   let decoded = try? JSONDecoder().decode(Type.self, from: data) {
    return decoded
}
```

## Testing & Debugging

### Debug Features

- **Reset Progress**: `GameManager.resetAllProgress()` (available in Settings)
- **Unlock All Tiers**: `GameManager.unlockTier(_:)` for testing
- **Custom Codes**: Pass `customCode:` parameter to `MastermindGame` initializer

### Common Testing Scenarios

1. **Test Specific Level**:
   ```swift
   let game = MastermindGame(tier: .intermediate, level: level)
   ```

2. **Test Random Game**:
   ```swift
   let game = MastermindGame(tier: .expert, level: nil)
   ```

3. **Test Known Code**:
   ```swift
   let game = MastermindGame(tier: .beginner, customCode: [.red, .blue, .green, .yellow])
   ```

### Previews

All major views include SwiftUI `#Preview` macros:

```swift
#Preview {
    ContentView()
        .environmentObject(GameManager())
        .environmentObject(GameCenterManager())
}
```

## Build Configuration

### Xcode Project Settings

- **Deployment Target**: iOS 17.0
- **Swift Version**: 5.0
- **Bundle ID**: `com.yourname.CodeBreaker` (⚠️ **Update before release**)
- **Version**: 1.0
- **Build**: 1
- **Capabilities Required**:
  - Game Center (optional, for leaderboards/achievements)

### Before App Store Submission

1. **Update Bundle Identifier**: Change from `com.yourname.CodeBreaker`
2. **Configure Signing**: Add development team in Xcode
3. **Game Center Setup** (optional):
   - Create leaderboards in App Store Connect
   - Create achievements with IDs from `GameCenterManager.AchievementID`
4. **App Icon**: Replace placeholder in `Assets.xcassets/AppIcon.appiconset`
5. **Privacy**: No special permissions required (purely offline game)

## Performance Considerations

### Optimization Patterns

1. **Lazy Loading**: Views use `LazyVGrid` for feedback pegs
2. **State Minimization**: Only publish properties that affect UI
3. **Animation Performance**: Use `.animation(_:value:)` for targeted animations
4. **Memory**:
   - Game state is minimal (arrays of enums)
   - UserDefaults for persistence (lightweight)
   - No image assets for pegs (pure SwiftUI shapes)

### Potential Bottlenecks

- **Level Generation**: All 330 levels generated on first launch (acceptable one-time cost)
- **ScrollView**: Large guess history (max 10 rows) - negligible impact
- **Haptics**: Sequential dispatch in `feedbackReveal` - intentional for UX

## Common Tasks

### Add a New Peg Color

1. Add case to `PegColor` enum (`GameTypes.swift:5-47`)
2. Add color mapping in `color` computed property
3. Add asset color in `Assets.xcassets/Peg[Name].colorset`
4. Add accessibility pattern (optional)
5. Update tier `colorCount` to include new color

### Add a New View Screen

1. Create SwiftUI view file in appropriate `Views/` subdirectory
2. Add navigation in parent view:
   ```swift
   .navigationDestination(isPresented: $showingNewView) {
       NewView()
   }
   ```
3. Inject environment objects if needed
4. Add Preview for development

### Modify Streak Logic

Located in `GameManager.swift:166-213`:

- `updateStreak()`: Check streak on app launch
- `updateStreakOnWin()`: Update streak after completing a level/daily challenge
- Streak resets if >1 day gap

### Add Achievement

1. Add case to `GameCenterManager.AchievementID` (`GameCenterManager.swift:22-49`)
2. Create achievement in App Store Connect with matching ID
3. Call `GameCenterManager.shared.unlockAchievement(.yourAchievement)` when earned

## Accessibility

### Current Features

- All peg colors have `accessibilityLabel` (`GameTypes.swift:30-32`)
- Colorblind-friendly patterns defined (not yet implemented in UI)
- Haptic feedback provides non-visual feedback

### Future Enhancements

- Implement pattern overlays for colorblind users
- VoiceOver support for game state
- Dynamic Type support for all text

## Known Limitations

1. **No iCloud Sync**: Progress stored locally only
2. **No Undo**: Cannot undo submitted guesses
3. **No Hints**: No hint system (intentional design choice)
4. **Pattern Overlays**: Defined but not rendered in UI
5. **Game Center**: Optional, gracefully degrades if unavailable

## Dependencies

**None!** This is a pure SwiftUI + UIKit (haptics) project with no external dependencies.

- ✅ No CocoaPods
- ✅ No Swift Package Manager dependencies
- ✅ No Carthage
- ✅ Fully self-contained

## Git Workflow

### Branch Naming

- Feature branches: `feature/description`
- Bug fixes: `fix/description`
- Claude branches: `claude/description-sessionid`

### Commit Messages

Follow conventional commit style:
- `feat: Add new feature`
- `fix: Resolve bug`
- `refactor: Restructure code`
- `style: Update UI/formatting`
- `docs: Update documentation`

### Pre-Commit Checklist

- [ ] Code compiles without warnings
- [ ] SwiftUI previews render correctly
- [ ] No force-unwraps in new code (use guard/if-let)
- [ ] MARK comments added for new sections
- [ ] Test on device if using haptics/Game Center

## Troubleshooting

### Common Issues

**Issue**: Game Center not authenticating
- **Solution**: Check capabilities in Xcode, sign in to Game Center on device

**Issue**: Haptics not working
- **Solution**: Test on physical device (simulator doesn't support haptics)

**Issue**: Levels not saving
- **Solution**: Check `GameManager.saveData()` is called after modifications

**Issue**: Daily challenge shows wrong date
- **Solution**: `DailyChallenge.forToday()` uses device time zone

**Issue**: SwiftUI previews not working
- **Solution**: Ensure preview includes all required `@EnvironmentObject` dependencies

## Quick Reference

### File Locations

- **Core Game Logic**: `Models/MastermindGame.swift:119-163` (feedback algorithm)
- **Difficulty Config**: `Models/GameTypes.swift:86-181`
- **Persistence**: `ViewModels/GameManager.swift:223-255`
- **Main Menu**: `Views/ContentView.swift`
- **Gameplay Screen**: `Views/Game/GameView.swift`
- **Haptic Patterns**: `Services/HapticManager.swift:43-109`

### Key Functions

- **Submit Guess**: `MastermindGame.submitGuess()` (`MastermindGame.swift:95-117`)
- **Complete Level**: `GameManager.completeLevel(_:stars:attempts:)` (`GameManager.swift:77-110`)
- **Daily Challenge**: `DailyChallenge.forToday()` (`GameTypes.swift:236-256`)
- **Feedback Calc**: `MastermindGame.calculateFeedback(guess:)` (`MastermindGame.swift:121-163`)

### Environment Objects

Always inject in app root (`CodeBreakerApp.swift:10-15`):
```swift
.environmentObject(gameManager)
.environmentObject(gameCenterManager)
```

## Best Practices for AI Assistants

### When Adding Features

1. ✅ **DO**: Follow existing patterns (MVVM, MARK comments, naming)
2. ✅ **DO**: Use `@Published` for state that affects UI
3. ✅ **DO**: Add haptic feedback for user interactions
4. ✅ **DO**: Include SwiftUI previews for new views
5. ✅ **DO**: Test on physical device if using haptics/Game Center
6. ❌ **DON'T**: Add external dependencies without discussion
7. ❌ **DON'T**: Use force-unwraps; prefer guard/if-let
8. ❌ **DON'T**: Modify core game algorithm without careful testing

### When Debugging

1. Check `@Published` properties are in `ObservableObject` classes
2. Verify environment objects are injected in view hierarchy
3. Use Xcode previews for rapid UI iteration
4. Test Game Center features on physical device
5. Remember: Simulators don't support haptics

### When Refactoring

1. Maintain existing MARK comment structure
2. Keep view files focused (break into subviews if >500 lines)
3. Preserve existing public APIs for backward compatibility
4. Update this CLAUDE.md if architecture changes

---

**Last Updated**: 2025-12-10
**Project Version**: 1.0
**Xcode Version**: 15.0+

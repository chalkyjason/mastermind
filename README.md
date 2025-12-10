# Code Breaker - Mastermind Puzzle Game

A beautiful SwiftUI implementation of the classic Mastermind code-breaking puzzle game for iOS.

## Features

- **Classic Mastermind Gameplay**: Guess the secret color code using logical deduction
- **6 Difficulty Tiers**: Tutorial through Master with 330+ levels total
- **Daily Challenges**: New puzzle every day with streak tracking
- **Game Center Integration**: Leaderboards and achievements
- **Haptic Feedback**: Rich tactile feedback throughout the game
- **Beautiful UI**: Modern gradient-based design with smooth animations

## Difficulty Tiers

| Tier | Code Length | Colors | Attempts | Levels |
|------|-------------|--------|----------|--------|
| Tutorial | 3 | 4 | 10 | 10 |
| Beginner | 4 | 5 | 10 | 30 |
| Intermediate | 4 | 6 | 8 | 50 |
| Advanced | 4 | 6 | 7 | 60 |
| Expert | 5 | 7 | 7 | 80 |
| Master | 5 | 8 | 6 | 100 |

## How to Play

1. **Goal**: Guess the secret color code within the allowed attempts
2. **Make a Guess**: Tap slots to select colors, then submit your guess
3. **Read Feedback**:
   - ⚫ **Black peg**: Correct color in correct position
   - ⚪ **White peg**: Correct color in wrong position
   - Empty: Color not in remaining positions
4. **Win**: Get all black pegs to crack the code!

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/CodeBreaker.git
   ```

2. Open `CodeBreaker.xcodeproj` in Xcode

3. Select your development team in Signing & Capabilities

4. Build and run on your device or simulator

## Game Center Setup (Optional)

To enable Game Center features:

1. Enable Game Center capability in Xcode
2. Create leaderboards in App Store Connect:
   - `com.codebreaker.totalstars` - Total Stars
   - `com.codebreaker.longeststreak` - Longest Streak
   - `com.codebreaker.levelscompleted` - Levels Completed

3. Create achievements in App Store Connect (see `GameCenterManager.swift` for IDs)

## Project Structure

```
CodeBreaker/
├── CodeBreakerApp.swift      # App entry point
├── Models/
│   ├── GameTypes.swift       # Enums and data types
│   └── MastermindGame.swift  # Core game logic
├── ViewModels/
│   └── GameManager.swift     # State management & persistence
├── Views/
│   ├── ContentView.swift     # Main menu
│   ├── Game/
│   │   ├── GameView.swift    # Main gameplay screen
│   │   └── GameOverlays.swift # Win/lose screens
│   └── Menu/
│       ├── LevelSelectView.swift
│       ├── DailyChallengeView.swift
│       ├── SettingsView.swift
│       └── HowToPlayView.swift
├── Services/
│   ├── HapticManager.swift   # Haptic feedback
│   └── GameCenterManager.swift
└── Resources/
    └── Assets.xcassets/      # Colors and images
```

## Customization

### Changing Colors

Edit the color assets in `Resources/Assets.xcassets/` to customize the game's appearance.

### Adjusting Difficulty

Modify `DifficultyTier` in `GameTypes.swift` to change:
- Code length
- Number of colors
- Maximum attempts
- Levels per tier

### Bundle Identifier

Update `PRODUCT_BUNDLE_IDENTIFIER` in the project settings before submitting to the App Store.

## License

MIT License - feel free to use this code for your own projects!

## Credits

Inspired by the classic Mastermind board game and the GiiKER Super Decoder puzzle console.

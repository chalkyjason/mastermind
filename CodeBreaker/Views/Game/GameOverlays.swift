import SwiftUI

// MARK: - Win Overlay

struct WinOverlayView: View {
    let attempts: Int
    let maxAttempts: Int
    let secretCode: [PegColor]
    let isDaily: Bool
    let onContinue: () -> Void
    let onReplay: () -> Void
    
    @State private var showingStars = false
    @State private var starAnimations: [Bool] = [false, false, false]
    
    var stars: Int {
        GameLevel.calculateStars(attempts: attempts, maxAttempts: maxAttempts)
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Title
                Text(isDaily ? "Daily Challenge Complete!" : "Level Complete!")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                
                // Secret code reveal
                HStack(spacing: 8) {
                    ForEach(0..<secretCode.count, id: \.self) { index in
                        Circle()
                            .fill(secretCode[index].color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                
                // Attempts info
                Text("Solved in \(attempts) attempt\(attempts == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                // Stars
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 48))
                            .foregroundColor(index < stars ? Color("AccentYellow") : .gray)
                            .scaleEffect(starAnimations[index] ? 1.2 : 0.5)
                            .opacity(starAnimations[index] ? 1 : 0.3)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.2),
                                value: starAnimations[index]
                            )
                    }
                }
                .padding(.vertical, 16)
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.primaryButtonTap()
                        onContinue()
                    }) {
                        Text(isDaily ? "Done" : "Continue")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentGreen"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if !isDaily {
                        Button(action: {
                            HapticManager.shared.gameRestart()
                            onReplay()
                        }) {
                            Text("Play Again")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("BackgroundTop").opacity(0.95))
            )
            .padding(24)
        }
        .onAppear {
            // Animate stars
            for i in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2 + 0.3) {
                    starAnimations[i] = true
                    HapticManager.shared.starEarned()
                }
            }
        }
    }
}

// MARK: - Lose Overlay

struct LoseOverlayView: View {
    let secretCode: [PegColor]
    let canWatchAd: Bool
    let isAdReady: Bool
    let onWatchAd: () -> Void
    let onRetry: () -> Void
    let onQuit: () -> Void

    @State private var isLoadingAd = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text("Out of Attempts")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)

                Text("The code was:")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))

                // Secret code reveal
                HStack(spacing: 8) {
                    ForEach(0..<secretCode.count, id: \.self) { index in
                        Circle()
                            .fill(secretCode[index].color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: secretCode[index].color.opacity(0.5), radius: 8, y: 2)
                    }
                }
                .padding(.vertical, 8)

                // Encouragement
                Text("Don't give up! Try again.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                // Buttons
                VStack(spacing: 12) {
                    // Watch Ad for Extra Life button
                    if canWatchAd {
                        Button(action: {
                            HapticManager.shared.primaryButtonTap()
                            isLoadingAd = true
                            onWatchAd()
                        }) {
                            HStack(spacing: 8) {
                                if isLoadingAd {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.title3)
                                }
                                Text("Watch Ad for Extra Life")
                                    .font(.headline.weight(.bold))
                                Spacer()
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                Text("+1")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    colors: [Color("AccentPurple"), Color("AccentBlue")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color("AccentPurple").opacity(0.4), radius: 8, y: 4)
                        }
                        .disabled(!isAdReady || isLoadingAd)
                        .opacity(isAdReady && !isLoadingAd ? 1 : 0.6)

                        if !isAdReady && !isLoadingAd {
                            Text("Loading ad...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Button(action: {
                        HapticManager.shared.gameRestart()
                        onRetry()
                    }) {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentOrange"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button(action: {
                        HapticManager.shared.secondaryButtonTap()
                        onQuit()
                    }) {
                        Text("Quit")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("BackgroundTop").opacity(0.95))
            )
            .padding(24)
        }
    }
}

#Preview("Win") {
    WinOverlayView(
        attempts: 4,
        maxAttempts: 10,
        secretCode: [.red, .blue, .green, .yellow],
        isDaily: false,
        onContinue: {},
        onReplay: {}
    )
}

#Preview("Lose") {
    LoseOverlayView(
        secretCode: [.red, .blue, .green, .yellow],
        canWatchAd: true,
        isAdReady: true,
        onWatchAd: {},
        onRetry: {},
        onQuit: {}
    )
}

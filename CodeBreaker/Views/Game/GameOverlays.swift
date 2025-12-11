import SwiftUI
import Foundation

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
    @State private var showConfetti = false
    @State private var codeRevealed = false
    @State private var showContent = false
    @AppStorage("colorblindMode") private var colorblindMode = false

    var stars: Int {
        GameLevel.calculateStars(attempts: attempts, maxAttempts: maxAttempts)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Confetti
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                // Title
                Text(isDaily ? "Daily Challenge Complete!" : "Level Complete!")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)

                // Secret code reveal with animation
                HStack(spacing: 8) {
                    ForEach(0..<secretCode.count, id: \.self) { index in
                        ZStack {
                            Circle()
                                .fill(secretCode[index].color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: secretCode[index].color.opacity(0.5), radius: 8, y: 2)

                            // Colorblind pattern
                            if colorblindMode {
                                Image(systemName: secretCode[index].pattern)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            }
                        }
                        .scaleEffect(codeRevealed ? 1 : 0)
                        .opacity(codeRevealed ? 1 : 0)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6)
                                .delay(Double(index) * 0.1 + 0.3),
                            value: codeRevealed
                        )
                    }
                }
                
                // Attempts info
                Text("Solved in \(attempts) attempt\(attempts == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: showContent)
                
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
                    .buttonStyle(ScaleButtonStyle())

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
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 32)
                .offset(y: showContent ? 0 : 20)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(1.2), value: showContent)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("BackgroundTop").opacity(0.95))
            )
            .padding(24)
        }
        .onAppear {
            // Show confetti immediately
            showConfetti = true

            // Reveal content in sequence
            withAnimation {
                showContent = true
                codeRevealed = true
            }

            // Animate stars with haptics and sound
            for i in 0..<stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2 + 0.8) {
                    starAnimations[i] = true
                    HapticManager.shared.starEarned()
                    SoundManager.shared.starEarned()
                }
            }
        }
    }
}

// MARK: - Lose Overlay

struct LoseOverlayView: View {
    @EnvironmentObject var livesManager: LivesManager

    let secretCode: [PegColor]
    let onRetry: () -> Void
    let onQuit: () -> Void

    @State private var showContent = false
    @State private var codeRevealed = false
    @State private var isLoadingAd = false
    @AppStorage("colorblindMode") private var colorblindMode = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3), value: showContent)

            VStack(spacing: 24) {
                // Title
                Text("Out of Attempts")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showContent)

                Text("The code was:")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.4), value: showContent)

                // Secret code reveal with staggered animation
                HStack(spacing: 8) {
                    ForEach(0..<secretCode.count, id: \.self) { index in
                        ZStack {
                            Circle()
                                .fill(secretCode[index].color)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: secretCode[index].color.opacity(0.5), radius: 8, y: 2)

                            // Colorblind pattern
                            if colorblindMode {
                                Image(systemName: secretCode[index].pattern)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            }
                        }
                        .scaleEffect(codeRevealed ? 1 : 0)
                        .blur(radius: codeRevealed ? 0 : 10)
                        .opacity(codeRevealed ? 1 : 0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                                .delay(Double(index) * 0.15 + 0.6),
                            value: codeRevealed
                        )
                    }
                }
                .padding(.vertical, 8)

                // Lives remaining
                HStack(spacing: 6) {
                    ForEach(0..<LivesManager.maxLives, id: \.self) { index in
                        Image(systemName: index < livesManager.lives ? "heart.fill" : "heart")
                            .foregroundColor(index < livesManager.lives ? Color("PegRed") : .gray.opacity(0.5))
                            .font(.title3)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.8), value: showContent)

                // Encouragement or warning
                if livesManager.hasLives {
                    Text("Don't give up! Try again.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(1.0), value: showContent)
                } else {
                    VStack(spacing: 4) {
                        Text("No lives remaining!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color("AccentOrange"))
                        if let timeString = livesManager.formattedTimeUntilNextLife {
                            Text("Next life in \(timeString)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(1.0), value: showContent)
                }

                // Buttons
                VStack(spacing: 12) {
                    // Watch Ad Button (always show if ad is available and not full lives)
                    if livesManager.isAdAvailable && !livesManager.isFull {
                        Button(action: watchAdForLife) {
                            HStack {
                                if isLoadingAd {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.rectangle.fill")
                                }
                                Text("Watch Ad for Life")
                            }
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentPurple"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isLoadingAd)
                    }

                    // Try Again Button (disabled if no lives)
                    Button(action: {
                        HapticManager.shared.gameRestart()
                        onRetry()
                    }) {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(livesManager.hasLives ? Color("AccentOrange") : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!livesManager.hasLives)

                    Button(action: onQuit) {
                        Text("Quit")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 32)
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(1.2), value: showContent)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("BackgroundTop").opacity(0.95))
            )
            .padding(24)
        }
        .onAppear {
            withAnimation {
                showContent = true
                codeRevealed = true
            }
        }
    }

    private func watchAdForLife() {
        isLoadingAd = true
        livesManager.requestAdForLife { success in
            isLoadingAd = false
            if !success {
                // Ad failed to load - could show an alert here
                HapticManager.shared.notification(.error)
            }
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
        onRetry: {},
        onQuit: {}
    )
    .environmentObject(LivesManager.shared)
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ConfettiPiece(particle: particle)
            }
        }
        .onAppear {
            startConfetti()
        }
    }

    private func startConfetti() {
        // Create 50 confetti particles
        for i in 0..<50 {
            let delay = Double(i) * 0.02
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let particle = ConfettiParticle()
                particles.append(particle)

                // Remove particle after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles.remove(at: index)
                    }
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat

    init() {
        let colors: [Color] = [
            Color("AccentYellow"),
            Color("AccentOrange"),
            Color("AccentGreen"),
            Color("AccentPurple"),
            Color("AccentBlue"),
            Color("PegRed"),
            Color("PegPink")
        ]
        self.color = colors.randomElement() ?? .yellow
        self.x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
        self.y = -50
        self.rotation = Double.random(in: 0...360)
        self.scale = CGFloat.random(in: 0.3...1.0)
    }
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    @State private var yOffset: CGFloat = 0
    @State private var rotationAmount: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: 10, height: 10)
            .scaleEffect(particle.scale)
            .rotationEffect(.degrees(rotationAmount))
            .position(x: particle.x, y: particle.y + yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeIn(duration: 3.0)
                ) {
                    yOffset = UIScreen.main.bounds.height + 100
                    opacity = 0
                }

                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    rotationAmount = particle.rotation + 720
                }
            }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}


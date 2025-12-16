import SwiftUI

// MARK: - Game Mode

enum GameMode: String, CaseIterable {
    case codeBreaker = "Code Breaker"
    case ballSort = "Ball Sort"

    var icon: String {
        switch self {
        case .codeBreaker: return "lock.shield"
        case .ballSort: return "testtube.2"
        }
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: GameMode = .codeBreaker
    @State private var currentPage = 0

    let codeBreakerPages: [TutorialPage] = [
        TutorialPage(
            title: "Crack the Code",
            description: "Your goal is to guess the secret color code. Each position in the code contains one color.",
            imageName: "lock.shield",
            colors: [.red, .blue, .green, .yellow]
        ),
        TutorialPage(
            title: "Make a Guess",
            description: "Tap each slot to select a color. Fill all slots, then submit your guess to get feedback.",
            imageName: "hand.tap",
            colors: nil
        ),
        TutorialPage(
            title: "Black = Perfect Match",
            description: "A black peg means you have the RIGHT color in the RIGHT position. This is what you want!",
            imageName: "circle.fill",
            feedbackDemo: .black
        ),
        TutorialPage(
            title: "White = Close",
            description: "A white peg means you have the RIGHT color but in the WRONG position. It's in the code, just not there.",
            imageName: "circle",
            feedbackDemo: .white
        ),
        TutorialPage(
            title: "Empty = Not in Code",
            description: "No peg means that color isn't in the remaining positions of the secret code.",
            imageName: "circle.dashed",
            feedbackDemo: .empty
        ),
        TutorialPage(
            title: "Win by Deduction",
            description: "Use the feedback to narrow down possibilities. All black pegs = you've cracked the code!",
            imageName: "brain.head.profile",
            colors: nil
        )
    ]

    let ballSortPages: [TutorialPage] = [
        TutorialPage(
            title: "Sort the Balls",
            description: "Your goal is to sort all balls by color. Each tube can hold up to 4 balls of the same color.",
            imageName: "testtube.2",
            ballSortDemo: .goal
        ),
        TutorialPage(
            title: "Drag to Move",
            description: "Drag a ball from one tube and drop it into another. The ball will smoothly follow your finger.",
            imageName: "hand.draw",
            ballSortDemo: .drag
        ),
        TutorialPage(
            title: "Match Colors Only",
            description: "You can only place a ball on top of the same color, or into an empty tube.",
            imageName: "checkmark.circle",
            ballSortDemo: .matching
        ),
        TutorialPage(
            title: "Use Empty Tubes",
            description: "Empty tubes are key to solving puzzles. Use them strategically to move balls around.",
            imageName: "arrow.left.arrow.right",
            ballSortDemo: .empty
        ),
        TutorialPage(
            title: "Complete All Tubes",
            description: "Fill each tube with 4 balls of the same color to win. Fewer moves = more stars!",
            imageName: "star.fill",
            ballSortDemo: .win
        )
    ]

    var currentPages: [TutorialPage] {
        selectedMode == .codeBreaker ? codeBreakerPages : ballSortPages
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundTop")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Game mode selector
                    HStack(spacing: 0) {
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMode = mode
                                    currentPage = 0
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: mode.icon)
                                        .font(.subheadline.weight(.semibold))
                                    Text(mode.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(selectedMode == mode ? .white : .white.opacity(0.5))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedMode == mode ?
                                    Color.white.opacity(0.2) :
                                    Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    TabView(selection: $currentPage) {
                        ForEach(0..<currentPages.count, id: \.self) { index in
                            TutorialPageView(page: currentPages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<currentPages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 16)

                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Label("Back", systemImage: "chevron.left")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        if currentPage < currentPages.count - 1 {
                            Button(action: {
                                withAnimation {
                                    currentPage += 1
                                }
                            }) {
                                Label("Next", systemImage: "chevron.right")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(Color("AccentBlue"))
                                    .clipShape(Capsule())
                            }
                        } else {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Got It!")
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color("AccentGreen"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

// MARK: - Ball Sort Demo Type

enum BallSortDemoType {
    case goal
    case drag
    case matching
    case empty
    case win
}

// MARK: - Tutorial Page Model

struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
    var colors: [PegColor]? = nil
    var feedbackDemo: FeedbackPeg? = nil
    var ballSortDemo: BallSortDemoType? = nil
}

// MARK: - Tutorial Page View

struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 120)

                if let feedback = page.feedbackDemo {
                    // Show feedback peg demo
                    Circle()
                        .fill(feedback.color)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(feedback == .empty ? Color.gray : Color.white.opacity(0.3), lineWidth: 3)
                        )
                } else {
                    Image(systemName: page.imageName)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
            }

            // Title
            Text(page.title)
                .font(.title.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Color demo if applicable
            if let colors = page.colors {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                .padding(.top, 16)
            }

            // Example guess if showing feedback
            if let feedbackDemo = page.feedbackDemo {
                ExampleGuessView(feedback: feedbackDemo)
                    .padding(.top, 16)
            }

            // Ball Sort demo if applicable
            if let ballSortDemo = page.ballSortDemo {
                BallSortDemoView(demoType: ballSortDemo)
                    .padding(.top, 16)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Example Guess View

struct ExampleGuessView: View {
    let feedback: FeedbackPeg
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Example:")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 16) {
                // Example guess
                HStack(spacing: 6) {
                    Circle().fill(PegColor.red.color).frame(width: 32, height: 32)
                    Circle().fill(PegColor.blue.color).frame(width: 32, height: 32)
                    Circle().fill(PegColor.green.color).frame(width: 32, height: 32)
                    Circle().fill(PegColor.yellow.color).frame(width: 32, height: 32)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.white.opacity(0.5))
                
                // Feedback
                LazyVGrid(columns: [GridItem(.fixed(14)), GridItem(.fixed(14))], spacing: 4) {
                    Circle().fill(feedback.color).frame(width: 14, height: 14)
                    Circle().fill(FeedbackPeg.empty.color).frame(width: 14, height: 14)
                    Circle().fill(FeedbackPeg.empty.color).frame(width: 14, height: 14)
                    Circle().fill(FeedbackPeg.empty.color).frame(width: 14, height: 14)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Ball Sort Demo View

struct BallSortDemoView: View {
    let demoType: BallSortDemoType

    var body: some View {
        VStack(spacing: 12) {
            switch demoType {
            case .goal:
                goalDemo
            case .drag:
                dragDemo
            case .matching:
                matchingDemo
            case .empty:
                emptyDemo
            case .win:
                winDemo
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Goal Demo

    private var goalDemo: some View {
        HStack(spacing: 16) {
            // Mixed tube
            MiniTubeView(balls: [.red, .blue, .red, .green], isComplete: false)

            Image(systemName: "arrow.right")
                .foregroundColor(.white.opacity(0.5))
                .font(.title3)

            // Sorted tubes
            MiniTubeView(balls: [.red, .red, .red, .red], isComplete: true)
        }
    }

    // MARK: - Drag Demo

    private var dragDemo: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                // Dragging ball indicator
                ZStack {
                    Circle()
                        .fill(PegColor.red.color)
                        .frame(width: 24, height: 24)
                    Image(systemName: "hand.point.up.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(x: 10, y: 10)
                }
                .offset(y: -12)

                MiniTubeView(balls: [.blue, .red, .red], isComplete: false)
            }

            // Curved arrow showing drag motion
            Image(systemName: "arrow.right.circle")
                .foregroundColor(Color("AccentGreen"))
                .font(.title2)

            MiniTubeView(balls: [.red], isComplete: false, isHighlighted: true)
        }
    }

    // MARK: - Matching Demo

    private var matchingDemo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color("AccentGreen"))
                        .font(.caption)
                    MiniTubeView(balls: [.red, .red], isComplete: false)
                    Text("OK")
                        .font(.caption2)
                        .foregroundColor(Color("AccentGreen"))
                }

                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    MiniTubeView(balls: [.red, .blue], isComplete: false)
                    Text("No")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Empty Demo

    private var emptyDemo: some View {
        HStack(spacing: 16) {
            MiniTubeView(balls: [.red, .blue, .green, .red], isComplete: false)

            Image(systemName: "arrow.right")
                .foregroundColor(.white.opacity(0.5))

            MiniTubeView(balls: [], isComplete: false, isHighlighted: true)

            Text("Use empty\ntubes!")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Win Demo

    private var winDemo: some View {
        HStack(spacing: 12) {
            MiniTubeView(balls: [.red, .red, .red, .red], isComplete: true)
            MiniTubeView(balls: [.blue, .blue, .blue, .blue], isComplete: true)
            MiniTubeView(balls: [.green, .green, .green, .green], isComplete: true)

            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(Color("AccentYellow"))
                    }
                }
                Text("Win!")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color("AccentYellow"))
            }
        }
    }
}

// MARK: - Mini Tube View (for demos)

struct MiniTubeView: View {
    let balls: [PegColor]
    let isComplete: Bool
    var isHighlighted: Bool = false

    private let tubeWidth: CGFloat = 28
    private let tubeHeight: CGFloat = 80
    private let ballSize: CGFloat = 22

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tube
            MiniTubeShape()
                .fill(Color.black.opacity(0.5))
                .frame(width: tubeWidth, height: tubeHeight)
                .overlay(
                    MiniTubeShape()
                        .stroke(
                            isComplete ? Color("AccentGreen") :
                            (isHighlighted ? Color("AccentGreen") : Color.white.opacity(0.3)),
                            lineWidth: isHighlighted ? 2 : 1.5
                        )
                )

            // Balls
            VStack(spacing: 1) {
                ForEach(Array(balls.enumerated().reversed()), id: \.offset) { _, color in
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    color.color.opacity(0.9),
                                    color.color
                                ]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: ballSize
                            )
                        )
                        .frame(width: ballSize, height: ballSize)
                }
            }
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Mini Tube Shape

struct MiniTubeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 8

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: rect.height),
            control: CGPoint(x: 0, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height - cornerRadius),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width, y: 0))

        return path
    }
}

#Preview {
    HowToPlayView()
}

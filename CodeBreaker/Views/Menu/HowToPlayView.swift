import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    let pages: [TutorialPage] = [
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundTop")
                    .ignoresSafeArea()
                
                VStack {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            TutorialPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
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
                        
                        if currentPage < pages.count - 1 {
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

// MARK: - Tutorial Page Model

struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
    var colors: [PegColor]? = nil
    var feedbackDemo: FeedbackPeg? = nil
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

#Preview {
    HowToPlayView()
}

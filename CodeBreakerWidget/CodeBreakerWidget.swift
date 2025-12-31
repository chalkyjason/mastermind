import WidgetKit
import SwiftUI

// MARK: - Widget Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 7, totalStars: 150, dailyChallengeAvailable: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh at midnight for daily challenge
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func loadEntry() -> StreakEntry {
        let defaults = UserDefaults(suiteName: "group.com.codebreaker.shared")

        let streak = defaults?.integer(forKey: "currentStreak") ?? 0
        let totalStars = defaults?.integer(forKey: "totalStars") ?? 0

        // Check if daily challenge is available
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDailyDate = defaults?.object(forKey: "lastDailyChallengeDate") as? Date
        let dailyChallengeAvailable = lastDailyDate == nil || !calendar.isDate(lastDailyDate!, inSameDayAs: today)

        return StreakEntry(
            date: Date(),
            streak: streak,
            totalStars: totalStars,
            dailyChallengeAvailable: dailyChallengeAvailable
        )
    }
}

// MARK: - Widget Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let totalStars: Int
    let dailyChallengeAvailable: Bool
}

// MARK: - Widget View

struct CodeBreakerWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                // Streak
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("\(entry.streak)")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                }

                Text("Day Streak")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Divider()
                    .background(Color.white.opacity(0.2))

                // Stars
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(entry.totalStars)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }

                // Daily challenge indicator
                if entry.dailyChallengeAvailable {
                    Text("Daily Available!")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 20) {
                // Left side - Streak
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("\(entry.streak)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Day Streak")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .background(Color.white.opacity(0.3))

                // Right side - Stats
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(entry.totalStars) stars")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }

                    if entry.dailyChallengeAvailable {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.green)
                            Text("Daily Ready!")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Daily Complete")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Text("Chromind")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}

// MARK: - Lock Screen Widgets

struct CircularWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(entry.streak)")
                    .font(.title3.weight(.bold))
            }
        }
    }
}

struct RectangularWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(entry.streak) day streak")
                        .font(.headline)
                }

                if entry.dailyChallengeAvailable {
                    Text("Daily challenge available!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Widget Configuration

struct CodeBreakerWidget: Widget {
    let kind: String = "CodeBreakerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CodeBreakerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chromind")
        .description("Track your streak and daily challenge status.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Bundle

@main
struct CodeBreakerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodeBreakerWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CodeBreakerWidget()
} timeline: {
    StreakEntry(date: Date(), streak: 7, totalStars: 150, dailyChallengeAvailable: true)
    StreakEntry(date: Date(), streak: 14, totalStars: 300, dailyChallengeAvailable: false)
}

#Preview("Medium", as: .systemMedium) {
    CodeBreakerWidget()
} timeline: {
    StreakEntry(date: Date(), streak: 7, totalStars: 150, dailyChallengeAvailable: true)
}

#Preview("Lock Screen", as: .accessoryCircular) {
    CodeBreakerWidget()
} timeline: {
    StreakEntry(date: Date(), streak: 7, totalStars: 150, dailyChallengeAvailable: true)
}

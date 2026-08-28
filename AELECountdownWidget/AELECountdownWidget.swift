import WidgetKit
import SwiftUI

private enum AELETarget {
    static var examDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 9
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    static func daysRemaining(at date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let target = calendar.startOfDay(for: examDate)
        return max(0, calendar.dateComponents([.day], from: today, to: target).day ?? 0)
    }

    static func nextRefresh(after date: Date) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
        return calendar.date(byAdding: .minute, value: 2, to: tomorrow) ?? tomorrow
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
}

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(CountdownEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let now = Date()
        let entry = CountdownEntry(date: now)
        completion(Timeline(entries: [entry], policy: .after(AELETarget.nextRefresh(after: now))))
    }
}

struct AELECountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    private var days: Int { AELETarget.daysRemaining(at: entry.date) }
    private var examDay: Bool { Calendar.current.isDate(entry.date, inSameDayAs: AELETarget.examDate) }
    private var examPassed: Bool { entry.date > Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: AELETarget.examDate)) ?? AELETarget.examDate }

    var body: some View {
        Group {
            switch family {
            case .systemMedium, .systemLarge, .systemExtraLarge:
                mediumLayout
            default:
                smallLayout
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.035, blue: 0.04), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AELE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(3)
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if examPassed {
                Text("DONE")
                    .font(.system(size: 42, weight: .black, design: .rounded))
            } else if examDay {
                Text("EXAM")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                Text("DAY")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            } else {
                Text("\(days)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(days == 1 ? "DAY TO GO" : "DAYS TO GO")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("NOV 9, 2026")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text("8:00 AM")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(4)
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("AELE 2026")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.secondary)

                if examPassed {
                    Text("FINISHED")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                } else if examDay {
                    Text("EXAM DAY")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(days)")
                            .font(.system(size: 62, weight: .black, design: .rounded))
                            .monospacedDigit()
                        Text(days == 1 ? "DAY" : "DAYS")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text("UNTIL THE BOARD EXAM")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: "airplane")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                Text("NOV 9–11")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("2026")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("DAY 1 • 8:00 AM")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(5)
    }
}

@main
struct AELECountdownWidget: Widget {
    let kind = "AELECountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            AELECountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("AELE Countdown")
        .description("Countdown to the 2026 Aeronautical Engineer Licensure Exam.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

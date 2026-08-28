import SwiftUI
import WidgetKit

private enum AELEDate {
    static var examDay: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 9
        components.hour = 8
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    static func daysRemaining(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let target = calendar.startOfDay(for: examDay)
        return max(0, calendar.dateComponents([.day], from: today, to: target).day ?? 0)
    }
}

struct MainView: View {
    private var days: Int { AELEDate.daysRemaining() }
    private var isExamDay: Bool {
        Calendar.current.isDate(Date(), inSameDayAs: AELEDate.examDay)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.07, green: 0.07, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 5) {
                    Text("AELE 2026")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(.secondary)

                    if isExamDay {
                        Text("EXAM DAY")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                    } else {
                        Text("\(days)")
                            .font(.system(size: 92, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("DAYS TO GO")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .tracking(4)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 6) {
                    Text("AERONAUTICAL ENGINEER LICENSURE EXAM")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text("NOVEMBER 9–11, 2026 • DAY 1 AT 8:00 AM")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Add it to your Mac desktop", systemImage: "rectangle.grid.2x2")
                        .font(.system(size: 15, weight: .semibold))
                    Text("1. Keep AELE Countdown in Applications and open it once.\n2. Right-click your desktop and choose Edit Widgets.\n3. Search for “AELE Countdown.”\n4. Drag the widget onto your desktop.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                }
                .frame(maxWidth: 430, alignment: .leading)
                .padding(18)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

                Text("The widget updates automatically as the board exam gets closer.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(34)
        }
        .frame(minWidth: 560, minHeight: 560)
        .onAppear {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

@main
struct AELECountdownApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 620, height: 650)
    }
}

import SwiftUI
import AppKit
import Combine

enum ClockMode: String, CaseIterable, Identifiable {
    case clock = "Clock"
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var id: String { rawValue }
}

@MainActor
final class ClockModel: ObservableObject {
    @Published var now = Date()
    @Published var mode: ClockMode = .clock
    @Published var remainingSeconds: Int = 25 * 60
    @Published var isRunning = false

    @AppStorage("focusMinutes") var focusMinutes = 25
    @AppStorage("shortBreakMinutes") var shortBreakMinutes = 5
    @AppStorage("longBreakMinutes") var longBreakMinutes = 15
    @AppStorage("use24Hour") var use24Hour = false

    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.tick()
            }
    }

    private func tick() {
        now = Date()
        guard mode != .clock, isRunning else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }
        if remainingSeconds == 0 {
            isRunning = false
            NSSound.beep()
        }
    }

    func setMode(_ newMode: ClockMode) {
        mode = newMode
        isRunning = false
        reset()
    }

    func reset() {
        switch mode {
        case .clock:
            remainingSeconds = focusMinutes * 60
        case .focus:
            remainingSeconds = focusMinutes * 60
        case .shortBreak:
            remainingSeconds = shortBreakMinutes * 60
        case .longBreak:
            remainingSeconds = longBreakMinutes * 60
        }
    }

    func toggleRunning() {
        guard mode != .clock else { return }
        if remainingSeconds == 0 { reset() }
        isRunning.toggle()
    }

    func adjustCurrentMode(by delta: Int) {
        switch mode {
        case .focus:
            focusMinutes = min(120, max(1, focusMinutes + delta))
        case .shortBreak:
            shortBreakMinutes = min(60, max(1, shortBreakMinutes + delta))
        case .longBreak:
            longBreakMinutes = min(90, max(1, longBreakMinutes + delta))
        case .clock:
            return
        }
        reset()
    }

    var primaryDigits: String {
        switch mode {
        case .clock:
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: now)
            let displayedHour: Int
            if use24Hour {
                displayedHour = hour
            } else {
                let twelve = hour % 12
                displayedHour = twelve == 0 ? 12 : twelve
            }
            return String(format: "%02d", displayedHour)
        default:
            return String(format: "%02d", remainingSeconds / 60)
        }
    }

    var secondaryDigits: String {
        switch mode {
        case .clock:
            return String(format: "%02d", Calendar.current.component(.minute, from: now))
        default:
            return String(format: "%02d", remainingSeconds % 60)
        }
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: now).uppercased()
    }

    var sessionLabel: String {
        switch mode {
        case .clock:
            return use24Hour ? "24-HOUR CLOCK" : "12-HOUR CLOCK"
        case .focus:
            return isRunning ? "FOCUSING" : "FOCUS READY"
        case .shortBreak:
            return isRunning ? "SHORT BREAK" : "SHORT BREAK READY"
        case .longBreak:
            return isRunning ? "LONG BREAK" : "LONG BREAK READY"
        }
    }
}

struct FlipCard: View {
    let digit: Character

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: min(w, h) * 0.055, style: .continuous)
                    .fill(Color(white: 0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: min(w, h) * 0.055, style: .continuous)
                            .stroke(Color.white.opacity(0.035), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 28, y: 12)

                Text(String(digit))
                    .font(.system(size: min(w * 0.86, h * 0.78), weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.94))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .offset(y: -h * 0.015)

                Rectangle()
                    .fill(Color.black.opacity(0.72))
                    .frame(height: 1)

                HStack {
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 3, height: 18)
                    Spacer()
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 3, height: 18)
                }
                .padding(.horizontal, 5)
            }
            .clipped()
        }
        .aspectRatio(0.62, contentMode: .fit)
    }
}

struct DigitPair: View {
    let digits: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, char in
                FlipCard(digit: char)
            }
        }
    }
}

struct ModeButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(selected ? Color.white.opacity(0.92) : Color.white.opacity(0.07))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ContentView: View {
    @StateObject private var model = ClockModel()
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 22)

                Text(model.dateLabel)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .tracking(7)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 24)

                GeometryReader { proxy in
                    let horizontalPadding = max(32.0, proxy.size.width * 0.055)
                    HStack(spacing: max(18, proxy.size.width * 0.022)) {
                        DigitPair(digits: model.primaryDigits)

                        Text(model.mode == .clock ? "│" : ":")
                            .font(.system(size: min(proxy.size.width * 0.06, 72), weight: .ultraLight, design: .rounded))
                            .foregroundStyle(.white.opacity(0.28))
                            .frame(width: max(30, proxy.size.width * 0.045))

                        DigitPair(digits: model.secondaryDigits)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: 560)

                Text(model.sessionLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(.white.opacity(0.34))
                    .padding(.top, 18)

                Spacer(minLength: 28)

                controls
                    .opacity(controlsVisible ? 1 : 0.06)
                    .animation(.easeOut(duration: 0.25), value: controlsVisible)
                    .padding(.bottom, 22)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { revealControlsTemporarily() }
        }
        .onTapGesture(count: 2) {
            NSApp.keyWindow?.toggleFullScreen(nil)
        }
        .onAppear { revealControlsTemporarily() }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ModeButton(title: "Clock", selected: model.mode == .clock) { model.setMode(.clock); revealControlsTemporarily() }
                ModeButton(title: "Focus", selected: model.mode == .focus) { model.setMode(.focus); revealControlsTemporarily() }
                ModeButton(title: "Short", selected: model.mode == .shortBreak) { model.setMode(.shortBreak); revealControlsTemporarily() }
                ModeButton(title: "Long", selected: model.mode == .longBreak) { model.setMode(.longBreak); revealControlsTemporarily() }
            }

            HStack(spacing: 9) {
                if model.mode != .clock {
                    Button {
                        model.adjustCurrentMode(by: -1)
                        revealControlsTemporarily()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .help("Decrease this session by one minute")

                    Button {
                        model.toggleRunning()
                        revealControlsTemporarily()
                    } label: {
                        Label(model.isRunning ? "Pause" : "Start", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                            .frame(minWidth: 74)
                    }
                    .keyboardShortcut(.space, modifiers: [])

                    Button {
                        model.reset()
                        model.isRunning = false
                        revealControlsTemporarily()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset timer")

                    Button {
                        model.adjustCurrentMode(by: 1)
                        revealControlsTemporarily()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Increase this session by one minute")
                } else {
                    Button {
                        model.use24Hour.toggle()
                        revealControlsTemporarily()
                    } label: {
                        Text(model.use24Hour ? "24H" : "12H")
                            .frame(minWidth: 40)
                    }
                }

                Button {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                    revealControlsTemporarily()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Toggle fullscreen")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.white.opacity(0.12))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .fixedSize()
    }

    private func revealControlsTemporarily() {
        controlsVisible = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { controlsVisible = false }
        }
    }
}

@main
struct FlipClockPomodoroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 760)
        .commands {
            CommandMenu("Timer") {
                Button("Clock") { NotificationCenter.default.post(name: .selectClock, object: nil) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Focus") { NotificationCenter.default.post(name: .selectFocus, object: nil) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Short Break") { NotificationCenter.default.post(name: .selectShortBreak, object: nil) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Long Break") { NotificationCenter.default.post(name: .selectLongBreak, object: nil) }
                    .keyboardShortcut("4", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let selectClock = Notification.Name("selectClock")
    static let selectFocus = Notification.Name("selectFocus")
    static let selectShortBreak = Notification.Name("selectShortBreak")
    static let selectLongBreak = Notification.Name("selectLongBreak")
}

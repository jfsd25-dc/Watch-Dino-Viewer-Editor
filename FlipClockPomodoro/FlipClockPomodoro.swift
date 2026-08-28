import SwiftUI
import AppKit
import Combine

enum MainMode: String, CaseIterable, Identifiable {
    case clock = "Clock"
    case timer = "Timer"
    case pomodoro = "Pomodoro"

    var id: String { rawValue }
}

enum TimerDirection: String, CaseIterable, Identifiable {
    case countDown = "Count Down"
    case countUp = "Count Up"

    var id: String { rawValue }
}

enum PomodoroPhase: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var id: String { rawValue }
}

enum TimeComponent {
    case hour
    case minute
    case second
}

@MainActor
final class ClockModel: ObservableObject {
    static let maxTimerSeconds = (99 * 3600) + (59 * 60) + 59

    @Published var now = Date()
    @Published var mainMode: MainMode = .clock
    @Published var timerDirection: TimerDirection = .countDown
    @Published var pomodoroPhase: PomodoroPhase = .focus
    @Published var isRunning = false
    @Published var timerCurrentSeconds = 15 * 60
    @Published var pomodoroRemainingSeconds = 25 * 60

    @AppStorage("focusMinutes") var focusMinutes = 25
    @AppStorage("shortBreakMinutes") var shortBreakMinutes = 5
    @AppStorage("longBreakMinutes") var longBreakMinutes = 15
    @AppStorage("use24Hour") var use24Hour = false
    @AppStorage("countdownSeedSeconds") var countdownSeedSeconds = 15 * 60
    @AppStorage("countupSeedSeconds") var countupSeedSeconds = 0

    private var timer: AnyCancellable?

    init() {
        timerCurrentSeconds = countdownSeedSeconds
        pomodoroRemainingSeconds = focusMinutes * 60

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        now = Date()
        guard isRunning else { return }

        switch mainMode {
        case .clock:
            isRunning = false

        case .timer:
            switch timerDirection {
            case .countDown:
                if timerCurrentSeconds > 0 {
                    timerCurrentSeconds -= 1
                }
                if timerCurrentSeconds == 0 {
                    finishRun()
                }

            case .countUp:
                if timerCurrentSeconds < Self.maxTimerSeconds {
                    timerCurrentSeconds += 1
                }
                if timerCurrentSeconds >= Self.maxTimerSeconds {
                    finishRun()
                }
            }

        case .pomodoro:
            if pomodoroRemainingSeconds > 0 {
                pomodoroRemainingSeconds -= 1
            }
            if pomodoroRemainingSeconds == 0 {
                finishRun()
            }
        }
    }

    private func finishRun() {
        isRunning = false
        NSSound.beep()
    }

    func setMainMode(_ newMode: MainMode) {
        guard mainMode != newMode else { return }
        mainMode = newMode
        isRunning = false

        switch newMode {
        case .clock:
            break
        case .timer:
            resetTimer()
        case .pomodoro:
            resetPomodoro()
        }
    }

    func setTimerDirection(_ direction: TimerDirection) {
        guard timerDirection != direction else { return }
        timerDirection = direction
        isRunning = false
        resetTimer()
    }

    func setPomodoroPhase(_ phase: PomodoroPhase) {
        guard pomodoroPhase != phase else { return }
        pomodoroPhase = phase
        isRunning = false
        resetPomodoro()
    }

    func toggleRunning() {
        switch mainMode {
        case .clock:
            return

        case .timer:
            if timerDirection == .countDown && timerCurrentSeconds == 0 {
                resetTimer()
                guard timerCurrentSeconds > 0 else {
                    NSSound.beep()
                    return
                }
            }
            isRunning.toggle()

        case .pomodoro:
            if pomodoroRemainingSeconds == 0 {
                resetPomodoro()
            }
            isRunning.toggle()
        }
    }

    func resetCurrent() {
        isRunning = false
        switch mainMode {
        case .clock:
            break
        case .timer:
            resetTimer()
        case .pomodoro:
            resetPomodoro()
        }
    }

    func resetTimer() {
        timerCurrentSeconds = timerDirection == .countDown ? countdownSeedSeconds : countupSeedSeconds
    }

    func resetPomodoro() {
        switch pomodoroPhase {
        case .focus:
            pomodoroRemainingSeconds = focusMinutes * 60
        case .shortBreak:
            pomodoroRemainingSeconds = shortBreakMinutes * 60
        case .longBreak:
            pomodoroRemainingSeconds = longBreakMinutes * 60
        }
    }

    func adjustTimerComponent(_ component: TimeComponent, by delta: Int) {
        guard mainMode == .timer, !isRunning, delta != 0 else { return }

        var (hours, minutes, seconds) = components(for: timerCurrentSeconds)

        switch component {
        case .hour:
            hours = wrapped(hours + delta, upperBound: 99)
        case .minute:
            minutes = wrapped(minutes + delta, upperBound: 59)
        case .second:
            seconds = wrapped(seconds + delta, upperBound: 59)
        }

        let total = min(Self.maxTimerSeconds, (hours * 3600) + (minutes * 60) + seconds)
        timerCurrentSeconds = total

        if timerDirection == .countDown {
            countdownSeedSeconds = total
        } else {
            countupSeedSeconds = total
        }
    }

    func adjustPomodoroMinutes(by delta: Int) {
        guard mainMode == .pomodoro, !isRunning else { return }

        switch pomodoroPhase {
        case .focus:
            focusMinutes = min(180, max(1, focusMinutes + delta))
        case .shortBreak:
            shortBreakMinutes = min(60, max(1, shortBreakMinutes + delta))
        case .longBreak:
            longBreakMinutes = min(120, max(1, longBreakMinutes + delta))
        }
        resetPomodoro()
    }

    private func wrapped(_ value: Int, upperBound: Int) -> Int {
        let modulus = upperBound + 1
        let normalized = value % modulus
        return normalized >= 0 ? normalized : normalized + modulus
    }

    func components(for totalSeconds: Int) -> (Int, Int, Int) {
        let clamped = min(Self.maxTimerSeconds, max(0, totalSeconds))
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60
        return (hours, minutes, seconds)
    }

    var displayComponents: (Int, Int, Int) {
        switch mainMode {
        case .clock:
            let calendar = Calendar.current
            let rawHour = calendar.component(.hour, from: now)
            let hour: Int
            if use24Hour {
                hour = rawHour
            } else {
                let twelveHour = rawHour % 12
                hour = twelveHour == 0 ? 12 : twelveHour
            }
            return (
                hour,
                calendar.component(.minute, from: now),
                calendar.component(.second, from: now)
            )

        case .timer:
            return components(for: timerCurrentSeconds)

        case .pomodoro:
            return components(for: pomodoroRemainingSeconds)
        }
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = use24Hour ? "MMM d, yyyy 'at' HH:mm:ss" : "MMM d, yyyy 'at' h:mm:ss a"
        return formatter.string(from: now)
    }

    var statusLabel: String {
        switch mainMode {
        case .clock:
            return use24Hour ? "24-HOUR CLOCK" : "12-HOUR CLOCK"

        case .timer:
            if isRunning {
                return timerDirection == .countDown ? "COUNTING DOWN" : "COUNTING UP"
            }
            return "TWO-FINGER SCROLL THE HOUR • MIN • SEC WHEELS"

        case .pomodoro:
            switch pomodoroPhase {
            case .focus:
                return isRunning ? "FOCUSING" : "FOCUS READY"
            case .shortBreak:
                return isRunning ? "SHORT BREAK" : "SHORT BREAK READY"
            case .longBreak:
                return isRunning ? "LONG BREAK" : "LONG BREAK READY"
            }
        }
    }

    var timerValuesEditable: Bool {
        mainMode == .timer && !isRunning
    }
}

final class ScrollCaptureNSView: NSView {
    var enabled = false {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    var onStep: ((Int) -> Void)?
    private var accumulatedDelta: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        enabled ? self : nil
    }

    override func scrollWheel(with event: NSEvent) {
        guard enabled else {
            super.scrollWheel(with: event)
            return
        }

        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        if event.hasPreciseScrollingDeltas {
            accumulatedDelta += delta
            let threshold: CGFloat = 13

            while accumulatedDelta >= threshold {
                onStep?(1)
                accumulatedDelta -= threshold
            }

            while accumulatedDelta <= -threshold {
                onStep?(-1)
                accumulatedDelta += threshold
            }
        } else {
            onStep?(delta > 0 ? 1 : -1)
        }
    }

    override func resetCursorRects() {
        guard enabled else { return }
        addCursorRect(bounds, cursor: .resizeUpDown)
    }
}

struct ScrollWheelCapture: NSViewRepresentable {
    let enabled: Bool
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> ScrollCaptureNSView {
        let view = ScrollCaptureNSView()
        view.enabled = enabled
        view.onStep = onStep
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {
        nsView.enabled = enabled
        nsView.onStep = onStep
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
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 10)

                Text(String(digit))
                    .font(.system(size: min(w * 0.86, h * 0.78), weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.94))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .offset(y: -h * 0.015)

                Rectangle()
                    .fill(Color.black.opacity(0.78))
                    .frame(height: 1)

                HStack {
                    Capsule()
                        .fill(Color.black.opacity(0.9))
                        .frame(width: 3, height: 18)
                    Spacer()
                    Capsule()
                        .fill(Color.black.opacity(0.9))
                        .frame(width: 3, height: 18)
                }
                .padding(.horizontal, 5)
            }
            .clipped()
        }
        .aspectRatio(0.62, contentMode: .fit)
    }
}

struct DigitPair: View {
    let value: Int

    var digits: String { String(format: "%02d", value) }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, char in
                FlipCard(digit: char)
            }
        }
    }
}

struct VisibleWheelPicker: View {
    let value: Int
    let maxValue: Int
    let enabled: Bool
    let onStep: (Int) -> Void

    private func wrapped(_ raw: Int) -> Int {
        let modulus = maxValue + 1
        let normalized = raw % modulus
        return normalized >= 0 ? normalized : normalized + modulus
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 5) {
                Button {
                    onStep(1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(enabled ? 0.62 : 0.18))
                .disabled(!enabled)

                Button {
                    onStep(-1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(enabled ? 0.62 : 0.18))
                .disabled(!enabled)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(enabled ? 0.055 : 0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(enabled ? 0.10 : 0.04), lineWidth: 1)
                    )

                VStack(spacing: 1) {
                    wheelRow(wrapped(value + 2), opacity: 0.18, size: 10)
                    wheelRow(wrapped(value + 1), opacity: 0.36, size: 12)

                    Text(String(format: "%02d", value))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(enabled ? 0.94 : 0.40))
                        .frame(width: 52, height: 28)
                        .background(Color.white.opacity(enabled ? 0.085 : 0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    wheelRow(wrapped(value - 1), opacity: 0.36, size: 12)
                    wheelRow(wrapped(value - 2), opacity: 0.18, size: 10)
                }
                .padding(.vertical, 7)

                if enabled {
                    ScrollWheelCapture(enabled: true, onStep: onStep)
                        .opacity(0.001)
                        .padding(.trailing, 13)
                }
            }
            .frame(width: 80, height: 116)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(enabled ? 0.13 : 0.04))
                    .frame(width: 4, height: 96)
                    .overlay(alignment: .center) {
                        Capsule()
                            .fill(Color.white.opacity(enabled ? 0.46 : 0.08))
                            .frame(width: 4, height: 27)
                    }

                Image(systemName: "hand.draw")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(enabled ? 0.34 : 0.08))
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .help(enabled ? "Two-finger scroll on the trackpad to change this value" : "Pause the timer to edit")
    }

    private func wheelRow(_ number: Int, opacity: Double, size: CGFloat) -> some View {
        Text(String(format: "%02d", number))
            .font(.system(size: size, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(enabled ? opacity : opacity * 0.35))
            .frame(height: 15)
    }
}

struct TimeUnitDisplay: View {
    let value: Int
    let maxValue: Int
    let label: String
    let editable: Bool
    let showWheel: Bool
    let onStep: (Int) -> Void

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                DigitPair(value: value)

                if editable {
                    ScrollWheelCapture(enabled: true, onStep: onStep)
                        .opacity(0.001)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.46))

            if showWheel {
                VisibleWheelPicker(
                    value: value,
                    maxValue: maxValue,
                    enabled: editable,
                    onStep: onStep
                )
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
                .foregroundStyle(selected ? .black : .white.opacity(0.72))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.white.opacity(0.94) : Color.white.opacity(0.07))
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
                Spacer(minLength: 16)

                Text(model.dateLabel)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.bottom, 14)

                if model.mainMode == .timer {
                    Text(model.timerDirection.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(3.8)
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.bottom, 8)
                } else if model.mainMode == .pomodoro {
                    Text(model.pomodoroPhase.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(3.8)
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.bottom, 8)
                }

                GeometryReader { proxy in
                    let components = model.displayComponents
                    let showWheel = model.mainMode == .timer && !model.isRunning

                    HStack(spacing: max(10, proxy.size.width * 0.012)) {
                        TimeUnitDisplay(
                            value: components.0,
                            maxValue: 99,
                            label: "HOUR",
                            editable: model.timerValuesEditable,
                            showWheel: showWheel,
                            onStep: {
                                model.adjustTimerComponent(.hour, by: $0)
                                revealControlsTemporarily()
                            }
                        )

                        colon(proxy, wheelVisible: showWheel)

                        TimeUnitDisplay(
                            value: components.1,
                            maxValue: 59,
                            label: "MIN",
                            editable: model.timerValuesEditable,
                            showWheel: showWheel,
                            onStep: {
                                model.adjustTimerComponent(.minute, by: $0)
                                revealControlsTemporarily()
                            }
                        )

                        colon(proxy, wheelVisible: showWheel)

                        TimeUnitDisplay(
                            value: components.2,
                            maxValue: 59,
                            label: "SEC",
                            editable: model.timerValuesEditable,
                            showWheel: showWheel,
                            onStep: {
                                model.adjustTimerComponent(.second, by: $0)
                                revealControlsTemporarily()
                            }
                        )
                    }
                    .padding(.horizontal, max(24, proxy.size.width * 0.035))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: model.mainMode == .timer && !model.isRunning ? 560 : 450)

                Text(model.statusLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.6)
                    .foregroundStyle(.white.opacity(0.36))
                    .padding(.top, 10)

                Spacer(minLength: 18)

                controls
                    .opacity(controlsVisible ? 1 : 0.07)
                    .animation(.easeOut(duration: 0.24), value: controlsVisible)
                    .padding(.bottom, 18)
            }
        }
        .frame(minWidth: 820, minHeight: 650)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { revealControlsTemporarily() }
        }
        .onTapGesture(count: 2) {
            NSApp.keyWindow?.toggleFullScreen(nil)
        }
        .onAppear {
            revealControlsTemporarily()
        }
    }

    private func colon(_ proxy: GeometryProxy, wheelVisible: Bool) -> some View {
        Text(":")
            .font(.system(size: min(proxy.size.width * 0.045, 58), weight: .ultraLight, design: .rounded))
            .foregroundStyle(.white.opacity(0.28))
            .frame(width: max(18, proxy.size.width * 0.025))
            .offset(y: wheelVisible ? -72 : -15)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                ModeButton(title: "Clock", selected: model.mainMode == .clock) {
                    model.setMainMode(.clock)
                    revealControlsTemporarily()
                }
                ModeButton(title: "Timer", selected: model.mainMode == .timer) {
                    model.setMainMode(.timer)
                    revealControlsTemporarily()
                }
                ModeButton(title: "Pomodoro", selected: model.mainMode == .pomodoro) {
                    model.setMainMode(.pomodoro)
                    revealControlsTemporarily()
                }
            }

            if model.mainMode == .timer {
                HStack(spacing: 7) {
                    ModeButton(title: "Count Down", selected: model.timerDirection == .countDown) {
                        model.setTimerDirection(.countDown)
                        revealControlsTemporarily()
                    }
                    ModeButton(title: "Count Up", selected: model.timerDirection == .countUp) {
                        model.setTimerDirection(.countUp)
                        revealControlsTemporarily()
                    }
                }
            } else if model.mainMode == .pomodoro {
                HStack(spacing: 7) {
                    ModeButton(title: "Focus", selected: model.pomodoroPhase == .focus) {
                        model.setPomodoroPhase(.focus)
                        revealControlsTemporarily()
                    }
                    ModeButton(title: "Short", selected: model.pomodoroPhase == .shortBreak) {
                        model.setPomodoroPhase(.shortBreak)
                        revealControlsTemporarily()
                    }
                    ModeButton(title: "Long", selected: model.pomodoroPhase == .longBreak) {
                        model.setPomodoroPhase(.longBreak)
                        revealControlsTemporarily()
                    }
                }
            }

            HStack(spacing: 9) {
                switch model.mainMode {
                case .clock:
                    Button {
                        model.use24Hour.toggle()
                        revealControlsTemporarily()
                    } label: {
                        Text(model.use24Hour ? "24H" : "12H")
                            .frame(minWidth: 42)
                    }

                case .timer:
                    Button {
                        model.toggleRunning()
                        revealControlsTemporarily()
                    } label: {
                        Label(model.isRunning ? "Pause" : "Start", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                            .frame(minWidth: 78)
                    }
                    .keyboardShortcut(.space, modifiers: [])

                    Button {
                        model.resetCurrent()
                        revealControlsTemporarily()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                case .pomodoro:
                    Button {
                        model.adjustPomodoroMinutes(by: -1)
                        revealControlsTemporarily()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(model.isRunning)

                    Button {
                        model.toggleRunning()
                        revealControlsTemporarily()
                    } label: {
                        Label(model.isRunning ? "Pause" : "Start", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                            .frame(minWidth: 78)
                    }
                    .keyboardShortcut(.space, modifiers: [])

                    Button {
                        model.resetCurrent()
                        revealControlsTemporarily()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        model.adjustPomodoroMinutes(by: 1)
                        revealControlsTemporarily()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(model.isRunning)
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
            .tint(.white.opacity(0.13))
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
            await MainActor.run {
                controlsVisible = false
            }
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
        .defaultSize(width: 1200, height: 820)
    }
}

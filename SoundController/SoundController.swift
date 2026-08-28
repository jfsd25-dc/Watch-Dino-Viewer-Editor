import SwiftUI
import AppKit
import Combine

@MainActor
final class SoundModel: ObservableObject {
    @Published var outputVolume: Double = 50
    @Published var inputVolume: Double = 50
    @Published var alertVolume: Double = 50
    @Published var isMuted = false
    @Published var keepOnTop = false
    @Published var statusText = "READY"

    private var poller: AnyCancellable?

    init() {
        refresh()
        poller = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh(silent: true)
            }
    }

    func refresh(silent: Bool = false) {
        let out = readNumber("output volume of (get volume settings)")
        let input = readNumber("input volume of (get volume settings)")
        let alert = readNumber("alert volume of (get volume settings)")
        let muted = readBool("output muted of (get volume settings)")

        if let out { outputVolume = Double(out) }
        if let input { inputVolume = Double(input) }
        if let alert { alertVolume = Double(alert) }
        if let muted { isMuted = muted }

        if !silent { statusText = "SYNCED WITH MAC" }
    }

    func applyOutput() {
        let v = clamp(outputVolume)
        outputVolume = Double(v)
        runAppleScript("set volume output volume \(v)")
        if v > 0 && isMuted {
            runAppleScript("set volume without output muted")
            isMuted = false
        }
        statusText = "OUTPUT \(v)%"
    }

    func setOutput(_ value: Int) {
        outputVolume = Double(clamp(Double(value)))
        applyOutput()
    }

    func bumpOutput(_ delta: Int) {
        setOutput(Int(outputVolume.rounded()) + delta)
    }

    func applyInput() {
        let v = clamp(inputVolume)
        inputVolume = Double(v)
        runAppleScript("set volume input volume \(v)")
        statusText = "MIC INPUT \(v)%"
    }

    func applyAlert() {
        let v = clamp(alertVolume)
        alertVolume = Double(v)
        runAppleScript("set volume alert volume \(v)")
        statusText = "ALERT \(v)%"
    }

    func toggleMute() {
        isMuted.toggle()
        runAppleScript(isMuted ? "set volume with output muted" : "set volume without output muted")
        statusText = isMuted ? "MUTED" : "UNMUTED"
    }

    func testSound() {
        NSSound.beep()
        statusText = "TEST SOUND"
    }

    func setWindowFloating(_ floating: Bool) {
        keepOnTop = floating
        NSApp.keyWindow?.level = floating ? .floating : .normal
        statusText = floating ? "KEEP ON TOP" : "NORMAL WINDOW"
    }

    private func clamp(_ value: Double) -> Int {
        min(100, max(0, Int(value.rounded())))
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func readNumber(_ expression: String) -> Int? {
        guard let text = runAppleScript(expression) else { return nil }
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func readBool(_ expression: String) -> Bool? {
        guard let text = runAppleScript(expression)?.lowercased() else { return nil }
        if text == "true" { return true }
        if text == "false" { return false }
        return nil
    }
}

struct LevelCard: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Slider(value: $value, in: 0...100, step: 1, onEditingChanged: { editing in
                if !editing { onCommit() }
            })
        }
        .padding(18)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
    }
}

struct PresetButton: View {
    let value: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)%")
                .font(.system(size: 12, weight: .semibold))
                .frame(minWidth: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

struct ContentView: View {
    @StateObject private var model = SoundModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SOUND CONTROLLER")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("MAC AUDIO CONTROL")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(2.5)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    Spacer()
                    Button {
                        model.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh current Mac sound levels")
                }

                LevelCard(
                    title: "Speaker Output",
                    symbol: model.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill",
                    value: $model.outputVolume,
                    onCommit: model.applyOutput
                )

                HStack(spacing: 10) {
                    Button {
                        model.bumpOutput(-5)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .help("Volume down 5%")

                    ForEach([25, 50, 75, 100], id: \.self) { value in
                        PresetButton(value: value) { model.setOutput(value) }
                    }

                    Button {
                        model.bumpOutput(5)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Volume up 5%")
                }
                .buttonStyle(.bordered)

                HStack(spacing: 12) {
                    Button {
                        model.toggleMute()
                    } label: {
                        Label(model.isMuted ? "Unmute" : "Mute", systemImage: model.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.testSound()
                    } label: {
                        Label("Test", systemImage: "waveform")
                    }
                    .buttonStyle(.bordered)

                    Toggle(isOn: Binding(
                        get: { model.keepOnTop },
                        set: { model.setWindowFloating($0) }
                    )) {
                        Text("Keep on top")
                    }
                    .toggleStyle(.switch)
                    .font(.system(size: 12, weight: .medium))
                }

                HStack(spacing: 12) {
                    LevelCard(
                        title: "Microphone Input",
                        symbol: "mic.fill",
                        value: $model.inputVolume,
                        onCommit: model.applyInput
                    )

                    LevelCard(
                        title: "Alert Volume",
                        symbol: "bell.fill",
                        value: $model.alertVolume,
                        onCommit: model.applyAlert
                    )
                }

                Text(model.statusText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.38))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(22)
        }
        .frame(minWidth: 620, minHeight: 520)
        .preferredColorScheme(.dark)
    }
}

@main
struct SoundControllerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 680, height: 590)
    }
}

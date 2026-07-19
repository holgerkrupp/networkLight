//
//  networkLightApp.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import AppKit
import CoreData
import SwiftUI
import UserNotifications

struct Speed: Identifiable {
    let id = UUID()
    let speed: Double
    let unit: String
    let date: Date
    let icon: String
    let responsiveness: Int?
}

struct SpeedLimit: Identifiable, Codable, Equatable {
    var upperlimit: Double
    var lowerlimit: Double
    var icon: String
    var id: UUID

    init(upperlimit: Double, lowerlimit: Double, icon: String, id: UUID = UUID()) {
        self.upperlimit = upperlimit
        self.lowerlimit = lowerlimit
        self.icon = icon
        self.id = id
    }

    enum CodingKeys: CodingKey {
        case upperlimit, lowerlimit, icon, id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        upperlimit = try container.decode(Double.self, forKey: .upperlimit)
        lowerlimit = try container.decode(Double.self, forKey: .lowerlimit)
        icon = try container.decode(String.self, forKey: .icon)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    }
}

@MainActor
final class NetworkMonitor: ObservableObject {
    static let defaultLimits = [
        SpeedLimit(upperlimit: 100, lowerlimit: 70, icon: "🟢"),
        SpeedLimit(upperlimit: 70, lowerlimit: 20, icon: "🟡"),
        SpeedLimit(upperlimit: 20, lowerlimit: 0, icon: "🔴")
    ]

    @Published private(set) var speeds: [String: Speed] = [:]
    @Published private(set) var isRunning = false
    @Published private(set) var isAutoRunEnabled = false
    @Published private(set) var nextRunDate: Date?
    @Published private(set) var lastError: String?

    @Published var maxDownload: Double {
        didSet {
            if !maxDownload.isFinite || maxDownload <= 0 { maxDownload = oldValue }
            defaults.set(maxDownload, forKey: Keys.maxDownload)
        }
    }

    @Published var maxUpload: Double {
        didSet {
            if !maxUpload.isFinite || maxUpload <= 0 { maxUpload = oldValue }
            defaults.set(maxUpload, forKey: Keys.maxUpload)
        }
    }

    @Published var repeatInterval: Int {
        didSet {
            let validValue = min(max(repeatInterval, 60), 86_400)
            if repeatInterval != validValue {
                repeatInterval = validValue
                return
            }
            defaults.set(repeatInterval, forKey: Keys.repeatInterval)
            if isAutoRunEnabled { scheduleNextRun() }
        }
    }

    @Published var speedLimits: [SpeedLimit] {
        didSet { saveSpeedLimits() }
    }

    var download: Speed? { speeds["Download"] }
    var upload: Speed? { speeds["Upload"] }
    var lastRunDate: Date? { download?.date ?? upload?.date }

    var hasInvalidSpeedLimits: Bool {
        let ordered = speedLimits.sorted { $0.lowerlimit < $1.lowerlimit }
        guard !ordered.isEmpty else { return true }
        guard ordered.allSatisfy({
            $0.lowerlimit.isFinite && $0.upperlimit.isFinite &&
            $0.lowerlimit >= 0 && $0.upperlimit > $0.lowerlimit &&
            !$0.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else { return true }

        return zip(ordered, ordered.dropFirst()).contains {
            abs($0.upperlimit - $1.lowerlimit) > 0.001
        }
    }

    private enum Keys {
        static let maxDownload = "maxDownload"
        static let maxUpload = "maxUpload"
        // Keep the original key so existing installations retain their interval.
        static let repeatInterval = "repleattime"
        static let speedLimits = "SpeedLimits"
    }

    private let defaults: UserDefaults
    private let viewContext: NSManagedObjectContext
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(
        viewContext: NSManagedObjectContext,
        defaults: UserDefaults = .standard
    ) {
        self.viewContext = viewContext
        self.defaults = defaults

        let storedDownload = defaults.object(forKey: Keys.maxDownload) as? Double
        maxDownload = storedDownload.flatMap { $0 > 0 ? $0 : nil } ?? 100

        let storedUpload = defaults.object(forKey: Keys.maxUpload) as? Double
        maxUpload = storedUpload.flatMap { $0 > 0 ? $0 : nil } ?? 20

        let storedInterval = defaults.object(forKey: Keys.repeatInterval) as? Int ?? 600
        repeatInterval = min(max(storedInterval, 60), 86_400)

        if let data = defaults.data(forKey: Keys.speedLimits),
           let decoded = try? JSONDecoder().decode([SpeedLimit].self, from: data),
           !decoded.isEmpty {
            speedLimits = decoded
        } else {
            speedLimits = Self.defaultLimits
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAutoRunEnabled else { return }
                self.timer?.invalidate()
                self.timer = nil
                self.nextRunDate = nil
                await self.runTest()
                self.scheduleNextRun()
            }
        }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func runTest() async {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil
        defer { isRunning = false }

        do {
            let output = try await NetworkQualityRunner.run()
            let result = try JSONDecoder().decode(
                NetworkQualityResult.self,
                from: Data(output.utf8)
            )

            let downloadSpeed = result.dlThroughput / 1_000_000
            let uploadSpeed = result.ulThroughput / 1_000_000
            guard downloadSpeed.isFinite, uploadSpeed.isFinite,
                  downloadSpeed >= 0, uploadSpeed >= 0 else {
                throw NetworkQualityError.invalidResponse
            }

            let now = Date()
            let uploadStatus = status(for: uploadSpeed, expected: maxUpload)
            let downloadStatus = status(for: downloadSpeed, expected: maxDownload)

            let upload = Speed(
                speed: uploadSpeed,
                unit: "Mbps",
                date: now,
                icon: uploadStatus.icon,
                responsiveness: nil
            )
            let download = Speed(
                speed: downloadSpeed,
                unit: "Mbps",
                date: now,
                icon: downloadStatus.icon,
                responsiveness: Int(result.responsiveness.rounded())
            )

            speeds = ["Upload": upload, "Download": download]
            try save(download: download, upload: upload, rawJSON: output)

            let lowestLimitID = speedLimits.min(by: { $0.lowerlimit < $1.lowerlimit })?.id
            if uploadStatus.id == lowestLimitID || downloadStatus.id == lowestLimitID {
                await sendLowSpeedNotification(download: download, upload: upload)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setAutoRunEnabled(_ enabled: Bool) {
        guard enabled != isAutoRunEnabled else { return }
        isAutoRunEnabled = enabled

        if enabled {
            scheduleNextRun()
            Task { await runTest() }
        } else {
            timer?.invalidate()
            timer = nil
            nextRunDate = nil
        }
    }

    func resetSpeedLimits() {
        speedLimits = Self.defaultLimits
    }

    private func scheduleNextRun() {
        timer?.invalidate()
        guard isAutoRunEnabled else {
            nextRunDate = nil
            return
        }

        let interval = TimeInterval(repeatInterval)
        nextRunDate = Date().addingTimeInterval(interval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAutoRunEnabled else { return }
                await self.runTest()
                self.scheduleNextRun()
            }
        }
    }

    private func status(for speed: Double, expected: Double) -> SpeedLimit {
        let percentage = speed / max(expected, 0.01) * 100
        let ordered = speedLimits.sorted { $0.lowerlimit > $1.lowerlimit }
        guard let first = ordered.first else {
            return Self.defaultLimits[1]
        }

        if percentage >= first.lowerlimit { return first }
        return ordered.first(where: {
            percentage >= $0.lowerlimit && percentage < $0.upperlimit
        }) ?? ordered.last ?? first
    }

    private func save(download: Speed, upload: Speed, rawJSON: String) throws {
        let log = SpeedLog(context: viewContext)
        log.download = download.speed
        log.upload = upload.speed
        log.date = download.date
        log.responsiveness = Int16(clamping: download.responsiveness ?? 0)
        log.json = rawJSON
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            throw error
        }
    }

    private func saveSpeedLimits() {
        guard let data = try? JSONEncoder().encode(speedLimits) else { return }
        defaults.set(data, forKey: Keys.speedLimits)
    }

    private func sendLowSpeedNotification(download: Speed, upload: Speed) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Network speed is below your target"
        content.subtitle = download.date.formatted(date: .abbreviated, time: .shortened)
        content.body = String(
            format: "Upload: %@ %.1f Mbps\nDownload: %@ %.1f Mbps",
            upload.icon,
            upload.speed,
            download.icon,
            download.speed
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "networkLight.lowSpeed.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

private struct NetworkQualityResult: Decodable {
    let downloadThroughput: Double
    let uploadThroughput: Double
    let responsiveness: Double

    enum CodingKeys: String, CodingKey {
        case downloadThroughput = "dl_throughput"
        case uploadThroughput = "ul_throughput"
        case responsiveness
    }

    var dlThroughput: Double { downloadThroughput }
    var ulThroughput: Double { uploadThroughput }
}

private enum NetworkQualityError: LocalizedError {
    case failed(status: Int32, message: String)
    case invalidOutput
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .failed(status, message):
            return message.isEmpty
                ? "The network quality test failed (exit code \(status))."
                : message
        case .invalidOutput:
            return "The network quality test returned unreadable output."
        case .invalidResponse:
            return "The network quality test returned invalid measurements."
        }
    }
}

private enum NetworkQualityRunner {
    static func run() async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/networkquality")
            process.arguments = ["-c", "-M", "60"]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            let outputReader = Task.detached {
                outputPipe.fileHandleForReading.readDataToEndOfFile()
            }
            let errorReader = Task.detached {
                errorPipe.fileHandleForReading.readDataToEndOfFile()
            }
            process.waitUntilExit()

            let outputData = await outputReader.value
            let errorData = await errorReader.value
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                throw NetworkQualityError.failed(
                    status: process.terminationStatus,
                    message: errorMessage
                )
            }
            guard let output = String(data: outputData, encoding: .utf8),
                  !output.isEmpty else {
                throw NetworkQualityError.invalidOutput
            }
            return output
        }.value
    }
}

@main
struct NetworkLightApp: App {
    private let persistenceController = PersistenceController.shared
    @StateObject private var monitor = NetworkMonitor(
        viewContext: PersistenceController.shared.container.viewContext
    )

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(monitor: monitor)
                .environment(
                    \.managedObjectContext,
                    persistenceController.container.viewContext
                )
        } label: {
            Text(monitor.isRunning ? "◌" : monitor.download?.icon ?? "○")
                .accessibilityLabel("NetworkLight")
        }
        .menuBarExtraStyle(.window)

        historyWindow
        settingsWindow
    }

    private var historyWindow: some Scene {
        WindowGroup("History", id: "history") {
            HistoryView(compact: false)
                .environment(
                    \.managedObjectContext,
                    persistenceController.container.viewContext
                )
        }
        .defaultSize(width: 760, height: 560)
        .handlesExternalEvents(matching: ["history"])
    }

    private var settingsWindow: some Scene {
        WindowGroup("NetworkLight Settings", id: "settings") {
            SettingsView(monitor: monitor)
        }
        .defaultSize(width: 540, height: 620)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["settings"])
    }
}

private struct MenuBarPanel: View {
    @ObservedObject var monitor: NetworkMonitor
    @Environment(\.openWindow) private var openWindow

    private var autoRunBinding: Binding<Bool> {
        Binding(
            get: { monitor.isAutoRunEnabled },
            set: { monitor.setAutoRunEnabled($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("NetworkLight")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if monitor.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                MetricCard(
                    title: "Download",
                    symbol: "arrow.down",
                    measurement: monitor.download
                )
                MetricCard(
                    title: "Upload",
                    symbol: "arrow.up",
                    measurement: monitor.upload
                )
            }

            if let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await monitor.runTest() }
            } label: {
                Label(
                    monitor.isRunning ? "Testing connection…" : "Run Speed Test",
                    systemImage: monitor.isRunning ? "hourglass" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(monitor.isRunning)
            .keyboardShortcut("n")

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Test automatically", isOn: autoRunBinding)
                    .toggleStyle(.switch)
                if let nextRunDate = monitor.nextRunDate {
                    Text("Next test \(nextRunDate, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Interval: \(formattedInterval(monitor.repeatInterval))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HistoryView(compact: true)

            Divider()

            HStack {
                Button("History", systemImage: "chart.xyaxis.line") {
                    showWindow(id: "history", title: "History")
                }
                Button("Settings", systemImage: "gearshape") {
                    showWindow(id: "settings", title: "NetworkLight Settings")
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 360)
    }

    private var statusText: String {
        if monitor.isRunning { return "Measuring your connection" }
        if let date = monitor.lastRunDate {
            return "Updated \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "Ready for the first test"
    }

    private func showWindow(id: String, title: String) {
        openWindow(id: id)
        activateApplication()

        // SwiftUI creates or restores the window after the openWindow action.
        // Move it forward on the next run-loop pass once it exists.
        DispatchQueue.main.async {
            activateApplication()
            guard let window = NSApplication.shared.windows.first(where: {
                $0.title == title
            }) else { return }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            activateApplication()
        }
    }

    private func activateApplication() {
        if #available(macOS 14.0, *) {
            NSApplication.shared.activate()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let symbol: String
    let measurement: Speed?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(measurement?.icon ?? "—")
                Text(measurement.map { $0.speed.formatted(.number.precision(.fractionLength(1))) } ?? "—")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(measurement?.unit ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .modifier(StatusCardStyle())
    }
}

private struct StatusCardStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        } else {
            content.background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

func formattedInterval(_ seconds: Int) -> String {
    if seconds % 3_600 == 0 {
        let hours = seconds / 3_600
        return "\(hours) hour\(hours == 1 ? "" : "s")"
    }
    let minutes = max(seconds / 60, 1)
    return "\(minutes) minute\(minutes == 1 ? "" : "s")"
}

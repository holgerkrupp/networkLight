//
//  SettingsView.swift
//  networkLight
//
//  Created by Holger Krupp on 10.10.22.
//

import AppKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var monitor: NetworkMonitor
    @State private var notificationSettings: UNNotificationSettings?
    @State private var notificationError: String?

    var body: some View {
        Form {
            Section {
                speedField(
                    title: "Download",
                    symbol: "arrow.down.circle.fill",
                    value: $monitor.maxDownload
                )
                speedField(
                    title: "Upload",
                    symbol: "arrow.up.circle.fill",
                    value: $monitor.maxUpload
                )
            } header: {
                Text("Expected Speeds")
            } footer: {
                Text("NetworkLight compares each result with these speeds to choose its status color.")
            }

            Section {
                Stepper(
                    value: $monitor.repeatInterval,
                    in: 60...86_400,
                    step: 60
                ) {
                    LabeledContent("Test interval") {
                        Text(formattedInterval(monitor.repeatInterval))
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Automatic Testing")
            } footer: {
                Text("Automatic testing remains off after relaunch so NetworkLight never consumes bandwidth unexpectedly.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("From")
                            .frame(width: 76, alignment: .leading)
                        Text("To")
                            .frame(width: 76, alignment: .leading)
                        Text("Indicator")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach($monitor.speedLimits) { $limit in
                        HStack {
                            percentageField(value: $limit.lowerlimit)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            percentageField(value: $limit.upperlimit)
                            TextField("Indicator", text: $limit.icon)
                                .labelsHidden()
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 62)
                                .accessibilityLabel("Status indicator")
                        }
                    }

                    if monitor.hasInvalidSpeedLimits {
                        Label(
                            "Ranges must be contiguous, non-overlapping, and greater than zero.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }

                    HStack {
                        Spacer()
                        Button("Restore Defaults") {
                            monitor.resetSpeedLimits()
                        }
                    }
                }
            } header: {
                Text("Status Ranges")
            } footer: {
                Text("Values are percentages of the expected upload or download speed. Boundary values use the better range.")
            }

            Section("Notifications") {
                LabeledContent("Permission") {
                    Label(notificationStatusText, systemImage: notificationStatusSymbol)
                        .foregroundStyle(notificationStatusColor)
                }

                if notificationSettings?.authorizationStatus == .denied {
                    Button("Open Notification Settings") {
                        openNotificationSettings()
                    }
                } else if notificationSettings?.authorizationStatus != .authorized {
                    Button("Allow Low-Speed Notifications") {
                        Task { await requestNotificationPermission() }
                    }
                } else {
                    Button("Manage Notifications") {
                        openNotificationSettings()
                    }
                }

                if let notificationError {
                    Text(notificationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("About") {
                LabeledContent("Version", value: versionText)
                Link(
                    "NetworkLight on GitHub",
                    destination: URL(string: "https://github.com/holgerkrupp/networkLight")!
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .task { await refreshNotificationSettings() }
    }

    private func speedField(
        title: String,
        symbol: String,
        value: Binding<Double>
    ) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField(
                    title,
                    value: value,
                    format: .number.precision(.fractionLength(0...1))
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                Text("Mbps")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    private func percentageField(value: Binding<Double>) -> some View {
        HStack(spacing: 3) {
            TextField(
                "Percent",
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: 62)
            Text("%")
                .foregroundStyle(.secondary)
        }
    }

    private var notificationStatusText: String {
        switch notificationSettings?.authorizationStatus {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .provisional: "Provisional"
        case .notDetermined: "Not requested"
        case .ephemeral: "Temporary"
        case nil: "Checking…"
        @unknown default: "Unknown"
        }
    }

    private var notificationStatusSymbol: String {
        switch notificationSettings?.authorizationStatus {
        case .authorized, .provisional: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        default: "questionmark.circle"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationSettings?.authorizationStatus {
        case .authorized, .provisional: .green
        case .denied: .red
        default: .secondary
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func refreshNotificationSettings() async {
        notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
    }

    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
            notificationError = nil
            await refreshNotificationSettings()
        } catch {
            notificationError = error.localizedDescription
        }
    }

    private func openNotificationSettings() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let url = URL(
                string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)"
              ) else { return }
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    SettingsView(
        monitor: NetworkMonitor(
            viewContext: PersistenceController.preview.container.viewContext,
            defaults: UserDefaults(suiteName: "SettingsPreview")!
        )
    )
}

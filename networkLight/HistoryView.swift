//
//  HistoryView.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import Charts
import CoreData
import SwiftUI
import UniformTypeIdentifiers

private enum HistoryPresentation: String, CaseIterable, Identifiable {
    case table
    case chart

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

private enum HistoryMetric: String, CaseIterable, Identifiable {
    case download
    case upload

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String { self == .download ? "arrow.down" : "arrow.up" }
}

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SpeedLog.date, ascending: false)],
        animation: .default
    ) private var speedLogs: FetchedResults<SpeedLog>

    let compact: Bool

    @AppStorage("history.presentation") private var presentation: HistoryPresentation = .table
    @AppStorage("history.metric") private var metric: HistoryMetric = .download
    @State private var isShowingDeleteConfirmation = false
    @State private var isExporting = false
    @State private var exportDocument = CSVDocument(text: "")
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if compact {
                compactContent
            } else {
                fullContent
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "NetworkLight Export"
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Delete all measurements?",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button("Delete All", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes \(speedLogs.count) saved measurements.")
        }
        .alert(
            "NetworkLight",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Tests")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(speedLogs.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if speedLogs.isEmpty {
                Label("No measurements yet", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 42)
            } else {
                ForEach(speedLogs.prefix(3)) { log in
                    HStack(spacing: 10) {
                        Text(log.date?.formatted(date: .omitted, time: .shortened) ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .leading)
                        Label(
                            log.download.formatted(.number.precision(.fractionLength(0...1))),
                            systemImage: "arrow.down"
                        )
                        Label(
                            log.upload.formatted(.number.precision(.fractionLength(0...1))),
                            systemImage: "arrow.up"
                        )
                        Spacer()
                        Text("Mbps")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption.monospacedDigit())
                }
            }
        }
    }

    private var fullContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection History")
                        .font(.title2.weight(.semibold))
                    Text("Review and export your saved network quality measurements.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("View", selection: $presentation) {
                    ForEach(HistoryPresentation.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }
            .padding()

            Divider()

            Group {
                if speedLogs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No Measurements")
                            .font(.title3.weight(.semibold))
                        Text("Run a speed test from the menu bar to start building your history.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if presentation == .table {
                    historyTable
                } else {
                    historyChart
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Text("\(speedLogs.count) measurement\(speedLogs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Export…", systemImage: "square.and.arrow.up") {
                    exportDocument = CSVDocument(text: makeCSV())
                    isExporting = true
                }
                .disabled(speedLogs.isEmpty)
                .keyboardShortcut("s")

                Button("Delete All", systemImage: "trash", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
                .disabled(speedLogs.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 620, minHeight: 420)
    }

    private var historyTable: some View {
        Table(of: SpeedLog.self) {
            TableColumn("Date") { log in
                Text(log.date?.formatted(date: .abbreviated, time: .standard) ?? "—")
            }
            .width(min: 150, ideal: 180)

            TableColumn("Download") { log in
                speedText(log.download)
            }
            .width(min: 100, ideal: 120)

            TableColumn("Upload") { log in
                speedText(log.upload)
            }
            .width(min: 100, ideal: 120)

            TableColumn("Responsiveness") { log in
                Text("\(log.responsiveness) RPM")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 110, ideal: 130)

            TableColumn("") { log in
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(log)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Delete this measurement")
            }
            .width(32)
        } rows: {
            ForEach(speedLogs) { log in
                TableRow(log)
            }
        }
    }

    private var historyChart: some View {
        VStack(spacing: 0) {
            Picker("Metric", selection: $metric) {
                ForEach(HistoryMetric.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding()

            Chart(Array(speedLogs.reversed())) { log in
                if let date = log.date {
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Mbps", value(for: log))
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", date),
                        y: .value("Mbps", value(for: log))
                    )
                    .symbolSize(22)
                }
            }
            .foregroundStyle(.tint)
            .chartYAxisLabel("Mbps")
            .chartYScale(domain: 0...chartMaximum)
            .padding([.horizontal, .bottom])
        }
    }

    private var chartMaximum: Double {
        let maximum = speedLogs.map(value(for:)).max() ?? 0
        return max(maximum * 1.1, 10)
    }

    private func value(for log: SpeedLog) -> Double {
        metric == .download ? log.download : log.upload
    }

    private func speedText(_ value: Double) -> some View {
        Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) Mbps")
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func delete(_ log: SpeedLog) {
        viewContext.delete(log)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        do {
            if viewContext.hasChanges { try viewContext.save() }

            let request = NSBatchDeleteRequest(
                fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "SpeedLog")
            )
            request.resultType = .resultTypeObjectIDs
            let result = try viewContext.execute(request) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [viewContext]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeCSV() -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let locale = Locale(identifier: "en_US_POSIX")

        var lines = ["Date (ISO 8601),Upload (Mbps),Download (Mbps),Responsiveness (RPM)"]
        lines.append(contentsOf: speedLogs.map { log in
            let date = log.date.map(isoFormatter.string(from:)) ?? ""
            let upload = String(format: "%.2f", locale: locale, log.upload)
            let download = String(format: "%.2f", locale: locale, log.download)
            return "\(csvField(date)),\(upload),\(download),\(log.responsiveness)"
        })
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#Preview {
    HistoryView(compact: false)
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}

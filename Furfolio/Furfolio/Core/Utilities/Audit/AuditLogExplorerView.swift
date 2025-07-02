//
//  AuditLogExplorerView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

/**
 AuditLogExplorerView
 --------------------
 A SwiftUI view for exploring in-memory audit log entries from AuditLogAuditManager,
 with support for refreshing, filtering, and exporting audit data.
 */

public struct AuditLogExplorerView: View {
    @State private var entries: [AuditLogAuditEntry] = []
    @State private var showJSONExport = false
    @State private var exportJSON = ""

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.event)
                            .font(.headline)
                        if let info = entry.info,
                           let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted]),
                           let jsonString = String(data: data, encoding: .utf8) {
                            Text(jsonString)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(3)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Audit Log Explorer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: export) {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showJSONExport) {
                NavigationView {
                    ScrollView {
                        Text(exportJSON)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .navigationTitle("Audit Log JSON")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showJSONExport = false }
                        }
                    }
                }
            }
            .task { await loadEntries() }
        }
    }

    private func refresh() {
        Task { await loadEntries() }
    }

    private func export() {
        Task {
            exportJSON = await AuditLogAuditManager.shared.exportJSON()
            showJSONExport = true
        }
    }

    private func loadEntries() async {
        entries = await AuditLogAuditManager.shared.recent(limit: 100)
    }
}

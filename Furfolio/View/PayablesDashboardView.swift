//
//  PayablesDashboardView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData
import os

struct PayablesDashboardView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PayablesDashboardView")
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.dueDate, order: .forward)]) private var invoices: [VendorInvoice]
    
    private var dueSoonInvoices: [VendorInvoice] {
        let today = Calendar.current.startOfDay(for: Date())
        let weekAhead = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        return invoices.filter { !$0.isPaid && $0.dueDate >= today && $0.dueDate <= weekAhead }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !dueSoonInvoices.isEmpty {
                    Section(header: Text("Due in the Next 7 Days")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.primaryText)
                    ) {
                        ForEach(dueSoonInvoices) { invoice in
                            InvoiceRow(invoice: invoice)
                        }
                    }
                }
                Section(header: Text("All Payables")
                        .font(AppTheme.title)
                        .foregroundColor(AppTheme.primaryText)
                ) {
                    ForEach(invoices) { invoice in
                        InvoiceRow(invoice: invoice)
                    }
                }
            }
            .navigationTitle("Payables")
            .listStyle(InsetGroupedListStyle())
        }
        .onAppear {
            logger.log("PayablesDashboardView appeared; total invoices: \(invoices.count), dueSoon: \(dueSoonInvoices.count)")
        }
    }
}

private struct InvoiceRow: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "InvoiceRowView")
    @Environment(\.modelContext) private var context
    @ObservedObject var invoice: VendorInvoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(invoice.vendorName)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                Text(invoice.dueDate, style: .date)
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            Spacer()
            Text(invoice.amount, format: .currency(code: invoice.currencyCode ?? Locale.current.currency?.identifier ?? "USD"))
                .font(AppTheme.body)
                .foregroundColor(AppTheme.primaryText)
            Button(action: {
                logger.log("Mark as Paid tapped for invoice id: \(invoice.id)")
                markAsPaid()
            }) {
                Image(systemName: invoice.isPaid ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(invoice.isPaid ? .green : .secondary)
            }
            .buttonStyle(FurfolioButtonStyle())
        }
        .padding(.vertical, 4)
        .onAppear {
            logger.log("InvoiceRow appeared for invoice id: \(invoice.id), isPaid: \(invoice.isPaid)")
        }
    }
    
    private func markAsPaid() {
        logger.log("markAsPaid: setting isPaid=true for invoice id: \(invoice.id)")
        invoice.isPaid = true
        if context.inTransaction {
            do {
                try context.save()
                logger.log("markAsPaid: saved context for invoice id: \(invoice.id)")
            } catch {
                logger.error("markAsPaid failed to save: \(error.localizedDescription)")
            }
        }
    }
}

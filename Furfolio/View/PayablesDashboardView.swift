//
//  PayablesDashboardView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData

struct PayablesDashboardView: View {
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
                    Section("Due in the Next 7 Days") {
                        ForEach(dueSoonInvoices) { invoice in
                            InvoiceRow(invoice: invoice)
                        }
                    }
                }
                Section("All Payables") {
                    ForEach(invoices) { invoice in
                        InvoiceRow(invoice: invoice)
                    }
                }
            }
            .navigationTitle("Payables")
            .listStyle(InsetGroupedListStyle())
        }
    }
}

private struct InvoiceRow: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var invoice: VendorInvoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(invoice.vendorName)
                    .font(.headline)
                Text(invoice.dueDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(invoice.amount, format: .currency(code: invoice.currencyCode ?? Locale.current.currency?.identifier ?? "USD"))
            Button(action: markAsPaid) {
                Image(systemName: invoice.isPaid ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(invoice.isPaid ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func markAsPaid() {
        invoice.isPaid = true
        if context.inTransaction {
            try? context.save()
        }
    }
}

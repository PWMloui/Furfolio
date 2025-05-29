import SwiftUI
import SwiftData
import os

struct ExpenseEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ExpenseEntryView")

    @State private var date: Date = Date()
    @State private var category: String = ""
    @State private var amountText: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var showValidationError: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Expense Details")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.primaryText)) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.primaryText)
                    TextField("Category", text: $category)
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.primaryText)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.primaryText)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.primaryText)
                }

                if isSaving {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Saving…")
                                .font(AppTheme.body)
                                .onAppear {
                                    logger.log("ExpenseEntryView showing saving overlay")
                                }
                            Spacer()
                        }
                    }
                    .listRowBackground(AppTheme.background.opacity(0.5))
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        logger.log("ExpenseEntryView Cancel tapped")
                        dismiss()
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        logger.log("ExpenseEntryView Save tapped: category=\(category), amount=\(amountText)")
                        guard let amount = Double(amountText), amount > 0 else {
                            logger.error("Validation failed: invalid amount \(amountText)")
                            showValidationError = true
                            return
                        }
                        isSaving = true
                        let expense = Expense(
                            date: date,
                            category: category,
                            amount: amount,
                            notes: notes.isEmpty ? nil : notes
                        )
                        context.insert(expense)
                        do {
                            try context.save()
                            logger.log("ExpenseEntryView saved Expense id: \(expense.id)")
                            dismiss()
                        } catch {
                            logger.error("ExpenseEntryView failed to save: \(error.localizedDescription)")
                        }
                        isSaving = false
                    }
                    .disabled(isSaving || category.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountText) == nil)
                    .buttonStyle(FurfolioButtonStyle())
                }
            }
            .onAppear {
                logger.log("ExpenseEntryView appeared")
            }
            .alert("Invalid amount", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {
                    logger.log("ExpenseEntryView validation error alert dismissed")
                }
            } message: {
                Text("Please enter a valid amount greater than zero.")
                    .font(AppTheme.body)
            }
        }
    }
}

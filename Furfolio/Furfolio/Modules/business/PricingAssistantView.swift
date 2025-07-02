//
//  PricingAssistantView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - Service Model

struct GroomingService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var basePrice: Double
    var competitorAvg: Double
    var costEstimate: Double  // Your internal cost per service
}

// MARK: - ViewModel

@MainActor
class PricingAssistantViewModel: ObservableObject {
    @Published var services: [GroomingService] = []
    @Published var selectedService: GroomingService?
    @Published var suggestedPrice: Double?
    @Published var customPriceInput: String = ""
    @Published var margin: Double = 0
    @Published var errorMessage: String?
    @Published var showSaveConfirmation: Bool = false
    
    init() {
        loadServices()
    }
    
    func loadServices() {
        // Replace with a real fetch from your DB or API as needed
        services = [
            GroomingService(name: "Full Groom", basePrice: 95, competitorAvg: 110, costEstimate: 60),
            GroomingService(name: "Basic Bath", basePrice: 60, competitorAvg: 58, costEstimate: 35),
            GroomingService(name: "Nail Trim", basePrice: 20, competitorAvg: 22, costEstimate: 8)
        ]
        selectedService = services.first
        updateSuggestedPrice()
    }
    
    func selectService(_ service: GroomingService) {
        selectedService = service
        customPriceInput = String(format: "%.2f", service.basePrice)
        updateSuggestedPrice()
    }
    
    func updateSuggestedPrice() {
        guard let service = selectedService else { return }
        // Simple recommendation: midpoint between cost+30% and competitor average, with min margin
        let minRecommended = service.costEstimate * 1.3
        let suggestion = max(minRecommended, (service.competitorAvg + minRecommended) / 2)
        suggestedPrice = suggestion
        // Update margin for current input
        updateMargin()
    }
    
    func updateMargin() {
        guard let service = selectedService else { margin = 0; return }
        let price = Double(customPriceInput) ?? service.basePrice
        margin = price - service.costEstimate
    }
    
    func setCustomPrice(_ value: String) {
        customPriceInput = value
        updateMargin()
    }
    
    /// Computes the recommended price band as a minimum and maximum price based on cost and competitor average.
    func recommendedPriceBand() -> (min: Double, max: Double)? {
        guard let service = selectedService else { return nil }
        let minPrice = service.costEstimate * 1.3
        let maxPrice = service.competitorAvg * 1.1
        return (minPrice, maxPrice)
    }
    
    /// Generates a dynamic tip text and status color based on the user's custom price relative to market and margin.
    func pricingTip() -> (text: String, color: Color)? {
        guard let service = selectedService else { return nil }
        let price = Double(customPriceInput) ?? service.basePrice
        let minPrice = service.costEstimate * 1.3
        let maxPrice = service.competitorAvg * 1.1
        
        if price < minPrice {
            return ("You’re underpriced", .red)
        } else if price >= minPrice && price <= service.competitorAvg {
            return ("You’re on par", .green)
        } else if price > service.competitorAvg && price <= maxPrice {
            return ("You’re above average", .orange)
        } else {
            return ("You’re premium priced", .blue)
        }
    }
    
    /// Simulates saving the new price by updating the base price for the selected service and showing a confirmation alert.
    func savePrice() {
        guard let service = selectedService,
              let newPrice = Double(customPriceInput),
              newPrice != service.basePrice else { return }
        
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index].basePrice = newPrice
            selectedService = services[index]
            updateSuggestedPrice()
            showSaveConfirmation = true
        }
    }
}

// MARK: - Main View

struct PricingAssistantView: View {
    @StateObject private var viewModel = PricingAssistantViewModel()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Service Picker
                Picker("Select Service", selection: $viewModel.selectedService) {
                    ForEach(viewModel.services) { service in
                        Text(service.name).tag(service as GroomingService?)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedService) { newValue in
                    if let svc = newValue { viewModel.selectService(svc) }
                }
                
                if let service = viewModel.selectedService {
                    // Pricing Details
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Your Base Price", systemImage: "dollarsign.circle")
                            Spacer()
                            Text("$\(service.basePrice, specifier: "%.2f")")
                        }
                        HStack {
                            Label("Competitor Avg.", systemImage: "chart.bar.xaxis")
                            Spacer()
                            Text("$\(service.competitorAvg, specifier: "%.2f")")
                                .foregroundColor(service.basePrice < service.competitorAvg ? .green : .secondary)
                        }
                        HStack {
                            Label("Your Estimated Cost", systemImage: "scissors")
                            Spacer()
                            Text("$\(service.costEstimate, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    
                    // What-If Pricing Calculator
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try a New Price")
                            .font(.headline)
                        HStack {
                            TextField("Enter price", text: $viewModel.customPriceInput)
                                .keyboardType(.decimalPad)
                                .frame(width: 100)
                                .onChange(of: viewModel.customPriceInput) { _ in viewModel.updateMargin() }
                            Button("Apply") {
                                // Optionally save/preview change
                                viewModel.updateMargin()
                            }
                        }
                        HStack {
                            Text("Margin: ")
                            Text("$\(viewModel.margin, specifier: "%.2f")")
                                .foregroundColor(viewModel.margin >= 0 ? .green : .red)
                        }
                        if let suggestion = viewModel.suggestedPrice {
                            HStack {
                                Label("Smart Suggestion", systemImage: "lightbulb")
                                    .foregroundColor(.accentColor)
                                Spacer()
                                Text("$\(suggestion, specifier: "%.2f")")
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    
                    // Advanced Insights Section
                    if let band = viewModel.recommendedPriceBand(),
                       let tip = viewModel.pricingTip() {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Advanced Insights")
                                .font(.headline)
                            HStack {
                                Text("Recommended Price Band:")
                                Spacer()
                                Text("$\(band.min, specifier: "%.2f") - $\(band.max, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                            }
                            HStack(spacing: 8) {
                                Text(tip.text)
                                    .font(.subheadline)
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(tip.color.opacity(0.2)))
                                    .foregroundColor(tip.color)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            Button("Save Price") {
                                viewModel.savePrice()
                            }
                            .disabled((Double(viewModel.customPriceInput) ?? service.basePrice) == service.basePrice)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    }
                }
                
                // Price Comparison Chart (optional, iOS 16+)
                if let service = viewModel.selectedService {
                    if #available(iOS 16.0, *) {
                        PriceComparisonChart(
                            yourPrice: Double(viewModel.customPriceInput) ?? service.basePrice,
                            competitorAvg: service.competitorAvg,
                            cost: service.costEstimate
                        )
                        .frame(height: 150)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pricing Assistant")
            .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Price Saved", isPresented: $viewModel.showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your new price has been saved successfully.")
            }
        }
    }
}

// MARK: - Chart (Swift Charts, iOS 16+)

import Charts

@available(iOS 16.0, *)
struct PriceComparisonChart: View {
    let yourPrice: Double
    let competitorAvg: Double
    let cost: Double
    var body: some View {
        Chart {
            BarMark(x: .value("Type", "Your Price"), y: .value("Price", yourPrice))
                .foregroundStyle(.blue)
            BarMark(x: .value("Type", "Competitor Avg"), y: .value("Price", competitorAvg))
                .foregroundStyle(.orange)
            BarMark(x: .value("Type", "Your Cost"), y: .value("Price", cost))
                .foregroundStyle(.gray)
        }
        .chartYAxis {
            AxisMarks(format: .currency(code: "USD"))
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    PricingAssistantView()
}

//
//  ServiceMatrixView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - Service Data Model

// ServiceMatrixEntry now includes avgRating (randomized for mock)
struct ServiceMatrixEntry: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let avgDuration: Double // In minutes
    let popularity: Int     // Number of times booked
    let usedByPets: Int     // Number of unique pets
    let avgRating: Double   // Mocked average rating
}

// MARK: - ViewModel

@MainActor
class ServiceMatrixViewModel: ObservableObject {
    @Published var services: [ServiceMatrixEntry] = []
    @Published var sortType: SortType = .popularityDescending
    
    enum SortType: String, CaseIterable, Identifiable {
        case popularityDescending = "Most Popular"
        case priceAscending = "Lowest Price"
        case priceDescending = "Highest Price"
        case durationAscending = "Quickest"
        case durationDescending = "Longest"
        
        var id: String { rawValue }
    }
    
    init() {
        loadServices()
    }
    
    func loadServices() {
        // Replace with actual analytics/database fetch
        // Assign random avgRating between 4.1 and 4.9 for mock
        func randomRating() -> Double {
            Double.random(in: 4.1...4.9)
        }
        services = [
            ServiceMatrixEntry(name: "Full Groom", price: 95, avgDuration: 90, popularity: 180, usedByPets: 105, avgRating: randomRating()),
            ServiceMatrixEntry(name: "Basic Bath", price: 60, avgDuration: 45, popularity: 110, usedByPets: 82, avgRating: randomRating()),
            ServiceMatrixEntry(name: "Nail Trim", price: 20, avgDuration: 15, popularity: 220, usedByPets: 180, avgRating: randomRating()),
            ServiceMatrixEntry(name: "Deshedding", price: 45, avgDuration: 60, popularity: 75, usedByPets: 48, avgRating: randomRating())
        ]
        applySort()
    }
    
    func applySort() {
        switch sortType {
        case .popularityDescending:
            services.sort { $0.popularity > $1.popularity }
        case .priceAscending:
            services.sort { $0.price < $1.price }
        case .priceDescending:
            services.sort { $0.price > $1.price }
        case .durationAscending:
            services.sort { $0.avgDuration < $1.avgDuration }
        case .durationDescending:
            services.sort { $0.avgDuration > $1.avgDuration }
        }
    }
}

// MARK: - Main View

struct ServiceMatrixView: View {
    @StateObject private var viewModel = ServiceMatrixViewModel()

    // MARK: - State for CSV Export
    @State private var csvExportURL: URL?
    @State private var showShareSheet = false

    // MARK: - State for Search
    @State private var searchText: String = ""

    // MARK: - State for Info Sheet
    @State private var selectedService: ServiceMatrixEntry?
    @State private var showInfoSheet: Bool = false

    var filteredServices: [ServiceMatrixEntry] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.services
        } else {
            return viewModel.services.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // Find the most popular service (for row highlighting)
    var mostPopularServiceID: UUID? {
        viewModel.services.max(by: { $0.popularity < $1.popularity })?.id
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Top Bar: Title, Sort Picker, CSV Export Button
                HStack {
                    Text("Service Matrix")
                        .font(.largeTitle).bold()
                    Spacer()
                    Picker("Sort", selection: $viewModel.sortType) {
                        ForEach(ServiceMatrixViewModel.SortType.allCases) { type in
                            Text(type.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.sortType) { _ in
                        viewModel.applySort()
                    }
                    // CSV Export Button
                    Button {
                        exportCSV()
                    } label: {
                        Label("CSV Export", systemImage: "square.and.arrow.up")
                    }
                    .padding(.leading, 12)
                }
                .padding(.top, 4)

                // MARK: - Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search services...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.bottom, 4)

                if filteredServices.isEmpty {
                    Spacer()
                    Text("No service data available.")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    // MARK: - Matrix Table
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            HStack {
                                matrixHeader("Service")
                                matrixHeader("Price")
                                matrixHeader("Avg Time")
                                matrixHeader("Popularity")
                                matrixHeader("Unique Pets")
                                matrixHeader("Avg Rating")
                                Spacer().frame(width: 32) // For Info button
                            }
                            .background(Color(.systemGray5))

                            ForEach(filteredServices) { service in
                                HStack {
                                    Text(service.name)
                                        .font(.body)
                                    Spacer()
                                    Text("$\(service.price, specifier: "%.2f")")
                                    Spacer()
                                    Text("\(Int(service.avgDuration)) min")
                                    Spacer()
                                    Text("\(service.popularity)")
                                        .foregroundColor(service.popularity > 100 ? .green : .secondary)
                                    Spacer()
                                    Text("\(service.usedByPets)")
                                    Spacer()
                                    Text(String(format: "%.1f", service.avgRating))
                                        .foregroundColor(.orange)
                                    Spacer()
                                    // MARK: - Info Button (shows service details)
                                    Button {
                                        selectedService = service
                                        showInfoSheet = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(width: 32)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 2)
                                // Highlight row if most popular
                                .background(
                                    service.id == mostPopularServiceID
                                    ? Color.yellow.opacity(0.18)
                                    : Color(.systemBackground)
                                )
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color(.systemGray6)),
                                    alignment: .bottom
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Service Matrix")
            // MARK: - CSV Share Sheet
            .sheet(isPresented: $showShareSheet, onDismiss: { csvExportURL = nil }) {
                if let url = csvExportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            // MARK: - Info Sheet for Service Details
            .sheet(isPresented: $showInfoSheet, onDismiss: { selectedService = nil }) {
                if let service = selectedService {
                    ServiceDetailSheet(service: service)
                }
            }
        }
    }

    // MARK: - Header Cell Helper
    func matrixHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .foregroundColor(.accentColor)
    }

    // MARK: - CSV Export Functionality
    func exportCSV() {
        let header = "Service,Price,Avg Time,Popularity,Unique Pets,Avg Rating"
        let rows = filteredServices.map { s in
            "\"\(s.name)\",\"\(s.price)\",\"\(Int(s.avgDuration))\",\"\(s.popularity)\",\"\(s.usedByPets)\",\"\(String(format: "%.1f", s.avgRating))\""
        }
        let csvString = ([header] + rows).joined(separator: "\n")
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("ServiceMatrix.csv")
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvExportURL = fileURL
            showShareSheet = true
        } catch {
            // handle error, could show alert
        }
    }
}

// MARK: - ShareSheet Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Service Detail Sheet
struct ServiceDetailSheet: View {
    let service: ServiceMatrixEntry
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(service.name)
                    .font(.title).bold()
                HStack {
                    Text("Price:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(service.price, specifier: "%.2f")")
                }
                HStack {
                    Text("Avg Duration:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(service.avgDuration)) min")
                }
                HStack {
                    Text("Popularity:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(service.popularity) bookings")
                }
                HStack {
                    Text("Unique Pets:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(service.usedByPets)")
                }
                HStack {
                    Text("Avg Rating:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "%.1f", service.avgRating))
                        .foregroundColor(.orange)
                }
                Divider()
                Text("Top Customers")
                    .font(.headline)
                Text("Coming soon...")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Service Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    ServiceMatrixView()
}

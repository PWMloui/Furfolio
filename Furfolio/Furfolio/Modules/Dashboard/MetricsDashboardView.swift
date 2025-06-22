//
//  MetricsDashboardView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Refactored by Gemini on 6/22/25.
//

import SwiftUI

struct MetricsDashboardView: View {
    
    /// The ViewModel holding the data for the dashboard.
    @StateObject private var viewModel = DashboardViewModel()
    
    /// The manager that dictates which widgets are visible and in what order.
    /// This makes the dashboard layout dynamic and user-configurable.
    @StateObject private var widgetManager = DashboardWidgetManager()
    
    /// State to control the presentation of the customization sheet.
    @State private var isShowingCustomizationSheet = false

    // Defines the grid layout for the dashboard items.
    // It creates a flexible grid with 2 columns on regular width (iPad/Mac)
    // and 1 column on compact width (iPhone).
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerView
                    
                    // Dynamic Widget Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        // We iterate through the widgets from the manager that are enabled.
                        ForEach(widgetManager.widgets.filter { $0.isEnabled }) { widget in
                            // The `widgetView(for:)` function determines which
                            // specific view to render for the given widget.
                            widgetView(for: widget)
                        }
                    }
                    .padding(.horizontal)
                    
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar items for refreshing and customizing the dashboard.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isShowingCustomizationSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Customize dashboard widgets")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button(action: { Task { await viewModel.refreshData() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh dashboard data")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $isShowingCustomizationSheet) {
                // Presents the customization view we created earlier.
                DashboardCustomizationView(manager: widgetManager)
            }
        }
    }
    
    /// The main header view for the dashboard.
    private var headerView: some View {
        Text("Your Business Snapshot")
            .font(.largeTitle.bold())
            .padding(.horizontal)
    }

    /// This is the core of the dynamic layout. It acts as a factory, returning the
    /// correct SwiftUI view based on the widget's title.
    /// In a production app, you would use a more robust identifier, like an enum,
    /// instead of relying on a String.
    @ViewBuilder
    private func widgetView(for widget: DashboardWidget) -> some View {
        switch widget.title {
        case "Revenue":
            KPIStatCard(
                title: "Total Revenue",
                value: String(format: "$%.2f", viewModel.totalRevenue),
                subtitle: "This Month",
                systemIconName: "dollarsign.circle.fill",
                iconBackgroundColor: .green
            )
        case "Appointments":
            KPIStatCard(
                title: "Upcoming Appointments",
                value: "\(viewModel.upcomingAppointmentsCount)",
                subtitle: "Next 7 Days",
                systemIconName: "calendar",
                iconBackgroundColor: .blue
            )
        case "Customer Retention":
            KPIStatCard(
                title: "Customer Retention",
                value: String(format: "%.0f%%", viewModel.customerRetentionRate * 100),
                subtitle: "Last Month",
                systemIconName: "arrow.2.squarepath",
                iconBackgroundColor: .purple
            )
        case "Loyalty Program":
            KPIStatCard(
                title: "Loyalty Progress",
                value: "\(Int(viewModel.loyaltyProgress * 100))%",
                subtitle: "Towards Reward",
                systemIconName: "star.circle.fill",
                iconBackgroundColor: .yellow
            )
        // You would add cases here for your chart widgets
        // case "Revenue Trend":
        //     RevenueTrendChart(data: viewModel.revenueData)
        //         .frame(height: 260)
        // case "Service Mix":
        //     ServiceMixChart(data: viewModel.serviceMixData)
        //         .frame(height: 320)
            
        default:
            // A fallback view for any unrecognized widget types.
            EmptyView()
        }
    }
}

// MARK: - Reusable KPI Card View
// This would likely live in its own file in a "Components" or "Reusable Views" group.

struct KPIStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemIconName: String
    let iconBackgroundColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemIconName)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(iconBackgroundColor)
                    .clipShape(Circle())
                
                Spacer()
            }
            
            Text(value)
                .font(.system(.largeTitle, design: .rounded).bold())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
}


// MARK: - Preview
#if DEBUG
struct MetricsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MetricsDashboardView()
            .preferredColorScheme(.dark)
    }
}
#endif

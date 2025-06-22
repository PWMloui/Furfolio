//
//  DashboardFilterBar.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct DashboardFilterBar: View {
    @Binding var selectedPeriod: TimePeriod
    @Binding var selectedDataType: DataType

    var onPeriodChange: ((TimePeriod) -> Void)?
    var onDataTypeChange: ((DataType) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            filterSection(
                title: "Time Period",
                options: TimePeriod.allCases,
                selected: selectedPeriod
            ) { newPeriod in
                selectedPeriod = newPeriod
                onPeriodChange?(newPeriod)
            }

            filterSection(
                title: "Data Type",
                options: DataType.allCases,
                selected: selectedDataType
            ) { newDataType in
                selectedDataType = newDataType
                onDataTypeChange?(newDataType)
            }
        }
        .padding(.vertical, 8)
    }

    private func filterSection<T: Hashable & RawRepresentable>(
        title: String,
        options: [T],
        selected: T,
        action: @escaping (T) -> Void
    ) -> some View where T.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        action(option)
                    }) {
                        Text(option.rawValue)
                            .fontWeight(selected == option ? .bold : .regular)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(selected == option ? Color.accentColor.opacity(0.25) : Color.clear)
                            .foregroundColor(selected == option ? .accentColor : .primary)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Filter by \(option.rawValue)")
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Enums

enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
}

enum DataType: String, CaseIterable {
    case revenue = "Revenue"
    case appointments = "Appointments"
    case customers = "Customers"
}

// MARK: - Preview

#if DEBUG
struct DashboardFilterBar_Previews: PreviewProvider {
    @State static var selectedPeriod: TimePeriod = .week
    @State static var selectedDataType: DataType = .revenue

    static var previews: some View {
        DashboardFilterBar(
            selectedPeriod: $selectedPeriod,
            selectedDataType: $selectedDataType
        ) { period in
            print("Selected period: \(period.rawValue)")
        } onDataTypeChange: { dataType in
            print("Selected data type: \(dataType.rawValue)")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif

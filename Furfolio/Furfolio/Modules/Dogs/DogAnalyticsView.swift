//
//  DogAnalyticsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct BehaviorTrendPoint: Identifiable {
    let id = UUID()
    let behavior: String
    let date: Date
    let rating: Int
}

struct BehaviorTrendChart: View {
    let data: [BehaviorTrendPoint]

    var body: some View {
        // Simple placeholder chart representation
        VStack(alignment: .leading) {
            ForEach(data) { point in
                HStack {
                    Text(point.behavior)
                        .frame(width: 80, alignment: .leading)
                    Text(point.date, style: .date)
                        .frame(width: 100, alignment: .leading)
                    HStack(spacing: 2) {
                        ForEach(0..<point.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Behavior trend chart")
    }
}

struct DogAnalyticsView: View {
    // Placeholder data for behavior trends
    let behaviorData: [BehaviorTrendPoint]

    // Placeholder data for grooming and health summary
    let totalVisits: Int
    let lastVisitDate: Date
    let vaccinationsUpToDate: Bool
    let allergies: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Behavior Trends")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)

                BehaviorTrendChart(data: behaviorData)
                    .frame(height: 250)
                    .padding(.horizontal)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Grooming History")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        Text("Total Visits:")
                            .font(.headline)
                        Spacer()
                        Text("\(totalVisits)")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Total grooming visits: \(totalVisits)")

                    HStack {
                        Text("Last Visit:")
                            .font(.headline)
                        Spacer()
                        Text(lastVisitDate, style: .date)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Last grooming visit date: \(lastVisitDate, formatter: DateFormatter.shortDate)")
                }
                .padding(.horizontal)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Health Summary")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        Text("Vaccinations Up to Date:")
                            .font(.headline)
                        Spacer()
                        Image(systemName: vaccinationsUpToDate ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundColor(vaccinationsUpToDate ? .green : .red)
                            .accessibilityLabel(vaccinationsUpToDate ? "Vaccinations up to date" : "Vaccinations overdue")
                    }
                    .accessibilityElement(children: .combine)

                    if allergies.isEmpty {
                        Text("No known allergies")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No known allergies")
                    } else {
                        VStack(alignment: .leading) {
                            Text("Allergies:")
                                .font(.headline)
                            ForEach(allergies, id: \.self) { allergy in
                                Text("• \(allergy)")
                                    .accessibilityLabel("Allergy: \(allergy)")
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Dog Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension DateFormatter {
    static var shortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

#if DEBUG
struct DogAnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let behaviors = ["Calm", "Anxious", "Playful"]

        var sampleBehaviorData: [BehaviorTrendPoint] = []

        for behavior in behaviors {
            for monthOffset in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let rating = Int.random(in: 1...5)
                    sampleBehaviorData.append(BehaviorTrendPoint(behavior: behavior, date: date, rating: rating))
                }
            }
        }

        NavigationView {
            DogAnalyticsView(
                behaviorData: sampleBehaviorData,
                totalVisits: 12,
                lastVisitDate: today.addingTimeInterval(-86400 * 30),
                vaccinationsUpToDate: true,
                allergies: ["Pollen", "Dust"]
            )
        }
    }
}
#endif

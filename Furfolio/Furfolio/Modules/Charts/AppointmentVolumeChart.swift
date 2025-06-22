import SwiftUI
import Charts

struct AppointmentVolumeChart: View {
    let appointmentsByDate: [Date: Int]

    private var sortedData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let past14Days = (0..<14).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        return past14Days.map { date in
            (date, appointmentsByDate[date] ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appointments (Last 14 Days)")
                .font(.title3).bold()
                .padding(.horizontal)

            Chart(sortedData, id: \.date) { entry in
                BarMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Appointments", entry.count)
                )
                .foregroundStyle(Color.accentColor)
                .annotation(position: .top) {
                    if entry.count > 0 {
                        Text("\(entry.count)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appointment volume chart for the last 14 days")
    }
}

#if DEBUG
struct AppointmentVolumeChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sampleData: [Date: Int] = [:]
        for i in 0..<14 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                sampleData[date] = Int.random(in: 0...5)
            }
        }
        return AppointmentVolumeChart(appointmentsByDate: sampleData)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

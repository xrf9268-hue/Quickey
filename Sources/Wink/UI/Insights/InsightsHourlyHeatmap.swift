import SwiftUI

struct InsightsHourlyHeatmap: View {
    @Environment(\.winkPalette) private var palette

    let buckets: [HourlyUsageBucket]

    private var groupedRows: [(date: String, counts: [Int])] {
        let orderedDates = buckets.reduce(into: [String]()) { dates, bucket in
            if dates.last != bucket.date {
                dates.append(bucket.date)
            }
        }
        let grouped = Dictionary(grouping: buckets, by: \.date)

        return orderedDates.map { date in
            let counts = (0..<24).map { hour in
                grouped[date, default: []].first(where: { $0.hour == hour })?.count ?? 0
            }
            return (date: date, counts: counts)
        }
    }

    private var maxCount: Int {
        max(buckets.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        WinkCard(
            title: {
                Text("Hourly heatmap")
            },
            accessory: {
                Text("Past 7 days")
                    .font(WinkType.labelSmall)
                    .foregroundStyle(palette.textTertiary)
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                hourScale

                VStack(spacing: 4) {
                    ForEach(groupedRows, id: \.date) { row in
                        HStack(spacing: 6) {
                            Text(dayLabel(for: row.date))
                                .font(WinkType.labelSmall)
                                .foregroundStyle(palette.textTertiary)
                                .frame(width: 28, alignment: .leading)

                            HStack(spacing: 2) {
                                ForEach(Array(row.counts.enumerated()), id: \.offset) { _, count in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(fill(for: count))
                                        .frame(width: 10, height: 12)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var hourScale: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 34)

            HStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Group {
                        if [0, 6, 12, 18].contains(hour) {
                            Text("\(hour)")
                                .font(WinkType.labelSmall)
                                .foregroundStyle(palette.textTertiary)
                                .frame(width: 12, alignment: .leading)
                        } else {
                            Color.clear.frame(width: 12)
                        }
                    }
                }
            }
        }
    }

    private func fill(for count: Int) -> Color {
        guard count > 0 else {
            return palette.heatmapBase
        }

        let normalized = Double(count) / Double(maxCount)
        return palette.accent.opacity(0.18 + (normalized * 0.72))
    }

    private func dayLabel(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = Calendar(identifier: .gregorian)
        weekdayFormatter.dateFormat = "EEE"
        weekdayFormatter.timeZone = .current
        return weekdayFormatter.string(from: date)
    }
}

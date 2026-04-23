import SwiftUI

enum InsightsTabCopy {
    static let rankingSectionTitle = "Most used"
    static let emptyRankingText = "No shortcuts used in this period"
}

struct InsightsTabView: View {
    @Environment(\.winkPalette) private var palette

    @Bindable var viewModel: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                InsightsUnusedNudge(appNames: viewModel.unusedShortcutNames)

                InsightsKpiSection(
                    totalCount: viewModel.totalCount,
                    previousPeriodTotal: viewModel.previousPeriodTotal,
                    currentStreakDays: viewModel.currentStreakDays,
                    sparklinePoints: viewModel.activationSparklinePoints
                )

                InsightsHourlyHeatmap(buckets: viewModel.heatmapBuckets)

                WinkCard(
                    title: {
                        Text(InsightsTabCopy.rankingSectionTitle)
                    },
                    accessory: {
                        Text("\(viewModel.totalCount.formatted(.number.grouping(.automatic))) activations")
                            .font(WinkType.labelSmall)
                            .foregroundStyle(palette.textTertiary)
                    }
                ) {
                    if viewModel.appRows.isEmpty {
                        Text(InsightsTabCopy.emptyRankingText)
                            .font(WinkType.bodyText)
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 18)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.appRows.enumerated()), id: \.element.id) { index, item in
                                InsightsAppRow(
                                    item: item,
                                    showsDivider: index < viewModel.appRows.count - 1
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .background(palette.windowBg)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insights")
                    .font(WinkType.tabTitle)
                    .foregroundStyle(palette.textPrimary)
                Text("Usage trends for your saved shortcuts.")
                    .font(WinkType.bodyText)
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Picker("", selection: $viewModel.period) {
                ForEach(InsightsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .labelsHidden()
        }
    }
}

import AppKit
import SwiftUI

enum InsightsTabCopy {
    static let rankingSectionTitle = "Most Used"
    static let emptyRankingText = "No shortcuts used in this period"
}

enum InsightsVisualStyle {
    static let accent = Color(
        nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua:
                return NSColor(srgbRed: 0.44, green: 0.63, blue: 0.79, alpha: 1)
            default:
                return NSColor(srgbRed: 0.34, green: 0.53, blue: 0.69, alpha: 1)
            }
        }
    )
    static let bannerBackground = Color.primary.opacity(0.05)
    static let listBackground = Color.primary.opacity(0.045)
    static let separator = Color.primary.opacity(0.07)
    static let barHeight: CGFloat = 16
    static let barCornerRadius: CGFloat = 5
    static let barMinimumVisibleWidth: CGFloat = 30
}

struct InsightsSummaryPresentation {
    let formattedTotalCount: String
    let usageUnit: String
    let periodText: String
    let narrativeText: String

    init(totalCount: Int, period: InsightsPeriod, locale: Locale = .autoupdatingCurrent) {
        formattedTotalCount = totalCount.formatted(
            .number
                .locale(locale)
                .grouping(.automatic)
        )
        usageUnit = totalCount == 1 ? "time" : "times"
        periodText = period.summaryRangeText
        narrativeText = "You've used shortcuts \(formattedTotalCount) \(usageUnit) \(periodText)"
    }

    var attributedNarrativeText: AttributedString {
        var text = AttributedString(narrativeText)
        text.font = .system(size: 15, weight: .medium, design: .rounded)

        if let range = text.range(of: formattedTotalCount) {
            text[range].font = .system(size: 15, weight: .bold, design: .rounded)
        }

        return text
    }
}

struct InsightsTabView: View {
    @Bindable var viewModel: InsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Picker("", selection: $viewModel.period) {
                    ForEach(InsightsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .frame(width: 116)
                .labelsHidden()
                .pickerStyle(.segmented)

                Spacer(minLength: 0)
            }

            summaryBanner

            if viewModel.ranking.isEmpty {
                Text(InsightsTabCopy.emptyRankingText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(InsightsTabCopy.rankingSectionTitle)
                        .font(.system(size: 17, weight: .semibold))

                    let maxCount = viewModel.ranking.first?.count ?? 1

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.ranking.enumerated()), id: \.element.id) { index, item in
                                rankingRow(
                                    item,
                                    maxCount: maxCount,
                                    showsDivider: index < viewModel.ranking.count - 1
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(InsightsVisualStyle.listBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { viewModel.scheduleRefresh() }
    }

    private var summaryBanner: some View {
        let summary = InsightsSummaryPresentation(totalCount: viewModel.totalCount, period: viewModel.period)

        return HStack(spacing: 0) {
            Text(summary.attributedNarrativeText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(InsightsVisualStyle.bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func rankingRow(_ item: RankedShortcut, maxCount: Int, showsDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppIconView(bundleIdentifier: item.bundleIdentifier, size: 28)

                Text(item.appName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 104, alignment: .leading)

                rankingBar(progress: progressValue(for: item.count, maxCount: maxCount))
                    .frame(maxWidth: .infinity)

                Text(item.count.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 54, alignment: .trailing)
            }
            .padding(.vertical, 16)

            if showsDivider {
                Divider()
                    .overlay(InsightsVisualStyle.separator)
                    .padding(.leading, 42)
            }
        }
    }

    private func rankingBar(progress: CGFloat) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 0) {
                RoundedRectangle(cornerRadius: InsightsVisualStyle.barCornerRadius, style: .continuous)
                    .fill(InsightsVisualStyle.accent)
                    .frame(width: filledBarWidth(in: geometry.size.width, progress: progress, height: geometry.size.height))

                Spacer(minLength: 0)
            }
        }
        .frame(height: InsightsVisualStyle.barHeight)
    }

    private func progressValue(for count: Int, maxCount: Int) -> CGFloat {
        guard maxCount > 0 else { return 0 }
        return min(max(CGFloat(count) / CGFloat(maxCount), 0), 1)
    }

    private func filledBarWidth(in totalWidth: CGFloat, progress: CGFloat, height: CGFloat) -> CGFloat {
        guard progress > 0 else { return 0 }
        return max(totalWidth * progress, max(InsightsVisualStyle.barMinimumVisibleWidth, height * 1.8))
    }
}

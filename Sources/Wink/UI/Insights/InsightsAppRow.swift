import SwiftUI

struct InsightsAppRow: View {
    @Environment(\.winkPalette) private var palette

    let item: InsightsAppRowModel
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppIconView(bundleIdentifier: item.bundleIdentifier, size: 30)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.appName)
                            .font(WinkType.bodyMedium)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)

                        InsightsChangeBadge(change: item.delta)
                    }

                    WinkSparkline(
                        points: item.sparklinePoints,
                        stroke: palette.accent,
                        fill: palette.accent.opacity(0.1)
                    )
                    .frame(width: 108, height: 28)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(item.count.formatted(.number.grouping(.automatic)))
                        .font(WinkType.monoBadge)
                        .foregroundStyle(palette.textPrimary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.accentBgSoft)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.accent)
                                .frame(width: max(geometry.size.width * item.progress, 24))
                        }
                    }
                    .frame(width: 96, height: 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showsDivider {
                Divider()
                    .overlay(palette.hairline)
                    .padding(.leading, 56)
            }
        }
    }
}

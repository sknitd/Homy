import Charts
import SwiftUI

/// Donut chart of library size by category (toolbar pie-chart button).
struct StorageChartView: View {
    @Environment(LibraryStore.self) private var library

    private struct Slice: Identifiable {
        let category: FileCategory
        let size: Int64
        var id: FileCategory { category }
    }

    var body: some View {
        let slices = FileCategory.allCases
            .map { Slice(category: $0, size: library.stats[$0]?.size ?? 0) }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }

        VStack(alignment: .leading, spacing: 16) {
            Text("Library Breakdown")
                .font(Theme.title(18))
            if slices.isEmpty {
                Text("Nothing scanned yet.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 280, height: 200)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Size", Double(slice.size)),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.category.tint)
                }
                .chartLegend(.hidden)
                .frame(width: 220, height: 220)
                .overlay {
                    VStack(spacing: 2) {
                        Text(Format.gigabytes(library.totalSize))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("total")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    ForEach(slices) { slice in
                        HStack(spacing: 8) {
                            Circle().fill(slice.category.tint).frame(width: 9, height: 9)
                            Text(slice.category.title)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            Spacer()
                            Text(Format.bytes(slice.size))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}

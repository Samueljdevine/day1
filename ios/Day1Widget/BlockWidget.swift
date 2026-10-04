import SwiftUI
import WidgetKit
import RoutineCore

struct BlockEntry: TimelineEntry {
    let date: Date
    let block: Block
    let next: Block
    let top3: [RoutineStore.Top3Item]
}

struct BlockProvider: TimelineProvider {
    private let store = RoutineStore.shared

    func placeholder(in context: Context) -> BlockEntry {
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BlockEntry) -> Void) {
        completion(entry(at: Date()))
    }

    /// One entry now plus one at every block boundary in the next 24 hours, so
    /// the widget flips at exactly 10:30:00 with no polling. The whole timeline
    /// is rebuilt after local midnight so the new day's top 3 apply.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BlockEntry>) -> Void) {
        let now = Date()
        var entries = [entry(at: now)]
        for boundary in Routine.boundaries(from: now, hours: 24) {
            entries.append(entry(at: boundary))
        }
        let nextMidnight = Routine.addDays(now, 1)
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    private func entry(at date: Date) -> BlockEntry {
        let blocks = Routine.blocks(for: date)
        let current = Routine.currentBlock(in: blocks, at: date)
        let next = Routine.nextBlock(in: blocks, at: date)
        return BlockEntry(date: date, block: current, next: next, top3: store.top3(for: Routine.dateKey(date)))
    }
}

struct BlockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    let entry: BlockEntry

    private var block: Block { entry.block }
    private var untilText: String { "until \(block.endLabel)" }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(block.displayTitle) · \(untilText)")
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(block.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(block.end, style: .timer)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(maxWidth: 88, alignment: .leading)
                    Text(untilText)
                        .font(.caption)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                if !block.isSleep {
                    Text("Next · \(entry.next.startLabel) \(entry.next.isSleep ? "Sleep" : entry.next.title)")
                        .font(.caption2)
                        .lineLimit(1)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                mainColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                    .overlay(block.text(for: scheme).opacity(0.3))
                sideColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(block.text(for: scheme))
            .containerBackground(block.fill(for: scheme), for: .widget)
        default:
            mainColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .foregroundStyle(block.text(for: scheme))
                .containerBackground(block.fill(for: scheme), for: .widget)
        }
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !block.isSleep {
                Text(String(format: "%02d", block.number))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .opacity(0.8)
            }
            Text(block.title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(block.end, style: .timer)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(untilText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .opacity(0.9)
        }
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next · \(entry.next.startLabel)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .opacity(0.8)
            Text(entry.next.isSleep ? "Sleep" : entry.next.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("TOP 3")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .opacity(0.7)
            ForEach(0..<3, id: \.self) { i in
                let item = i < entry.top3.count ? entry.top3[i] : RoutineStore.Top3Item()
                HStack(spacing: 5) {
                    Image(systemName: item.done ? "checkmark.square.fill" : "square")
                        .font(.caption)
                    Text(item.text.isEmpty ? "–" : item.text)
                        .font(.caption)
                        .lineLimit(1)
                        .strikethrough(item.done)
                }
                .opacity(item.done ? 0.6 : 1)
            }
        }
    }
}

struct BlockWidget: Widget {
    let kind = "Day1Block"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BlockProvider()) { entry in
            BlockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Day 1")
        .description("The current block of your routine and how long is left.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("Small", as: .systemSmall) {
    BlockWidget()
} timeline: {
    let now = Date()
    let blocks = Routine.blocks(for: now)
    BlockEntry(
        date: now,
        block: Routine.currentBlock(in: blocks, at: now),
        next: Routine.nextBlock(in: blocks, at: now),
        top3: [.init(text: "Site plan", done: true), .init(text: "Costings"), .init()]
    )
}

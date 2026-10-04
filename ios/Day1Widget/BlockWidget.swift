import SwiftUI
import WidgetKit
import RoutineCore

struct BlockEntry: TimelineEntry {
    let date: Date
    let block: Block
    let next: Block
    let top3: [RoutineStore.Top3Item]
    /// All of the entry day's blocks, for the day strip.
    let blocks: [Block]
    /// Share of the program completed, or nil outside it.
    let programFraction: Double?
    /// The moment the content describes. Same as `date` except in the simulator preview hook.
    let contentDate: Date
    /// Target for the live countdown. Same as `block.end` except in the simulator preview hook.
    let timerEnd: Date
}

/// Today at a glance: every block as a segment sized by duration. The current
/// block is full height, earlier blocks are dimmed. Timeline entries fall on
/// block boundaries, so this is always exact without a moving marker.
struct WidgetDayStrip: View {
    let blocks: [Block]
    let current: Block
    let date: Date
    let scheme: ColorScheme
    var monochrome = false

    private let gap: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let total = blocks.reduce(0.0) { $0 + $1.duration }
            let usable = max(0, geo.size.width - gap * CGFloat(max(0, blocks.count - 1)))
            HStack(alignment: .center, spacing: gap) {
                ForEach(blocks) { block in
                    let isCurrent = !current.isSleep && block.number == current.number
                    let isPast = !isCurrent && date >= block.end
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(monochrome ? Color.primary : block.category.text(for: scheme))
                        .opacity(isCurrent ? 1 : (isPast ? 0.25 : (monochrome ? 0.55 : 0.8)))
                        .frame(
                            width: total > 0 ? usable * block.duration / total : 0,
                            height: isCurrent ? geo.size.height : geo.size.height * 0.6
                        )
                }
            }
            .frame(height: geo.size.height)
        }
        .opacity(current.isSleep ? 0.5 : 1)
        .accessibilityHidden(true)
    }
}

/// Thin bar: how far through the 100 days.
struct WidgetProgramBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.22))
                Capsule().fill(color).frame(width: max(3, geo.size.width * fraction))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

struct BlockProvider: TimelineProvider {
    private let store = RoutineStore.shared

    func placeholder(in context: Context) -> BlockEntry {
        entry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BlockEntry) -> Void) {
        if let fake = Self.simulatorFakeNow() {
            completion(entry(at: fake, shownAt: Date()))
        } else {
            completion(entry(at: Date()))
        }
    }

    /// One entry now plus one at every block boundary in the next 24 hours, so
    /// the widget flips at exactly 10:30:00 with no polling. The whole timeline
    /// is rebuilt after local midnight so the new day's top 3 apply.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BlockEntry>) -> Void) {
        let now = Date()
        if let fake = Self.simulatorFakeNow() {
            completion(Timeline(entries: [entry(at: fake, shownAt: now)], policy: .after(now.addingTimeInterval(60))))
            return
        }
        var entries = [entry(at: now)]
        for boundary in Routine.boundaries(from: now, hours: 24) {
            entries.append(entry(at: boundary))
        }
        let nextMidnight = Routine.addDays(now, 1)
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    /// Debug builds in the simulator only: put a local time such as
    /// `2026-10-05T11:10:00` in /tmp/day1-fake-now.txt on the Mac to preview the
    /// widget at that moment. Delete the file to return to the real clock.
    private static func simulatorFakeNow() -> Date? {
        #if DEBUG && targetEnvironment(simulator)
        guard let raw = try? String(contentsOfFile: "/tmp/day1-fake-now.txt", encoding: .utf8) else { return nil }
        let f = DateFormatter()
        f.calendar = Routine.calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        #else
        return nil
        #endif
    }

    private func entry(at date: Date, shownAt: Date? = nil) -> BlockEntry {
        let blocks = Routine.blocks(for: date)
        let current = Routine.currentBlock(in: blocks, at: date)
        let next = Routine.nextBlock(in: blocks, at: date)
        return BlockEntry(
            date: shownAt ?? date,
            block: current,
            next: next,
            top3: store.top3(for: Routine.dateKey(date)),
            blocks: blocks,
            programFraction: Routine.programFraction(date),
            contentDate: date,
            timerEnd: shownAt.map { $0.addingTimeInterval(current.remaining(at: date)) } ?? current.end
        )
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
                    Text(entry.timerEnd, style: .timer)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(maxWidth: 88, alignment: .leading)
                    Text(untilText)
                        .font(.caption)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                WidgetDayStrip(blocks: entry.blocks, current: block, date: entry.contentDate, scheme: scheme, monochrome: true)
                    .frame(height: 6)
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .systemMedium:
            VStack(spacing: 8) {
                programBar
                HStack(alignment: .top, spacing: 14) {
                    mainColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    Divider()
                        .overlay(block.text(for: scheme).opacity(0.3))
                    sideColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                strip
            }
            .foregroundStyle(block.text(for: scheme))
            .containerBackground(block.fill(for: scheme), for: .widget)
        default:
            VStack(spacing: 7) {
                programBar
                mainColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                strip
            }
                .foregroundStyle(block.text(for: scheme))
                .containerBackground(block.fill(for: scheme), for: .widget)
        }
    }

    @ViewBuilder
    private var programBar: some View {
        if let fraction = entry.programFraction {
            WidgetProgramBar(fraction: fraction, color: block.text(for: scheme))
        }
    }

    private var strip: some View {
        WidgetDayStrip(blocks: entry.blocks, current: block, date: entry.contentDate, scheme: scheme)
            .frame(height: 9)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.displayTitle)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            Text(entry.timerEnd, style: .timer)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
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
        VStack(alignment: .leading, spacing: 3) {
            Text("Next · \(entry.next.startLabel) \(entry.next.isSleep ? "Sleep" : entry.next.title)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(0.85)
            Spacer(minLength: 0)
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
        top3: [.init(text: "Site plan", done: true), .init(text: "Costings"), .init()],
        blocks: blocks,
        programFraction: 0.37,
        contentDate: now,
        timerEnd: Routine.currentBlock(in: blocks, at: now).end
    )
}

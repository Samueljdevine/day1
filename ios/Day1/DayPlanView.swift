import SwiftUI
import RoutineCore

/// Full-screen plan for today: every block on a timeline, sized by its
/// length, with the current block marked and category totals at the bottom.
struct DayPlanView: View {
    let done: Set<Int>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let pointsPerMinute: CGFloat = 1.05
    private let minHeight: CGFloat = 46

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1)) { context in
            let now = DebugClock.now(context.date)
            let blocks = Routine.blocks(for: now)

            VStack(spacing: 0) {
                head(now: now)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(blocks) { block in
                                row(block, now: now).id(block.number)
                            }
                            sleepRow
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        if let current = blocks.first(where: { $0.start <= now && now < $0.end }) {
                            proxy.scrollTo(current.number, anchor: .center)
                        }
                    }
                }
                Divider()
                totals(blocks)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func head(now: Date) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's plan")
                    .font(.title2.weight(.heavy))
                Text("\(Routine.headerDate(now)) · \(Routine.programDay(now))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close schedule")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func row(_ block: Block, now: Date) -> some View {
        let minutes = block.duration / 60
        let isCurrent = block.start <= now && now < block.end
        let isPast = now >= block.end
        let isDone = done.contains(block.number)
        let fg = block.category.text(for: scheme)
        let bg = block.category.fill(for: scheme)
        let meta = minutes <= 30
            ? "to \(block.endLabel) · \(Routine.formatDuration(block.duration))"
            : "\(block.startLabel)–\(block.endLabel) · \(Routine.formatDuration(block.duration))"
        let badge = "Now · \(Routine.formatRemaining(block.remaining(at: now))) left"

        return HStack(alignment: .top, spacing: 8) {
            Text(block.startLabel)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 8)

            Group {
                if minutes <= 30 {
                    HStack(spacing: 10) {
                        Text(block.displayTitle)
                            .font(.callout.weight(.bold))
                            .strikethrough(isDone)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        if isCurrent {
                            badgeView(badge, fg: fg, bg: bg)
                        } else {
                            Text(meta).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.displayTitle)
                            .font(.callout.weight(.bold))
                            .strikethrough(isDone)
                        Text(meta).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                        if minutes >= 45 {
                            Text(block.note).font(.footnote).opacity(0.85).padding(.top, 2)
                        }
                        if isCurrent {
                            badgeView(badge, fg: fg, bg: bg).padding(.top, 5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: max(minHeight, CGFloat(minutes) * pointsPerMinute), alignment: .topLeading)
            .foregroundStyle(fg)
            .background(bg)
            // Elapsed part of the current block, as a bar down the card's left edge.
            .overlay(alignment: .topLeading) {
                if isCurrent {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(fg)
                            .frame(width: 5, height: geo.size.height * block.progress(at: now))
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(fg, lineWidth: 2.5)
                }
            }
            .opacity(isPast ? 0.45 : 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func badgeView(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(bg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(fg, in: Capsule())
    }

    private var sleepRow: some View {
        let out = Routine.parseHM(Schedule.lightsOut)
        let wake = Routine.parseHM(Schedule.wake)
        let minutes = 24 * 60 - (out.hour * 60 + out.minute) + wake.hour * 60 + wake.minute
        return HStack(alignment: .top, spacing: 8) {
            Text(Schedule.lightsOut)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 8)
            HStack {
                Text("Sleep").font(.callout.weight(.bold))
                Spacer()
                Text("\(Schedule.lightsOut)–\(Schedule.wake) · \(Routine.formatDuration(TimeInterval(minutes * 60)))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
        }
    }

    private func totals(_ blocks: [Block]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(Category.allCases, id: \.self) { category in
                let seconds = blocks.filter { $0.category == category }.reduce(0.0) { $0 + $1.duration }
                if seconds > 0 {
                    HStack(spacing: 6) {
                        Text(category.style.label).fontWeight(.semibold)
                        Text(Routine.formatDuration(seconds)).fontWeight(.heavy).monospacedDigit()
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(category.text(for: scheme))
                    .background(category.fill(for: scheme), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

/// Wraps children onto new lines, left to right.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width.isFinite ? width : maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

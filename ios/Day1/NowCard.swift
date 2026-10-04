import SwiftUI
import RoutineCore

/// The dominant card: block title, live countdown, "until HH:MM", progress bar, note.
/// `compact` collapses it to one line while a text field is being edited.
struct NowCard: View {
    let block: Block
    let isPreview: Bool
    let compact: Bool

    @Environment(\.colorScheme) private var scheme

    private static let amber = Color(hex: "#F59E0B")

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1)) { context in
            let now = DebugClock.now(context.date)
            let remaining = isPreview ? block.duration : block.remaining(at: now)
            let progress = isPreview ? (now >= block.end ? 1.0 : 0.0) : block.progress(at: now)
            let urgent = !isPreview && !block.isSleep && remaining > 0 && remaining < 5 * 60
            let pulseOn = urgent && Int(now.timeIntervalSinceReferenceDate) % 2 == 0

            Group {
                if compact {
                    compactBody(remaining: remaining)
                } else {
                    fullBody(remaining: remaining, progress: progress, urgent: urgent, pulseOn: pulseOn)
                }
            }
            .foregroundStyle(block.text(for: scheme))
            .background(block.fill(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous))
            .animation(.easeInOut(duration: 0.25), value: compact)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(block.displayTitle), \(Routine.formatRemaining(remaining)) until \(block.endLabel)")
        }
    }

    private func fullBody(remaining: TimeInterval, progress: Double, urgent: Bool, pulseOn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(block.isSleep ? "Sleep" : block.category.style.label)
                Spacer(minLength: 8)
                Text("\(block.startLabel)–\(block.endLabel)")
                    .monospacedDigit()
            }
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .tracking(1)
            .opacity(0.75)

            HStack(alignment: .firstTextBaseline) {
                Text(block.displayTitle)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if isPreview {
                    Text("PREVIEW")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(lineWidth: 1.5))
                }
            }

            Text(Routine.formatRemaining(remaining))
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.vertical, 2)
                .scaleEffect(pulseOn ? 0.985 : 1)
                .opacity(pulseOn ? 0.72 : 1)
                .animation(.easeInOut(duration: 0.5), value: pulseOn)

            Text(isPreview ? "\(block.startLabel) – \(block.endLabel)" : "until \(block.endLabel)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .opacity(0.9)

            Text(block.note)
                .font(.footnote)
                .lineLimit(3)
                .opacity(0.85)
                .padding(.top, 2)
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 22, trailing: 18))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.gray.opacity(0.25))
                    Rectangle()
                        .fill(urgent ? Self.amber : block.text(for: scheme))
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.9), value: progress)
                }
            }
            .frame(height: 6)
        }
    }

    private func compactBody(remaining: TimeInterval) -> some View {
        HStack(spacing: 12) {
            Text(block.displayTitle)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(Routine.formatRemaining(remaining))
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .monospacedDigit()
            Text("until \(block.endLabel)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .opacity(0.9)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

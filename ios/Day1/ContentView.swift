import SwiftUI
import RoutineCore

/// Mirrors the web app's single screen. The header and Now card stay pinned;
/// everything below scrolls, which also lets the keyboard push text fields
/// into view. The layout re-evaluates every minute (block boundaries are on
/// whole minutes) and the countdown inside the card ticks every second.
struct ContentView: View {
    var model: DayModel

    @Environment(\.colorScheme) private var scheme
    @FocusState private var focus: EditField?
    @State private var confirmReset = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let blocks = Routine.blocks(for: now)
            let live = Routine.currentBlock(in: blocks, at: now)
            let next = Routine.nextBlock(in: blocks, at: now)
            let shown = model.preview ?? live
            let isPreview = model.preview != nil && model.preview != live
            let editing = focus != nil

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            body(now: now, blocks: blocks, live: live, next: next)
                                .opacity(live.isSleep ? 0.4 : 1)
                        } header: {
                            VStack(spacing: 0) {
                                header(now: now)
                                    .opacity(live.isSleep ? 0.4 : 1)
                                NowCard(block: shown, isPreview: isPreview, compact: editing)
                                    .containerRelativeFrame(.vertical, alignment: .top) { height, _ in
                                        editing ? 52 : max(240, height * 0.40)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 8)
                            }
                            .background(background(sleep: live.isSleep).ignoresSafeArea(edges: .top))
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: live.id) { _, _ in
                    if model.preview == nil {
                        withAnimation { proxy.scrollTo("block-\(live.number)", anchor: .center) }
                    }
                }
            }
            .background(background(sleep: live.isSleep))
            .onAppear { model.ensureDate(now) }
            .onChange(of: now) { _, newValue in model.ensureDate(newValue) }
        }
        .confirmationDialog("Clear today's checkboxes?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset today", role: .destructive) { model.resetToday() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func background(sleep: Bool) -> Color {
        sleep ? Color.black : Color(uiColor: .systemBackground)
    }

    private func header(now: Date) -> some View {
        HStack {
            Text(Routine.headerDate(now))
            Spacer()
            Text(Routine.programDay(now))
        }
        .font(.title3.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func body(now: Date, blocks: [Block], live: Block, next: Block) -> some View {
        HStack(spacing: 0) {
            Text("Next · ")
                .foregroundStyle(.secondary)
            Text("\(next.startLabel) \(next.isSleep ? "Sleep" : next.title)")
                .monospacedDigit()
            Spacer()
        }
        .font(.body.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)

        Top3Section(
            title: "Top 3 for today",
            fieldKey: "today",
            items: model.top3Today,
            onChange: model.setTop3Today,
            focus: $focus
        )

        if live.number == Schedule.tomorrowTop3Block {
            Top3Section(
                title: "Tomorrow's top 3",
                fieldKey: "tomorrow",
                items: model.top3Tomorrow,
                onChange: model.setTop3Tomorrow,
                focus: $focus
            )
        }

        LearningSection(
            showInput: live.number == Schedule.learningLogBlock,
            text: model.learn,
            streak: model.streak,
            onChange: model.setLearn,
            focus: $focus
        )

        Divider().padding(.top, 4)

        ForEach(blocks) { block in
            DayRow(
                block: block,
                isCurrent: !live.isSleep && block.number == live.number,
                isPast: now >= block.end && block.number != live.number,
                isDone: model.done.contains(block.number),
                onToggle: { model.setDone(block.number, $0) },
                onTap: { model.startPreview(block) }
            )
            .id("block-\(block.number)")
        }

        Divider().padding(.top, 4)

        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { model.keepAwake },
                set: { value in
                    model.keepAwake = value
                    UIApplication.shared.isIdleTimerDisabled = value
                }
            )) {
                Text("Keep screen awake")
            }
            .font(.footnote)
            .toggleStyle(.switch)
            .fixedSize()

            Spacer()

            Button("Reset today") { confirmReset = true }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.bottom, 12)
    }
}

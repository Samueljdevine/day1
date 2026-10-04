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
    @State private var showPlan = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = DebugClock.now(context.date)
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
                                        editing ? 52 : max(250, height * 0.40)
                                    }
                                    .padding(.horizontal, 12)
                                DayStrip(
                                    blocks: blocks,
                                    live: live,
                                    now: now,
                                    previewed: model.preview,
                                    onTap: { model.startPreview($0) }
                                )
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                                .padding(.bottom, 8)
                                .opacity(live.isSleep ? 0.4 : 1)
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
            // Sleep is always near-black, so text and fields must use dark styling even in light mode.
            .preferredColorScheme(live.isSleep ? .dark : nil)
            .onAppear { model.ensureDate(now) }
            .onChange(of: now) { _, newValue in model.ensureDate(newValue) }
        }
        // The widgets' plan button deep-links here with day1://plan.
        .onOpenURL { url in
            if url.scheme == "day1", url.host == "plan" { showPlan = true }
        }
        .fullScreenCover(isPresented: $showPlan) {
            DayPlanView(done: model.done)
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
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(Routine.headerDate(now))
                Button {
                    showPlan = true
                } label: {
                    Image(systemName: "calendar.day.timeline.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show today's schedule")
                Spacer()
                Text(Routine.programDay(now))
            }
            .font(.title3.weight(.semibold))
            if let fraction = Routine.programFraction(now) {
                ProgramBar(fraction: fraction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

        DayHeader(done: blocks.filter { model.done.contains($0.number) }.count, total: blocks.count)

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

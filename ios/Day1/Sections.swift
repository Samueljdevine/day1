import SwiftUI
import RoutineCore

enum EditField: Hashable {
    case top3(String, Int)
    case learn
}

/// A tappable square checkbox.
struct CheckBox: View {
    @Binding var isOn: Bool
    var label: String = ""

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title2)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? "Done" : label)
        .accessibilityValue(isOn ? "checked" : "unchecked")
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.4)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Top3Section: View {
    let title: String
    let fieldKey: String
    let items: [RoutineStore.Top3Item]
    let onChange: ([RoutineStore.Top3Item]) -> Void
    var focus: FocusState<EditField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(text: title)
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    TextField("Top \(i + 1)", text: binding(i))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .autocorrectionDisabled(false)
                        .focused(focus, equals: .top3(fieldKey, i))
                        .strikethrough(items[i].done)
                        .foregroundStyle(items[i].done ? Color.secondary : Color.primary)
                        .onSubmit { focus.wrappedValue = nil }
                    CheckBox(isOn: doneBinding(i), label: "Item \(i + 1) done")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func binding(_ i: Int) -> Binding<String> {
        Binding(
            get: { items[i].text },
            set: { newValue in
                var copy = items
                copy[i].text = newValue
                onChange(copy)
            }
        )
    }

    private func doneBinding(_ i: Int) -> Binding<Bool> {
        Binding(
            get: { items[i].done },
            set: { newValue in
                var copy = items
                copy[i].done = newValue
                onChange(copy)
            }
        )
    }
}

struct LearningSection: View {
    let showInput: Bool
    let text: String
    let streak: Int
    let onChange: (String) -> Void
    var focus: FocusState<EditField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showInput {
                Text("What did you learn?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("One line", text: Binding(get: { text }, set: onChange))
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused(focus, equals: .learn)
                    .onSubmit { focus.wrappedValue = nil }
            }
            Text("Learning streak: \(streak) \(streak == 1 ? "day" : "days")")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct DayRow: View {
    let block: Block
    let isCurrent: Bool
    let isPast: Bool
    let isDone: Bool
    let onToggle: (Bool) -> Void
    let onTap: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            CheckBox(isOn: Binding(get: { isDone }, set: onToggle), label: "Block \(block.number) done")
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(block.startLabel)–\(block.endLabel)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(block.displayTitle)
                        .font(.body.weight(.semibold))
                        .strikethrough(isDone)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCurrent ? Color(uiColor: .secondarySystemBackground) : Color.clear)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(block.category.text(for: scheme))
                .frame(width: 4)
                .padding(.vertical, 4)
        }
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(block.category.text(for: scheme), lineWidth: 2)
            }
        }
        .opacity(isPast ? 0.45 : 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

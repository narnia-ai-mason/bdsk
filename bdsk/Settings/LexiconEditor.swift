import SwiftUI

struct LexiconEditor: View {
    @Bindable var store: LexiconStore
    @State private var spoken = ""
    @State private var written = ""
    @State private var editing: LexiconEntry?
    @State private var toast = ""

    private var canSubmit: Bool {
        !written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            CeramicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("사전은 하나예요")
                        .font(BdskTheme.titleFont())
                        .foregroundStyle(BdskTheme.pearl)
                    Text("엔진이 한글로 적는 고유명사든, 짧게 말하고 싶은 말이든 같은 칸에 넣으면 됩니다. 말한 형태와 넣을 글자만 적으세요. 조사는 따로 적지 않아도 됩니다. 스위프트 데이터만 있으면 스위프트 데이터로, 스위프트 데이터에서도 같이 바뀝니다.")
                        .font(BdskTheme.bodyFont())
                        .foregroundStyle(BdskTheme.pearlMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            CeramicCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 12) {
                        BdskField(
                            title: "이렇게 말하면",
                            placeholder: "스위프트 데이터, 스위프트데이터",
                            text: $spoken
                        )
                        Text("→")
                            .font(BdskTheme.titleFont())
                            .foregroundStyle(BdskTheme.lavender)
                            .padding(.bottom, 12)
                        BdskField(
                            title: "이렇게 넣어요",
                            placeholder: "SwiftData",
                            text: $written
                        )
                    }
                    HStack(spacing: 8) {
                        BdskPrimaryButton(
                            title: editing == nil ? "추가" : "저장",
                            enabled: canSubmit,
                            action: submit
                        )
                        if editing != nil {
                            BdskGhostButton(title: "취소", action: clearForm)
                        }
                        if !toast.isEmpty {
                            Text(toast)
                                .font(BdskTheme.captionFont())
                                .foregroundStyle(BdskTheme.lavender)
                        }
                    }
                }
            }

            if store.entries.isEmpty {
                CeramicCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            pebble(BdskTheme.lavender)
                            pebble(BdskTheme.pearl)
                            pebble(BdskTheme.pink)
                        }
                        .padding(.bottom, 8)
                        Text("위에 말한 형태와 넣을 글자를 적고 추가를 누르면 됩니다.")
                            .font(BdskTheme.bodyFont())
                            .foregroundStyle(BdskTheme.pearlMuted)
                    }
                }
            } else {
                CeramicCard(padding: 16) {
                    VStack(spacing: 8) {
                        ForEach(store.entries) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: LexiconEntry) -> some View {
        let isEditing = editing?.id == entry.id
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.aliases.joined(separator: ", "))
                    .font(BdskTheme.bodyFont())
                    .foregroundStyle(BdskTheme.pearl)
                Text(entry.replacement)
                    .font(BdskTheme.labelFont())
                    .foregroundStyle(BdskTheme.lavender)
            }
            Spacer()
            BdskGhostButton(title: "고치기") {
                beginEdit(entry)
            }
            BdskGhostButton(title: "삭제", role: .destructive) {
                if editing?.id == entry.id {
                    clearForm()
                }
                store.delete(entry)
                showToast("삭제했어요")
            }
        }
        .padding(12)
        .background(isEditing ? BdskTheme.surfaceRaised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: BdskTheme.radiusChip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BdskTheme.radiusChip, style: .continuous)
                .stroke(isEditing ? BdskTheme.lavender : Color.clear, lineWidth: 1.5)
        )
    }

    private func pebble(_ color: Color) -> some View {
        Capsule(style: .continuous)
            .fill(color)
            .frame(width: 22, height: 16)
    }

    private func submit() {
        let aliases = spoken
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let editing {
            store.update(editing, replacement: written, aliases: aliases)
            showToast("저장했어요")
        } else {
            guard store.add(replacement: written, aliases: aliases) != nil else { return }
            showToast("추가했어요")
        }
        clearForm()
    }

    private func beginEdit(_ entry: LexiconEntry) {
        editing = entry
        written = entry.replacement
        spoken = entry.aliases.joined(separator: ", ")
        toast = ""
    }

    private func clearForm() {
        editing = nil
        spoken = ""
        written = ""
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if toast == message {
                toast = ""
            }
        }
    }
}

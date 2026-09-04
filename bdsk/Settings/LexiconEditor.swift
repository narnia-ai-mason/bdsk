import SwiftUI

struct LexiconEditor: View {
    private static let pageSizeChoices = [5, 10, 20, 50]

    @Bindable var store: LexiconStore

    @AppStorage("lexiconPageSize") private var pageSize = 10
    @State private var spoken = ""
    @State private var written = ""
    @State private var search = ""
    @State private var page = 0
    @State private var editing: LexiconEntry?
    @State private var editSpoken = ""
    @State private var editWritten = ""
    @State private var toast = ""
    @FocusState private var spokenFocused: Bool
    @FocusState private var editSpokenFocused: Bool

    private var canSubmitAdd: Bool {
        isFilled(spoken, written)
    }

    private var canSubmitEdit: Bool {
        isFilled(editSpoken, editWritten)
    }

    private var filteredEntries: [LexiconEntry] {
        LexiconStore.matching(store.entries, replacementQuery: search)
    }

    private var pageCount: Int {
        let size = resolvedPageSize
        guard size > 0, !filteredEntries.isEmpty else { return 1 }
        return Int(ceil(Double(filteredEntries.count) / Double(size)))
    }

    private var pagedEntries: [LexiconEntry] {
        let size = resolvedPageSize
        let start = page * size
        guard start < filteredEntries.count else { return [] }
        return Array(filteredEntries[start..<min(start + size, filteredEntries.count)])
    }

    private var resolvedPageSize: Int {
        Self.pageSizeChoices.contains(pageSize) ? pageSize : 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            CeramicCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("사전은 하나예요")
                        .font(BdskTheme.titleFont())
                        .foregroundStyle(BdskTheme.pearl)
                    Text("엔진이 한글로 적는 고유명사든, 짧게 말하고 싶은 말이든 같은 칸에 넣으면 됩니다. 말한 형태와 넣을 글자만 적으세요. 조사와 입니다처럼 자주 붙는 말은 따로 적지 않아도 됩니다. 스위프트 데이터만 있으면 스위프트 데이터로, 스위프트 데이터입니다도 같이 바뀝니다.")
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
                            text: $spoken,
                            focus: $spokenFocused
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
                    BdskPrimaryButton(
                        title: "추가",
                        enabled: canSubmitAdd,
                        action: submitAdd
                    )
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
                listCard
            }
        }
        .onAppear(perform: normalizePageSize)
        .onChange(of: search) { _, _ in
            page = 0
            dropEditIfHidden()
            clampPage()
        }
        .onChange(of: store.entries.count) { _, _ in
            dropEditIfHidden()
            clampPage()
        }
    }

    private var listCard: some View {
        CeramicCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                BdskField(
                    title: "넣을 글자로 찾기",
                    placeholder: "Notion",
                    text: $search
                )
                if filteredEntries.isEmpty {
                    Text("넣을 글자에 맞는 항목이 없어요.")
                        .font(BdskTheme.bodyFont())
                        .foregroundStyle(BdskTheme.pearlMuted)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(pagedEntries) { entry in
                            entryRow(entry)
                        }
                    }
                }
                listFooter
            }
        }
    }

    private var listFooter: some View {
        HStack(spacing: 8) {
            Text("한 페이지에")
                .font(BdskTheme.captionFont())
                .foregroundStyle(BdskTheme.pearlMuted)
            ForEach(Self.pageSizeChoices, id: \.self) { size in
                BdskChoiceChip(title: "\(size)", selected: resolvedPageSize == size) {
                    changePageSize(to: size)
                }
            }
            Spacer()
            if !toast.isEmpty {
                Text(toast)
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.lavender)
            }
            if pageCount > 1 {
                BdskGhostButton(title: "이전", enabled: page > 0) {
                    page -= 1
                }
                Text("\(page + 1) / \(pageCount)")
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
                    .monospacedDigit()
                BdskGhostButton(title: "다음", enabled: page + 1 < pageCount) {
                    page += 1
                }
            }
        }
    }

    private func entryRow(_ entry: LexiconEntry) -> some View {
        let isEditing = editing?.id == entry.id
        return VStack(alignment: .leading, spacing: 12) {
            if isEditing {
                HStack(alignment: .bottom, spacing: 12) {
                    BdskField(
                        title: "이렇게 말하면",
                        placeholder: "스위프트 데이터, 스위프트데이터",
                        text: $editSpoken,
                        focus: $editSpokenFocused
                    )
                    Text("→")
                        .font(BdskTheme.titleFont())
                        .foregroundStyle(BdskTheme.lavender)
                        .padding(.bottom, 12)
                    BdskField(
                        title: "이렇게 넣어요",
                        placeholder: "SwiftData",
                        text: $editWritten
                    )
                }
                HStack(spacing: 8) {
                    BdskPrimaryButton(title: "저장", enabled: canSubmitEdit, action: submitEdit)
                    BdskGhostButton(title: "취소", action: clearEdit)
                    if !toast.isEmpty {
                        Text(toast)
                            .font(BdskTheme.captionFont())
                            .foregroundStyle(BdskTheme.lavender)
                    }
                    Spacer()
                    BdskGhostButton(title: "삭제", role: .destructive) {
                        delete(entry)
                    }
                }
            } else {
                HStack(spacing: 12) {
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
                        delete(entry)
                    }
                }
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

    private func submitAdd() {
        let aliases = splitAliases(spoken)
        guard let outcome = store.add(replacement: written, aliases: aliases) else { return }
        switch outcome {
        case .added(let entry):
            showToast("추가했어요")
            reveal(entry)
        case .merged(let entry):
            showToast("기존 항목에 합쳤어요")
            reveal(entry)
        }
        spoken = ""
        written = ""
    }

    private func submitEdit() {
        guard let editing else { return }
        store.update(editing, replacement: editWritten, aliases: splitAliases(editSpoken))
        showToast("저장했어요")
        clearEdit()
    }

    private func beginEdit(_ entry: LexiconEntry) {
        editing = entry
        editWritten = entry.replacement
        editSpoken = entry.aliases.joined(separator: ", ")
        toast = ""
        Task { @MainActor in
            editSpokenFocused = true
        }
    }

    private func clearEdit() {
        editing = nil
        editSpoken = ""
        editWritten = ""
    }

    private func delete(_ entry: LexiconEntry) {
        if editing?.id == entry.id {
            clearEdit()
        }
        store.delete(entry)
        showToast("삭제했어요")
        clampPage()
    }

    private func reveal(_ entry: LexiconEntry) {
        if let index = filteredEntries.firstIndex(where: { $0.id == entry.id }) {
            page = index / resolvedPageSize
        }
    }

    private func changePageSize(to size: Int) {
        let first = page * resolvedPageSize
        pageSize = size
        page = first / size
        clampPage()
    }

    private func clampPage() {
        let last = max(0, pageCount - 1)
        if page > last {
            page = last
        }
    }

    private func dropEditIfHidden() {
        guard let editing else { return }
        if !filteredEntries.contains(where: { $0.id == editing.id }) {
            clearEdit()
        }
    }

    private func normalizePageSize() {
        if !Self.pageSizeChoices.contains(pageSize) {
            pageSize = 10
        }
        clampPage()
    }

    private func isFilled(_ spokenValue: String, _ writtenValue: String) -> Bool {
        !writtenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !spokenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func splitAliases(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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

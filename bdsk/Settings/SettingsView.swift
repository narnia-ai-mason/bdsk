import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case lexicon
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "일반"
        case .lexicon: return "사전"
        case .permissions: return "권한"
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var pane: SettingsPane = .general
    @State private var micStatus = Permissions.microphoneStatus()
    @State private var speechStatus = Permissions.speechStatus()
    @State private var accessStatus = Permissions.accessibilityStatus()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(BdskTheme.stroke)
                .frame(width: 1)
            detail
        }
        .background(BdskTheme.bgBase)
        .preferredColorScheme(.dark)
        .onAppear(perform: recheck)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            recheck()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("bdsk")
                .font(BdskTheme.titleFont())
                .foregroundStyle(BdskTheme.pearl)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            ForEach(SettingsPane.allCases) { item in
                Button {
                    pane = item
                } label: {
                    Text(item.title)
                        .font(BdskTheme.labelFont())
                        .foregroundStyle(pane == item ? BdskTheme.pearl : BdskTheme.pearlMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(pane == item ? BdskTheme.surfaceRaised : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: BdskTheme.radiusChip, style: .continuous))
                        .overlay(alignment: .leading) {
                            if pane == item {
                                Capsule()
                                    .fill(BdskTheme.lavender)
                                    .frame(width: 3, height: 16)
                                    .padding(.leading, 4)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 176)
        .background(BdskTheme.bgBase)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(pane.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BdskTheme.pearl)
                paneContent
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BdskTheme.bgBase)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch pane {
        case .general:
            GeneralSettingsPane(model: model)
        case .lexicon:
            LexiconEditor(store: model.lexicon)
        case .permissions:
            PermissionsSettingsPane(
                model: model,
                micStatus: $micStatus,
                speechStatus: $speechStatus,
                accessStatus: $accessStatus,
                refresh: refreshPermissions
            )
        }
    }

    private func recheck() {
        refreshPermissions()
        model.refreshHotkeyMonitor()
        Task { await model.refreshSpeechAssets() }
    }

    private func refreshPermissions() {
        micStatus = Permissions.microphoneStatus()
        speechStatus = Permissions.speechStatus()
        accessStatus = Permissions.accessibilityStatus()
    }
}

import AppKit
import SwiftUI

struct PermissionsSettingsPane: View {
    @Bindable var model: AppModel
    @Binding var micStatus: PermissionStatus
    @Binding var speechStatus: PermissionStatus
    @Binding var accessStatus: PermissionStatus
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            CeramicCard {
                VStack(alignment: .leading, spacing: 20) {
                    permissionRow(.microphone, status: micStatus) {
                        Task {
                            await Permissions.requestMicrophone()
                            refresh()
                        }
                    }
                    permissionRow(.speech, status: speechStatus) {
                        Task {
                            await Permissions.requestSpeech()
                            refresh()
                        }
                    }
                    permissionRow(.accessibility, status: accessStatus) {
                        Permissions.requestAccessibility()
                        Permissions.openAccessibilitySettings()
                        refresh()
                    }
                    assetRow
                }
            }

            if accessStatus != .granted {
                CeramicCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("손쉬운 사용이 이 실행 파일에 아직 없을 수 있어요")
                            .font(BdskTheme.titleFont())
                            .foregroundStyle(BdskTheme.pearl)
                        Text("시스템 설정 스위치가 켜져 있어도, 방금 빌드한 복사본에는 안 먹을 수 있습니다. 목록에서 bdsk를 끈 뒤 앱을 완전히 종료하고 다시 실행한 다음, 새로 나타난 항목만 켜세요. 켠 뒤에는 한 번 더 종료 후 실행하세요.")
                            .font(BdskTheme.bodyFont())
                            .foregroundStyle(BdskTheme.pearlMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(model.runningAppPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(BdskTheme.pearlMuted)
                            .textSelection(.enabled)
                        BdskGhostButton(title: "경로 복사") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.runningAppPath, forType: .string)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var assetRow: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("한국어 엔진")
                    .font(BdskTheme.labelFont())
                    .foregroundStyle(BdskTheme.pearl)
                Text("macOS가 받아쓰기에 쓰는 자산입니다. 없으면 받습니다.")
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
                Text(model.speechAssetPhase.label)
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(model.speechAssetPhase == .ready ? BdskTheme.lavender : BdskTheme.pinkDeep)
                if model.speechAssetPhase == .downloading {
                    ProgressView(value: model.speechAssetProgress)
                        .tint(BdskTheme.lavender)
                }
            }
            Spacer()
            if model.speechAssetPhase == .available || model.speechAssetPhase == .failed {
                BdskPrimaryButton(title: model.speechAssetPhase == .failed ? "다시 받기" : "받기") {
                    Task { await model.installSpeechAssets() }
                }
            }
        }
    }

    private func permissionRow(
        _ kind: PermissionKind,
        status: PermissionStatus,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(BdskTheme.labelFont())
                    .foregroundStyle(BdskTheme.pearl)
                Text(kind.summary)
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
                Text(status.label)
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(status == .granted ? BdskTheme.lavender : BdskTheme.pinkDeep)
            }
            Spacer()
            if status != .granted {
                BdskPrimaryButton(title: "허용") { action() }
            }
        }
    }
}

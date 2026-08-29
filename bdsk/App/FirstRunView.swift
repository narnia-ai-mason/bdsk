import SwiftUI

struct FirstRunView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var micStatus = Permissions.microphoneStatus()
    @State private var speechStatus = Permissions.speechStatus()
    @State private var accessStatus = Permissions.accessibilityStatus()
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("받아쓰기를 쓸 준비를 합니다")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BdskTheme.pearl)
                Text("마이크, 손쉬운 사용, 그리고 이 맥 안의 한국어 엔진이 필요합니다. 허용과 받기는 기기를 떠나지 않습니다.")
                    .font(BdskTheme.bodyFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CeramicCard {
                VStack(alignment: .leading, spacing: 18) {
                    statusRow(title: "마이크", detail: "말하는 소리를 듣습니다.", status: micStatus.label)
                    statusRow(title: "음성 인식", detail: "기기 안에서 말을 글자로 바꿉니다.", status: speechStatus.label)
                    statusRow(title: "손쉬운 사용", detail: "핫키와 커서에 글 넣기에 필요합니다.", status: accessStatus.label)
                    statusRow(title: "한국어 엔진", detail: "macOS가 받아쓰기에 쓰는 자산입니다.", status: model.speechAssetPhase.label)
                }
            }

            if model.speechAssetPhase == .downloading {
                VStack(alignment: .leading, spacing: 8) {
                    Text("한국어 엔진을 받고 있습니다.")
                        .font(BdskTheme.captionFont())
                        .foregroundStyle(BdskTheme.pearlMuted)
                    progressBar(model.speechAssetProgress)
                }
            }

            if !model.lastMessage.isEmpty, model.speechAssetPhase == .failed {
                Text(model.lastMessage)
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pinkDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if accessStatus != .granted, Permissions.didPromptAccessibility {
                Text("손쉬운 사용에서 bdsk를 켠 뒤에는 앱을 한 번 종료했다가 다시 열어 주세요.")
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                BdskGhostButton(title: "나중에") {
                    model.dismissSetupForSession()
                    close()
                }
                Spacer()
                BdskPrimaryButton(title: primaryTitle, enabled: !busy && model.speechAssetPhase != .downloading) {
                    Task { await runPrimary() }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BdskTheme.bgBase)
        .preferredColorScheme(.dark)
        .onAppear {
            refreshStatuses()
            Task {
                await model.refreshSpeechAssets()
                if model.isSetupComplete {
                    close()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatuses()
            Task { await model.refreshSpeechAssets() }
            model.refreshHotkeyMonitor()
        }
    }

    private var primaryTitle: String {
        if model.isSetupComplete { return "완료" }
        if model.speechAssetPhase == .failed { return "다시 받기" }
        if needsPermissionPrompt { return "허용하기" }
        if model.speechAssetPhase == .available { return "엔진 받기" }
        if accessStatus != .granted { return "손쉬운 사용 열기" }
        return "계속"
    }

    private var needsPermissionPrompt: Bool {
        micStatus == .notDetermined || speechStatus == .notDetermined || accessStatus == .notDetermined
    }

    private func statusRow(title: String, detail: String, status: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BdskTheme.labelFont())
                    .foregroundStyle(BdskTheme.pearl)
                Text(detail)
                    .font(BdskTheme.captionFont())
                    .foregroundStyle(BdskTheme.pearlMuted)
            }
            Spacer()
            Text(status)
                .font(BdskTheme.captionFont())
                .foregroundStyle(status == "허용됨" || status == "준비됨" ? BdskTheme.lavender : BdskTheme.pinkDeep)
        }
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BdskTheme.surfaceRaised)
                Capsule()
                    .fill(BdskTheme.lavender)
                    .frame(width: max(8, geo.size.width * value))
            }
        }
        .frame(height: 8)
    }

    private func runPrimary() async {
        if model.isSetupComplete {
            close()
            return
        }
        busy = true
        defer {
            busy = false
            refreshStatuses()
        }

        if needsPermissionPrompt {
            if micStatus == .notDetermined {
                await Permissions.requestMicrophone()
                refreshStatuses()
            }
            if speechStatus == .notDetermined {
                await Permissions.requestSpeech()
                refreshStatuses()
            }
            if accessStatus == .notDetermined {
                Permissions.requestAccessibility()
                Permissions.openAccessibilitySettings()
                refreshStatuses()
            }
            await model.refreshSpeechAssets()
            return
        }

        if model.speechAssetPhase == .available || model.speechAssetPhase == .failed {
            await model.installSpeechAssets()
            refreshStatuses()
            return
        }

        if micStatus == .denied {
            Permissions.openMicrophoneSettings()
        }
        if speechStatus == .denied {
            Permissions.openSpeechSettings()
        }
        if accessStatus != .granted {
            Permissions.requestAccessibility()
            Permissions.openAccessibilitySettings()
        }
        await model.refreshSpeechAssets()
        model.refreshHotkeyMonitor()
    }

    private func refreshStatuses() {
        micStatus = Permissions.microphoneStatus()
        speechStatus = Permissions.speechStatus()
        accessStatus = Permissions.accessibilityStatus()
    }

    private func close() {
        dismiss()
        DispatchQueue.main.async {
            AppChrome.resignToMenuBarIfNeeded()
        }
    }
}

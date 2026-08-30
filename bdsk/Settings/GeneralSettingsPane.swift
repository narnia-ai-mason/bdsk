import SwiftUI

struct GeneralSettingsPane: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            CeramicCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("핫키")
                        .font(BdskTheme.titleFont())
                        .foregroundStyle(BdskTheme.pearl)
                    Text("짧게 누르면 토글, 길게 누르면 누르는 동안만 듣습니다. 키를 누르는 순간 녹음이 시작됩니다.")
                        .font(BdskTheme.bodyFont())
                        .foregroundStyle(BdskTheme.pearlMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    HotkeyRecorder(binding: $model.hotkey)
                    if model.debuggerAttached {
                        Text("Xcode 디버거가 붙어 있으면 전역 핫키가 막힙니다. 스킴에서 Debug executable을 끄고 다시 실행하세요.")
                            .font(BdskTheme.captionFont())
                            .foregroundStyle(BdskTheme.pinkDeep)
                    } else if model.hotkeyMonitorFailed {
                        Text("핫키가 꺼져 있습니다. 손쉬운 사용을 이 실행 파일에 적용한 뒤 앱을 완전히 종료하고 다시 실행하세요.")
                            .font(BdskTheme.captionFont())
                            .foregroundStyle(BdskTheme.pinkDeep)
                    }
                }
            }

            CeramicCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("길게 누르기 기준")
                        .font(BdskTheme.titleFont())
                        .foregroundStyle(BdskTheme.pearl)
                    Text("녹음이 준비된 뒤부터 셉니다. 지금은 \(Int(model.holdThresholdMs))ms입니다.")
                        .font(BdskTheme.bodyFont())
                        .foregroundStyle(BdskTheme.pearlMuted)
                    HStack {
                        Text("200ms")
                            .font(BdskTheme.captionFont())
                            .foregroundStyle(BdskTheme.pearlMuted)
                        Slider(value: $model.holdThresholdMs, in: 200...400, step: 50)
                            .tint(BdskTheme.lavender)
                        Text("400ms")
                            .font(BdskTheme.captionFont())
                            .foregroundStyle(BdskTheme.pearlMuted)
                    }
                }
            }

            CeramicCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("듣기 표시")
                        .font(BdskTheme.titleFont())
                        .foregroundStyle(BdskTheme.pearl)
                    Text("받아쓰는 동안 화면 아래에 작게 보여 줍니다. 화면을 녹화하거나 화상 회의에 있으면 메뉴막대 마이크 표시만으로는 구분하기 어렵습니다.")
                        .font(BdskTheme.bodyFont())
                        .foregroundStyle(BdskTheme.pearlMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle(isOn: $model.showsListeningHUD) {
                        Text("화면에 표시")
                            .font(BdskTheme.labelFont())
                            .foregroundStyle(BdskTheme.pearl)
                    }
                    .toggleStyle(.switch)
                    .tint(BdskTheme.lavender)
                }
            }
        }
    }
}

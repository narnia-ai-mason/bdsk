import AppKit
import SwiftUI

@main
struct BdskApp: App {
    @NSApplicationDelegateAdaptor(BdskAppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            MenuBarLabel(isRecording: model.phase.isRecording)
        }
        .menuBarExtraStyle(.menu)

        Window("bdsk 설정", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 720, minHeight: 520)
                .background(SettingsWindowChrome())
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)

        Window("처음 설정", id: "setup") {
            FirstRunView(model: model)
                .frame(minWidth: 440, minHeight: 520)
                .background(SettingsWindowChrome())
        }
        .defaultSize(width: 480, height: 600)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 720, minHeight: 520)
                .background(SettingsWindowChrome())
        }
    }
}

private struct MenuBarLabel: View {
    let isRecording: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle")
            .symbolRenderingMode(.hierarchical)
            .onAppear {
                AppChrome.openSettingsWindow = {
                    openWindow(id: "settings")
                }
                AppChrome.openSetupWindow = {
                    openWindow(id: "setup")
                }
                AppChrome.presentPendingWindows()
            }
    }
}

private struct SettingsWindowChrome: View {
    var body: some View {
        Color.clear
            .onAppear {
                AppChrome.becomeRegularApp()
            }
            .onDisappear {
                DispatchQueue.main.async {
                    AppChrome.resignToMenuBarIfNeeded()
                }
            }
    }
}

struct MenuBarContent: View {
    @Bindable var model: AppModel

    var body: some View {
        Text("bdsk · \(model.phase.menuLabel)")
        if !model.partialText.isEmpty {
            Text(model.partialText)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else if !model.lastMessage.isEmpty {
            Text(model.lastMessage)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        Divider()
        Button(model.phase.isRecording ? "받아쓰기 끝내기" : "받아쓰기 시작") {
            model.toggleFromMenu()
        }
        Button("설정…") {
            AppChrome.showSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("종료") {
            NSApp.terminate(nil)
        }
    }
}

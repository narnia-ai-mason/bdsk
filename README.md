# bdsk

<p align="center">
  <img src="docs/AppIcon-fullbleed-1024.png" width="180" alt="bdsk">
</p>

<p align="center">
  <strong>On-device speech-to-text for macOS.</strong><br>
  Cursor에 한국어로 말하면, 조사와 숫자 읽는 법까지 남습니다.
</p>

<p align="center">
  <a href="https://github.com/narnia-ai-mason/bdsk/releases/latest"><strong>다운로드</strong></a>
  · macOS 14+ · Apple Silicon · MIT
</p>

단어만 말하면 사전이 됩니다. `깃허브에`처럼 조사가 붙으면 표제어를 놓칩니다.

<p align="center">
  <strong>bdsk</strong><br>
  <img src="docs/bdsk.gif" width="900" alt="bdsk"><br>
  <code>GitHub. PR. Notion. GitHub에 PR 올려놨고 자세한 내용은 Notion에 써놨어.</code>
</p>

<p align="center">
  <strong>TypeWhisper</strong><br>
  <img src="docs/typewhisper.gif" width="900" alt="TypeWhisper"><br>
  <code>GitHub.PR.notion. 기터부에 PR 올려놨고 자세한 내용은 노션에 써놨어.</code>
</p>

같은 말, 같은 사전입니다. `깃허브`, `피알`, `노션`을 넣어 두고 `깃허브에 피알 올려놨고 자세한 내용은 노션에 써놨어`라고 말합니다.

혼자 떨어진 `깃허브`, `피알`, `노션`은 양쪽 다 알아듣습니다. 그다음 문장에서 조사가 붙습니다. bdsk는 어간만 보고 `에`를 남깁니다. `GitHub에`, `Notion에`. TypeWhisper는 공백으로 단어를 나눕니다. `깃허브에`는 표제어 `깃허브`가 아니라서 `기터부`로 나갑니다. `노션에`도 `노션`으로 남습니다.

TypeWhisper에서 그 문장까지 고치려면 `깃허브에`, `깃허브에서`, `깃허브로는`처럼 가능한 조사를 모두 붙여 등록해야 합니다. `노션으로`, `커서로`, `스위프트 데이터에서는`마다 한 줄입니다. 엔진이 받을 수 있는 힌트는 최대 100개라서, 표제어가 늘수록 금방 찹니다.

bdsk에서는 그러지 않아도 됩니다. `깃허브`만 넣으면 `깃허브에`, `깃허브에서`, `깃허브로는`이 됩니다. 조사는 코드가 남깁니다. 전사는 이 맥의 받아쓰기 엔진(`ko-KR`)이 하고, 텍스트는 지금 있는 커서에 들어갑니다. macOS 26부터는 SpeechAnalyzer, 그 아래는 시스템 받아쓰기를 씁니다.

한국어 숫자는 읽는 법이 두 가지입니다. 하나 둘 셋으로 말하면 한글로 적고, 일 이 삼으로 말하면 아라비아 숫자로 적는 경우가 많습니다. 엔진은 가끔 이를 구분하지 않습니다. `한 시에서 두 시 사이에 전화할게.`라고 말해도 `1시에서 2시 사이에 전화할게.`로 나올 수 있습니다. `한 분`과 `1분`처럼 의미가 갈리는 자리도 있습니다.

그래서 숫자+수분류사(`시`, `분`, `가지`, `개` …)가 보이면 바로 넣지 않고, 표기를 고르는 HUD를 잠깐 띄웁니다. `1시`와 `한 시`, `2시`와 `두 시` 중 고른 뒤 넣습니다. ↑↓·Tab으로 항목을 옮기고 ←→로 고르며, ESC로 취소하거나 핫키·Return으로 넣습니다.

<p align="center">
  <img src="docs/number-orthography.png" width="420" alt="숫자 표기 HUD"><br>
  <code>한 시에서 두 시 사이에 전화할게.</code>
</p>

로컬 Whisper나 Qwen을 올리거나, 클라우드로 보내 문장을 다듬는 받아쓰기도 있습니다. bdsk는 둘 다 안 합니다. 전사는 이 맥의 받아쓰기 엔진이 하고, 그 위에 올리는 건 조사 보존 사전과 숫자 표기 선택뿐입니다. 모델 파일을 받지 않습니다. 빠르고, 조사를 남기고, 그다음엔 없습니다.

## 하는 일

- **조사까지 치환.** `스위프트 데이터로` → `SwiftData로`, `스위프트 데이터에서는` → `SwiftData에서는`. `에서`+`는`처럼 겹친 조사도 이어서 먹습니다. 조사가 아니면 그대로 둡니다 (`스위프트 데이터링`).
- **숫자 표기 선택.** 엔진이 `1시`처럼 아라비아로 적어도, `한 시`/`1시`를 HUD에서 고른 뒤 넣습니다. 추측해서 바꾸지 않습니다.
- **시스템 엔진.** macOS 26에서는 기기 안 SpeechAnalyzer. 그 아래는 시스템 받아쓰기입니다.
- **커서에 바로.** 클립보드에 쌓아두지 않습니다. 필드가 안 바뀌면 붙여넣기 후 클립보드를 되돌립니다.
- **누르면 녹음.** 짧게 누르면 토글, 길게 누르면 누르는 동안만. 기본 핫키는 Control+Space입니다.

아직 없는 것: 히스토리에서 수정 학습, 스니펫, 플러그인, 클라우드, 영어 로케일 전환.

## 설치

[Releases](https://github.com/narnia-ai-mason/bdsk/releases/latest)에서 `bdsk-*-macos.dmg`를 받아 엽니다. `bdsk`를 Applications로 끌어다 놓으면 됩니다.

Apple Developer ID로 서명하지 않았으므로, 처음에는 **응용 프로그램의 bdsk를 우클릭 → 열기**로 실행하세요. 더블클릭만 하면 Gatekeeper가 막을 수 있습니다.

앱은 Dock에 상주하지 않습니다. 메뉴막대 아이콘이 켜진 표시입니다. 처음 실행하면 마이크, 음성 인식, 손쉬운 사용을 묻습니다. macOS 26에서는 이 맥에 한국어 받아쓰기 엔진이 없으면 받을지 확인합니다.

## 사전

설정에서 치환과 표제어(쉼표로 alias)를 등록합니다. 어간만 넣으면 됩니다. 공백 있는 표제어는 공백 없는 형태도 같이 봅니다. 저장 위치는 `~/Library/Application Support/dev.bdsk.app/lexicon.json`입니다.

## 권한

| 권한 | 용도 |
| --- | --- |
| 마이크 | 녹음 |
| 음성 인식 | 말을 글자로 바꿈 |
| 손쉬운 사용 | 전역 핫키, 커서 삽입 |
| 한국어 엔진 | macOS 26에서는 Apple이 기기 안에 두는 받아쓰기 자산. 없을 수 있어 첫 실행에서 받습니다. 그 아래는 시스템 받아쓰기를 씁니다. |

## 소스에서 빌드

Xcode 26에서 `bdsk.xcodeproj`를 열고 스킴 **bdsk**, 대상 **My Mac**, Run.

```bash
xcodebuild -project bdsk.xcodeproj -scheme bdsk \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build build
```

```bash
xcodebuild -project bdsk.xcodeproj -scheme bdsk \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build test
```

배포용 dmg는 `scripts/package-release.sh`입니다.

시스템 설정 스위치가 켜져 있어도, Xcode가 방금 빌드한 복사본에는 손쉬운 사용이 안 먹을 수 있습니다. 목록에서 bdsk를 끈 뒤 앱을 완전히 종료하고, 새로 나타난 항목을 켭니다. 켠 뒤에도 한 번 더 종료 후 실행합니다. Xcode 디버거가 붙어 있으면 macOS가 전역 핫키를 막습니다. 스킴 `bdsk`는 Debug executable을 끈 상태로 두었습니다.

| 경로 | 역할 |
| --- | --- |
| `bdsk/App` | 메뉴바, 설정 창, 권한, Command+Tab용 activation policy, 숫자 표기 HUD |
| `bdsk/Hotkey` | 전역 핫키 (CGEvent tap) |
| `bdsk/Dictation` | `AVAudioEngine` → SpeechAnalyzer, 없으면 SFSpeechRecognizer |
| `bdsk/Lexicon` | 조사 테이블, 치환, 숫자 표기, `lexicon.json` |
| `bdsk/Insertion` | AX 삽입, Command+V 폴백 |
| `bdsk/Settings` | 핫키 녹음, 사전 CRUD |
| `bdskTests` | `ParticleAwareReplacer`, `NumberOrthography` |
| `bench/apple` | SpeechAnalyzer 파일 전사 벤치. 앱 런타임에 넣지 않습니다. |
| `docs` | README 로고, TypeWhisper 비교 GIF, 숫자 표기 HUD |

번들 ID는 `dev.bdsk.app`입니다. 시각 언어는 [DESIGN.md](DESIGN.md)에 있습니다.

## 라이선스

[MIT](LICENSE). Copyright (c) 2026 Mason Seo.


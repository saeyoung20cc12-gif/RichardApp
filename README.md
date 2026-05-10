# 🦆 RichardApp — 나만의 오리 빌리저 가상 동반 앱

> Animal Crossing 스타일의 오리 캐릭터 **리처드**와 함께하는 iOS 가상 동반 앱.  
> 다마고치 + AI 채팅 + Dynamic Island 픽셀 아트를 결합했습니다.

<br>

## ✨ 주요 기능

- 🕐 **실제 시간 기반 일과표** — 리처드는 아침에 일어나고, 밥 먹고, 낮잠 자고, 밤엔 잠에 드는 실제 하루를 살아갑니다
- 🏝️ **Dynamic Island 픽셀 아트** — Live Activity로 잠금화면/화면 상단에 24×24px 픽셀 아트 리처드가 항상 떠 있습니다
- 🤖 **AI 대화 (Claude 연동)** — 채팅창에서 리처드와 대화하면, Anthropic Claude API로 한국어 인캐릭터 응답을 합니다
- 🦆 **3D 자율 로밍** — 메인 방 화면에 3D 리처드가 Animal Crossing처럼 걸어다니고 두리번거립니다

<br>

## 🎭 리처드 캐릭터 소개

| 항목 | 내용 |
|------|------|
| **이름** | 리처드 (오리, 남성) |
| **성격** | Lazy Type B — 조용하고 느긋한 몽상가, 간식과 낮잠을 사랑함 |
| **말투** | 모음 늘이기 (그렇구나아~), 문장 마지막에 항상 "그래유!" |
| **금지사항** | 이모지, 3인칭 자기 언급, AI임을 드러내는 발화 |
| **AI 모델** | claude-sonnet-4-6 |

<br>

## 📱 스크린샷

> *(출시 후 스크린샷 추가 예정)*

<br>

## 🏗️ 기술 스택

| 분류 | 기술 |
|------|------|
| 플랫폼 | iOS 16.2+ (SwiftUI) |
| 3D 렌더링 | SceneKit / USDZ |
| AI 연동 | Anthropic Claude API (`/v1/messages`) |
| Live Activity | ActivityKit + WidgetKit |
| 상태 관리 | Combine (`AppStateViewModel`) |
| 3D 모델 원본 | Meshy.ai 생성 후 Blender에서 텍스처 보정 |

<br>

## 🗂️ 프로젝트 구조

```
RichardApp/
├── RichardApp/                     ← 메인 앱 타겟
│   ├── Models/
│   │   ├── RichardModels.swift     ← RichardState, ChatMessage 등 데이터 모델
│   │   └── RichardActivityAttributes.swift  ← Live Activity 데이터 모델
│   ├── ViewModels/
│   │   └── AppStateViewModel.swift ← 앱 전체 상태 관리 + LLM 호출
│   ├── Services/
│   │   ├── AutonomyService.swift   ← 시간 기반 상태 자동 전환 (60초 타이머)
│   │   ├── LiveActivityService.swift ← Dynamic Island 생명주기 + 픽셀 아트 애니메이션
│   │   └── LLMService.swift        ← Claude API 연동
│   └── Views/
│       ├── MainRoomView.swift      ← 다마고치 메인 방 (3D 리처드 렌더링)
│       └── ChatView.swift          ← 리처드와의 채팅 UI
│
└── RichardWidget/                  ← Widget Extension 타겟
    └── RichardWidgetLiveActivity.swift  ← Dynamic Island UI (픽셀 아트)
```

<br>

## 🕐 리처드의 하루 일과

```
07:00 ~ 08:29  🌅 일어나는 중 (waking)
08:00 / 12:00 / 15:00 / 18:00  🍚 밥 먹는 중 (eating) — snack 픽셀 아트
09:00 / 10:00 / 13:00 / 16:00 / 19:00 / 20:00  🎮 노는 중 (playing)
그 외 낮 시간  💤 멍하니 있는 중 (idle)
23:00 ~ 06:59  🌙 자는 중 (sleeping)
대화 중  💬 채팅 중 (chatting)
```

<br>

## ⚙️ 설치 및 실행 (개발자용)

### 필수 조건
- Xcode 15 이상
- iOS 16.2 이상 기기 (Live Activity는 실기기 필요, 시뮬레이터 미지원)
- Anthropic API 키

### 설정 방법

1. **레포지토리 클론**
   ```bash
   git clone https://github.com/saeyoung20cc12-gif/RichardApp.git
   cd RichardApp
   ```

2. **API 키 설정**
   `RichardApp/Services/LLMService.swift` 파일에서 API 키를 본인의 키로 교체:
   ```swift
   private let apiKey = "YOUR_ANTHROPIC_API_KEY"
   ```
   > ⚠️ 실제 서비스 배포 시에는 xcconfig 파일로 분리하는 것을 권장합니다.

3. **Xcode에서 열기**
   ```
   RichardApp.xcodeproj
   ```

4. **Capabilities 설정** (Xcode > Signing & Capabilities)
   - Background Modes → `Background fetch`, `Background processing` 체크
   - Push Notifications 추가
   - Info.plist에 아래 항목 추가:
     ```
     NSSupportsLiveActivities = true
     NSSupportsLiveActivitiesFrequentUpdates = true
     ```

5. **빌드 및 실행** — 실기기 연결 후 Run (⌘R)

<br>

## 📋 구현 현황

| 기능 | 상태 |
|------|------|
| 시간 기반 상태 자동 전환 | ✅ 완료 |
| Dynamic Island 픽셀 아트 Live Activity | ✅ 완료 |
| Claude AI 한국어 인캐릭터 채팅 | ✅ 완료 |
| 3D 리처드 자율 로밍 (SceneKit) | ✅ 완료 |
| Tamagotchi 스타일 메인 방 UI | ✅ 완료 |
| normal3.png 3프레임 애니메이션 | 🚧 예정 |
| 홈화면 위젯 | 🚧 예정 |
| APNs 기반 Live Activity 업데이트 | 🚧 예정 |

<br>

## 🔒 보안 주의사항

- `LLMService.swift`의 API 키는 현재 하드코딩 상태입니다
- **절대로 API 키가 포함된 채로 public 레포에 Push하지 마세요**
- `.gitignore`에 secrets 파일을 추가하거나 `xcconfig`로 분리하는 것을 권장합니다

<br>

## 📄 라이선스

개인 프로젝트입니다. 별도 라이선스 없음.

---

*Made with 🦆 and lots of naps*

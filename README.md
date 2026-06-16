# RichardApp

RichardApp은 오리 캐릭터 `리처드`와 함께 지내는 iOS 반려 캐릭터 앱입니다. 리처드는 방 안을 돌아다니고, 허기/행복/재미 상태에 따라 반응하며, 대화와 미션, 간식, 코인, 미니게임으로 작은 일상을 만들어갑니다.

<p align="center">
  <img src="docs/app-preview.png" alt="RichardApp 미리보기" width="320">
</p>

## 주요 기능

- **3D 리처드 방**: SceneKit으로 구현한 리처드 모델이 따뜻한 방 배경 위를 자연스럽게 이동합니다.
- **다마고치형 돌봄 루프**: 허기, 행복, 재미 수치를 0~100으로 관리하고 `UserDefaults`에 저장합니다.
- **상태 기반 반응**: 쉬는 중, 노는 중, 먹는 중, 우는 중, 그리워하는 중, 토라짐, 자는 중, 놀람 등 상태에 따라 리처드가 다르게 행동합니다.
- **AI 대화**: Anthropic Messages API와 한국어 캐릭터 프롬프트를 사용해 리처드 말투로 대화합니다.
- **간식 상점**: 코인으로 간식을 사서 허기, 행복, 재미를 회복시킬 수 있습니다.
- **일일 미션**: 출석, 외출, 걸음 수 미션을 완료하고 코인을 받을 수 있습니다.
- **걸음 수 연동**: `CoreMotion` 만보기로 오늘 걸음 수를 읽어 걷기 미션 진행도를 갱신합니다.
- **하이로우 미니게임**: 다음 카드가 더 높을지 낮을지 맞히며 코인을 얻고 재미 수치를 올립니다.
- **Live Activity / Dynamic Island**: ActivityKit으로 리처드의 현재 상태와 픽셀 아트 프레임 애니메이션을 표시합니다.
- **위젯 타깃**: WidgetKit 및 App Intent 기반 확장 구조를 포함합니다.

## 기술 스택

- Swift
- SwiftUI
- SceneKit
- ActivityKit / WidgetKit
- CoreMotion
- UserDefaults
- Anthropic Messages API

## 프로젝트 구조

```text
RichardApp/
  RichardApp/              메인 앱 소스
  RichardWidget/           위젯 및 Live Activity 확장
  RichardApp.xcodeproj     Xcode 프로젝트
  docs/app-preview.png     README 미리보기 이미지
```

## API 키 설정

`LLMService`는 API 키를 소스 코드에 저장하지 않습니다. Anthropic API 키는 아래 방식 중 하나로 주입합니다.

- `ANTHROPIC_API_KEY` 환경변수
- 빌드 시 앱 번들 `Info.plist`에 들어가는 `ANTHROPIC_API_KEY` 값

키가 없어도 앱은 실행되지만, AI 대화는 키가 없다는 기본 안내 문구를 반환합니다.

## 실행 방법

Xcode에서 `RichardApp.xcodeproj`를 열고 `RichardApp` 스킴을 선택한 뒤 iOS 시뮬레이터 또는 실제 기기에서 빌드/실행합니다.

커맨드라인 빌드 예시:

```sh
xcodebuild -project RichardApp.xcodeproj -scheme RichardApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 참고

- `.DS_Store`, Xcode 사용자 데이터, 빌드 산출물, DerivedData는 Git에서 제외합니다.
- 돌봄 수치, 코인, 미션, 걸음 수는 로컬 저장소에 저장됩니다.

# 키보드에서 Face ID 를 쓰려던 이야기

잠긴 단축어는 **앱에서는 Face ID 로 열리는데, 키보드에서는 네 자리 번호를 묻는다.**
사용자가 이걸 고장으로 읽고 문의를 보냈다.

> 建议增加加密短语faceid解锁。
> (잠긴 단축어를 Face ID 로 열게 해 주세요.)

## 결론부터: 못 한다

커스텀 키보드 익스텐션에서는 `LocalAuthentication` 을 쓸 수 없다. 우회로도 없다.
번호를 쓰는 것은 게으름이 아니라 iOS 의 제약이다.

## 왜

세 겹으로 확인했다.

### ① Apple DTS 의 답변

Quinn "The Eskimo!" (2020-03, [forums/thread/129480](https://developer.apple.com/forums/thread/129480)):

> "LocalAuthentication is an **app** framework; it was not designed to be used in other
> contexts, like app extensions."

익스텐션에서 쓰라고 만든 프레임워크가 아니라는 말이다.

### ② 키보드는 포그라운드가 아니다

익스텐션에서 `evaluatePolicy` 를 부르면 `LAError.notInteractive` 또는
`"Caller is not running foreground"` 로 떨어진다. 생체 인증 UI 는 시스템이 포그라운드
앱 위에 띄우는 것인데, 키보드 익스텐션은 그 자리를 못 얻는다.

AutoFill Credential Provider 익스텐션은 화면이 완전히 올라온 뒤로 호출을 미뤄서
넘기기도 한다([forums/thread/776747](https://developer.apple.com/forums/thread/776747)).
**커스텀 키보드는 그 부류가 아니다** - 타이밍 문제가 아니라 자격 문제다.

### ③ 커스텀 키보드의 문서화된 제약

커스텀 키보드는 Touch ID / Face ID API 접근 자체가 허용되지 않는다.

## 흔적이 남아 있었다

이 조사를 하기 전에도 저장소에 흔적이 있었다.

- 익스텐션 타깃에 `INFOPLIST_KEY_NSFaceIDUsageDescription` 이 **들어가 있다.**
  (한 번 시도했다는 뜻이다)
- 그런데 익스텐션 코드에는 `LAContext` 가 **한 줄도 없고** PIN 으로 되어 있다.

즉 예전에 누군가 해 보고 안 돼서 번호로 돌아섰는데, **그 판단을 아무 데도 안 적었다.**
그래서 같은 질문이 사용자에게서 다시 왔고, 답할 근거를 처음부터 다시 찾아야 했다.
이 문서가 그 값을 치르지 않기 위한 것이다.

## 그래서 한 일

기능을 만들지 않고 **설명을 만들었다.** 궁금해지는 자리마다 한 줄씩.

| 자리 | 파일 |
| --- | --- |
| 키보드 PIN 판 (묻는 바로 그 순간) | `ClipKeyboardExtension/KeyboardView.swift` `pinEntryOverlay` |
| 앱의 잠금 번호 설정 (번호를 만드는 자리) | `ClipKeyboard/Screens/SecurePINSettings.swift` |

키보드 쪽 안내는 **"PIN 이 틀렸습니다" 와 같은 줄자리**를 쓴다. 키보드 높이 안에 숫자판까지
들어가야 해서, 줄을 하나 더 늘리면 작은 기기에서 아래가 잘린다.

## 앞으로 이 문서를 볼 사람에게

`INFOPLIST_KEY_NSFaceIDUsageDescription` 이 익스텐션 타깃에 남아 있는 것을 보고
"되겠네" 하고 다시 시작하지 말 것. 키는 남아 있어도 프레임워크가 안 열린다.

정 하고 싶으면 방법은 하나뿐이다: **앱에서 Face ID 로 인증하고, App Group 에 만료 시각을
적어 두고, 키보드는 그 시각만 본다.** 이건 "키보드에서 Face ID" 가 아니라 "앱에서 열어 둔
시간 창"이고, 창이 열린 동안에는 폰을 집은 다른 사람도 번호 없이 꺼낼 수 있다.
그 맞바꿈을 받아들일지는 그때 다시 판단할 일이다. 지금은 안 하기로 했다.

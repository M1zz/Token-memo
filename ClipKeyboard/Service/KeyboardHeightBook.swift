//
//  KeyboardHeightBook.swift
//  ClipKeyboard
//
//  시스템 키보드가 몇 pt 인지 적어 두는 장부. **앱과 키보드 익스텐션 양쪽 타겟**에 있다.
//
//  왜 필요한가: 익스텐션은 시스템 키보드 높이를 물어볼 방법이 없다. 그런 API 가 없다.
//  그래서 우리 키보드는 오래도록 254 라는 고정값을 썼고, 그 숫자가 기기마다 다른 진짜
//  높이와 어긋난 만큼 사용자에게 위화감으로 보였다. 게다가 iOS 는 입력 뷰를 자기 기본
//  높이로 한 번 세운 뒤 우리 값으로 끌어당기며 그 변화를 **애니메이션한다.** 키보드가
//  뜰 때 높이가 팍 튀는 것처럼 보이던 것이 이것이다.
//
//  방법은 하나뿐이다. **메인 앱은 시스템 키보드를 띄울 수 있다.** 앱에서 키보드가 올라올 때
//  그 높이를 재서 App Group 에 적어 두면, 익스텐션이 그대로 읽어 쓴다. 예측 입력 줄을 켰는지
//  껐는지 같은 그 사람의 설정까지 저절로 반영된다.
//
//  ⚠️ 앱을 한 번도 안 연 사람에게는 잰 값이 없다. 그때는 화면 비율로 어림한다
//     (`fallbackHeight`). 어림이라 몇 pt 어긋날 수 있고, 앱을 한 번 쓰면 정확해진다.
//
//  ⚠️ 익스텐션 타겟에도 컴파일된다. 메모리 상한(약 60MB) 안에서 도니 무거운 의존을 들이지 말 것.
//     여기 있는 건 UserDefaults 읽기·쓰기와 산수뿐이다.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum KeyboardHeightBook {

    // MARK: - 장부

    /// 잰 값들. `[화면키: 높이]` 형태로 App Group 에 있다.
    ///
    /// 화면마다 따로 적는 이유: 같은 사람이 아이폰과 아이패드를 함께 쓰고, 같은 기기라도
    /// 가로와 세로의 키보드 높이가 완전히 다르다. 하나로 뭉치면 방금 잰 값이 다른 상황의
    /// 값을 덮어써서, 돌아갈 때마다 어긋난다.
    private static var book: [String: Double] {
        get { (AppGroup.defaults?.dictionary(forKey: DefaultsKey.systemKeyboardHeights) as? [String: Double]) ?? [:] }
        set { AppGroup.defaults?.set(newValue, forKey: DefaultsKey.systemKeyboardHeights) }
    }

    /// 화면 하나를 가리키는 열쇠. 크기와 방향이 함께 들어간다.
    ///
    /// 짧은 변과 긴 변으로 적는 건 같은 기기를 한 이름으로 묶기 위해서다. 가로/세로는
    /// 뒤에 따로 붙인다. 그래야 "이 기기의 가로"와 "이 기기의 세로"가 각각 남는다.
    static func key(for size: CGSize) -> String {
        let short = Int(min(size.width, size.height).rounded())
        let long = Int(max(size.width, size.height).rounded())
        let orientation = size.width > size.height ? "L" : "P"
        return "\(short)x\(long)-\(orientation)"
    }

    // MARK: - 읽기

    /// 앱이 실제로 잰 값. 잰 적이 없으면 nil.
    static func measuredHeight(for size: CGSize) -> CGFloat? {
        guard let value = book[key(for: size)], value > 0 else { return nil }
        return CGFloat(value)
    }

    /// 시스템 키보드가 화면에서 차지하는 **전체** 높이. 잰 값이 있으면 그것, 없으면 어림값.
    static func totalHeight(for size: CGSize) -> CGFloat {
        measuredHeight(for: size) ?? fallbackHeight(for: size)
    }

    /// 익스텐션이 입력 뷰에 걸 높이. **우리가 그리는 판만큼**이다.
    ///
    /// ⚠️ 전체 높이가 아니다. iOS 26 부터 시스템이 우리 뷰 **바깥에** 지구본·받아쓰기 줄을
    ///    직접 그리기 때문에, 전체 높이를 그대로 요구하면 그 줄만큼 키보드가 더 높아진다
    ///    (`systemChrome` 머리말 참고).
    ///
    /// ## 왜 시스템 키보드와 "똑같이" 세우지 않는가
    ///
    /// 5.0.6 에서 한 번 그렇게 세웠다가 **판이 짜부라졌다.** 계산은 맞았는데 전제가 틀렸다.
    /// 시스템 키보드는 그 높이를 통째로 키에 쓴다. 우리 판은 같은 높이 안에 카테고리 줄을
    /// 먼저 얹고 남은 자리에 키를 깐다. 같은 값을 받으면 우리 격자만 한 줄 넘게 굶는다.
    ///
    /// 그래서 재는 값은 **격자가 받을 몫**으로 보고, 우리에게만 있는 머리 줄을 그 위에 얹는다.
    /// 총 높이는 시스템 키보드보다 머리 줄만큼 높아진다. 그게 맞다. 시스템 키보드에 없는
    /// 것을 우리가 그리고 있으니 그만큼 자리가 더 필요하다.
    ///
    /// ## 사용자가 높이를 고르면
    ///
    /// 위 문단이 정하는 것은 **기본값**이고, 사람은 그보다 낮거나 높은 것을 고를 수 있다
    /// (`KeyboardHeightPreset`). 고르는 자리가 왜 따로 필요한지는 그 열거형 머리말에 적었다.
    ///
    /// - Parameter content: 우리 판이 그리는 것들의 치수. 사용자가 설정에서 키 높이와
    ///   칸 수를 바꾸므로 값이 고정이 아니다.
    /// - Parameter preset: 사용자가 고른 높이. 익스텐션은 `.current` 를 넘긴다.
    static func height(for size: CGSize,
                       content: ContentMetrics = ContentMetrics(),
                       preset: KeyboardHeightPreset = .standard) -> CGFloat {
        // ① 시스템 키보드가 키에 쓰는 만큼은 격자에 준다. 머리 줄은 그 위에 얹는다.
        let keyArea = totalHeight(for: size) - systemChrome(for: size)
        let matched = keyArea + preset.extraHeight(content: content)

        // ② 그래도 버튼 여섯은 보인다. 화면이 작아 ① 이 모자란 기기를 위한 바닥.
        //
        //   ⚠️ **`.compact` 에는 이 바닥을 대지 않는다.** 이 값을 고른 사람은 "시스템 키보드와
        //      같은 높이"를 달라고 말한 것이고, 여섯 개가 안 보이면 굴려서 보겠다고 이미
        //      답한 것이다. 여기서 바닥을 대면 키를 크게 쓰는 사람에게는 고른 것이
        //      **아무 일도 안 하는 것처럼** 보인다(예전 `버튼 높이` 슬라이더가 그랬다).
        //      그래도 판이 통째로 사라지지는 않게 `minimumContentHeight` 는 남긴다.
        let floor = preset == .compact
            ? minimumContentHeight
            : max(content.floorHeight, minimumContentHeight)

        // ③ 그러나 화면을 통째로 먹지는 않는다. 가로에서 ② 를 그대로 쓰면 본문이 사라진다.
        let ceiling = maximumContentHeight(for: size)

        return min(max(matched, floor), ceiling)
    }

    /// 우리 판이 이보다 낮아지지는 않는다. 카테고리 줄 + 키 한 줄이 겨우 들어가는 높이.
    static let minimumContentHeight: CGFloat = 150

    // MARK: - 조작 키

    /// 조작 키 한 칸의 기본 높이. 설정을 건드린 적 없는 사람이 보던 그 크기다.
    static let defaultControlKeySize: CGFloat = 28
    /// 조작 키를 이보다 작게는 못 만든다. 44pt 손가락 자리 안에서 눈에 보이는 하한.
    static let minimumControlKeySize: CGFloat = 24
    /// 이보다 크게도 못 만든다. 더 키우면 머리 줄이 격자보다 두꺼워진다.
    static let maximumControlKeySize: CGFloat = 44

    /// 저장된 값을 지금 규칙에 맞게 해석한다. **읽는 곳은 전부 이걸 거친다.**
    ///
    /// ⚠️ `UserDefaults` 는 키가 없으면 0 을 돌려준다. 그대로 쓰면 머리 줄이 10pt 가 되어
    ///    윗줄이 통째로 사라진다.
    static func resolvedControlKeySize(_ raw: Double) -> CGFloat {
        guard raw > 0 else { return defaultControlKeySize }
        return min(max(CGFloat(raw), minimumControlKeySize), maximumControlKeySize)
    }

    /// 우리 판이 이보다 높아지지는 않는다.
    ///
    /// 키보드가 화면을 덮으면 무엇에 입력하고 있는지가 안 보인다. 세로에서는 화면의 55%,
    /// 가로에서는 62% 까지만 쓴다(가로는 화면이 낮아 같은 비율로는 키가 안 들어간다).
    static func maximumContentHeight(for size: CGSize) -> CGFloat {
        let isLandscape = size.width > size.height
        let share: CGFloat = isLandscape ? 0.62 : 0.55
        let room = size.height * share - systemChrome(for: size)
        return max(room, minimumContentHeight)
    }

    // MARK: - 우리 판이 그리는 것들의 치수

    /// 판 높이를 정하려면 **우리가 무엇을 그리는지** 알아야 한다.
    ///
    /// 키 높이와 칸 수는 설정에서 사용자가 바꾼다(App Group 공유). 값을 여기 박아 두면
    /// 키를 크게 쓰는 사람의 격자가 그만큼 잘린다. 그래서 인자로 받는다.
    ///
    /// ⚠️ 여기 숫자들은 `KeyboardView` 의 실제 레이아웃에서 온 것이다. 저쪽을 고치면
    ///    여기도 고쳐야 한다. 어긋나면 판이 다시 짜부라지거나 빈 자리가 남는다.
    struct ContentMetrics {
        /// 조작 키 한 칸의 높이. 설정 > 키보드 레이아웃에서 바꾼다.
        ///
        /// ⚠️ 머리 줄에 서는 것들(지우기 · 보내기 · 클립보드 · 지구본 · 갈래 · 전체삭제)이
        ///    전부 이 높이다. 하나만 키우면 줄이 어긋나므로 한 값으로 묶어 둔다.
        var controlKeySize: CGFloat = KeyboardHeightBook.defaultControlKeySize

        /// 카테고리 줄. 조작 키에 위아래 5pt 여백이다.
        ///
        /// ⚠️ 고정값이었다가 계산으로 바뀌었다. 조작 키를 키울 수 있게 되었는데 이 값이
        ///    38 에 박혀 있으면, 키운 만큼 머리 줄이 격자를 **덮어** 첫 줄이 잘린다.
        var headerHeight: CGFloat { controlKeySize + 10 }
        /// 격자 위아래 여백. 키를 누를 때 번지는 물결이 잘리지 않을 자리다(`gridRippleReach` × 2).
        var gridPadding: CGFloat = 24
        /// 격자 줄 사이.
        var rowSpacing: CGFloat = 10
        /// 키 하나의 높이. 설정 > 키보드 모양에서 바꾼다.
        var buttonHeight: CGFloat = 44
        /// 한 줄에 서는 키 개수. 설정에서 1~5.
        var columns: Int = 2
        /// 적어도 이만큼은 보인다. 셋만 보이면 목록이 아니라 조각으로 읽힌다.
        var minimumVisibleButtons: Int = 6

        /// 버튼 `minimumVisibleButtons` 개가 실제로 보이려면 판이 얼마나 높아야 하는가.
        ///
        /// ⚠️ 줄 수에 울타리를 둔다. 한 칸씩 쓰는 사람에게 여섯 줄을 그대로 주면
        ///    키보드가 화면 절반을 넘는다. 넷까지만 센다(가로에서는 위 ③ 이 또 깎는다).
        var floorHeight: CGFloat {
            let perRow = max(1, min(5, columns))
            let needed = Int(ceil(Double(minimumVisibleButtons) / Double(perRow)))
            let rows = CGFloat(max(1, min(4, needed)))
            let grid = rows * buttonHeight + (rows - 1) * rowSpacing
            return headerHeight + gridPadding + grid
        }
    }

    // MARK: - 시스템이 우리 뷰 밖에 그리는 몫

    /// iOS 26 부터 시스템이 **우리 뷰 바깥에** 그리는 높이.
    ///
    /// 무엇인가: 키보드 판 위쪽 여백과, 아래쪽 지구본·받아쓰기 줄(그리고 그 아래 홈 인디케이터
    /// 자리)이다. 예전에는 지구본을 키보드가 직접 그렸는데, iOS 26 은 시스템이 그린다.
    /// `needsInputModeSwitchKey` 가 false 로 오는 것이 그 증거다.
    ///
    /// ⚠️ **이 몫은 우리 뷰에 포함되지 않는다.** `safeAreaInsets` 로도 안 온다(전부 0 이다).
    ///    그래서 전체 높이를 그대로 요구하면 딱 이만큼 키보드가 더 높아진다.
    ///
    /// 실측 (iPhone 17 Pro · iOS 26.0.1 · 세로, 사파리 주소창 위치로 잼):
    ///
    /// | 우리 뷰에 건 높이 | 키보드 전체 | 차이 |
    /// | --- | --- | --- |
    /// | 314.6 (예전 코드) | 399.7 | 85.1 |
    /// | 268 (제약 없이 iOS 기본) | 353.0 | 85.0 |
    /// | 시스템 키보드 | 311.0 | - |
    ///
    /// 85pt 의 내역은 위 여백 13 + 지구본·받아쓰기 줄 40 + 홈 인디케이터 34 이다.
    /// 재는 방법은 `docs/postmortem/KEYBOARD_SYSTEM_CHROME_5_0_6.md` 에 적어 두었다.
    ///
    /// ⚠️ 가로·아이패드 값은 같은 방법으로 재서 넣은 것이다. 새 값이 필요하면 그 문서를 따를 것.
    static func systemChrome(for size: CGSize) -> CGFloat {
        guard systemDrawsKeyboardChrome else { return 0 }
        let isLandscape = size.width > size.height
        let isPad = min(size.width, size.height) >= 600
        if isPad { return isLandscape ? padLandscapeChrome : padPortraitChrome }
        return isLandscape ? phoneLandscapeChrome : phonePortraitChrome
    }

    /// 시스템이 지구본·받아쓰기 줄을 직접 그리는 OS 인가.
    static var systemDrawsKeyboardChrome: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static let phonePortraitChrome: CGFloat = 85
    /// 가로에서는 홈 인디케이터 자리가 21pt 로 줄어든다(세로 34pt).
    static let phoneLandscapeChrome: CGFloat = 72
    static let padPortraitChrome: CGFloat = 85
    static let padLandscapeChrome: CGFloat = 85

    /// 잰 값이 없을 때의 어림. **정답이 아니라 첫 인상용 임시값**이다.
    ///
    /// 애플이 키보드 높이를 공개하지 않으므로 화면 높이에 대한 비율로 어림한다.
    /// 비율은 실제로 올라오는 키보드(예측 입력 줄 포함)를 재서 맞췄다.
    ///
    /// | 기기 | 화면 | 키보드 | 비율 |
    /// | --- | --- | --- | --- |
    /// | iPhone SE 3 | 667 | 260 | 0.390 |
    /// | iPhone 13 mini | 812 | 335 | 0.413 |
    /// | iPhone 15 · 16 | 852 | 336 | 0.394 |
    /// | iPhone Pro Max | 932 | 346 | 0.371 |
    ///
    /// ⚠️ 예전에는 0.36 이었다. 위 표의 어느 기기보다도 낮아서, 앱을 아직 안 연 사람은
    ///    처음부터 짜부라진 키보드를 봤다. 0.39 로 올린다.
    /// 가로는 0.5, 아이패드는 화면이 커서 같은 비율을 쓰면 지나치게 높아지므로 따로 잡는다.
    ///
    /// 위아래 울타리를 두는 건 새 기기가 나와 비율이 어긋나도 말이 되는 범위에
    /// 머물게 하려는 것이다. 어림이 빗나가도 **쓸 수 없는 키보드**가 되지는 않는다.
    static func fallbackHeight(for size: CGSize) -> CGFloat {
        let height = max(size.width, size.height) > 0 ? size.height : 844
        let isLandscape = size.width > size.height
        // 짧은 변이 이보다 크면 아이패드로 본다(아이폰 최대가 440 언저리다).
        let isPad = min(size.width, size.height) >= 600

        if isPad {
            return clamp(height * 0.30, low: 260, high: 420)
        }
        return isLandscape
            ? clamp(height * 0.50, low: 150, high: 240)
            : clamp(height * 0.39, low: 250, high: 380)
    }

    private static func clamp(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }

    // MARK: - 적기 (앱 전용)

    /// 잰 값을 장부에 적는다. 값이 그대로면 쓰지 않는다.
    ///
    /// 같은 값을 다시 쓰지 않는 이유: App Group UserDefaults 는 키보드도 읽는 파일이라,
    /// 의미 없는 쓰기가 잦으면 키보드가 뜨는 순간과 겹칠 수 있다.
    static func record(height: CGFloat, for size: CGSize) {
        let key = key(for: size)
        let value = Double(height.rounded())
        var current = book
        guard current[key] != value else { return }
        current[key] = value
        book = current
        print("📐 [KeyboardHeightBook] \(key) 시스템 키보드 높이 \(value) 기록")
    }

    #if canImport(UIKit) && !os(macOS)

    /// 시스템 키보드가 올라올 때마다 높이를 재서 적는다. **앱에서 1회 호출.**
    ///
    /// 익스텐션에서 부르면 안 된다. 익스텐션이 보는 키보드는 자기 자신이라
    /// 자기 높이를 정답으로 적어 버리고, 그 값이 다시 자기 입력이 되는 고리가 생긴다.
    static func startWatching() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            consider(frame: frame)
        }
    }

    private static var observer: NSObjectProtocol?

    /// 잰 값을 믿을지 가린다. **믿을 수 없는 값을 적는 것이 안 적는 것보다 나쁘다.**
    /// 어긋난 값이 장부에 한 번 들어가면 어림값으로도 못 돌아가고 그대로 굳는다.
    static func consider(frame: CGRect, screen: CGSize? = nil) {
        let screenSize = screen ?? UIScreen.main.bounds.size
        guard screenSize.height > 0 else { return }

        // ① 하드웨어 키보드가 붙어 있으면 화면에는 단축 바만 뜬다. 그 높이를 적으면
        //    키보드가 손가락 두 마디만 해진다.
        // ② 아이패드의 떠 있는 키보드(floating)는 화면 너비를 다 안 쓴다.
        //    폭이 화면과 크게 다르면 그 상황으로 본다.
        let coversWidth = abs(frame.width - screenSize.width) < 1
        let ratio = frame.height / screenSize.height
        guard coversWidth, ratio > 0.2, ratio < 0.6 else {
            print("📐 [KeyboardHeightBook] 믿을 수 없는 프레임 무시: \(frame) (화면 \(screenSize))")
            return
        }

        record(height: frame.height, for: screenSize)
    }

    #endif
}

// MARK: - 사용자가 고르는 높이

/// 키보드 판을 얼마나 높게 세울지. **앱 설정과 익스텐션이 같은 값을 본다.**
///
/// 왜 따로 필요한가: 설정에는 오래도록 `버튼 높이` 슬라이더뿐이었는데, 그것은 키 하나의
/// 크기지 판의 높이가 아니다. 판 높이는 위 `height(for:content:preset:)` 이 시스템 키보드에서
/// 따오고, 슬라이더는 **바닥 계산에만** 들어간다. 그래서 요즘 아이폰에서는 슬라이더를 끝까지
/// 내려도 키보드 높이가 1pt 도 안 변했다(iPhone 15 기준 374pt 고정). 높이가 마음에 안 드는
/// 사람은 설정을 다 뒤진 끝에 아무것도 못 바꾸고 나갔다. 실제로 그 리뷰를 받았다.
///
/// 고르는 것은 **머리 줄 한 칸을 어떻게 할 것인가**다. 우리 판에는 시스템 키보드에 없는 줄이
/// 하나 있다(카테고리 · 지구본 · 클립보드 · 보내기). 그 줄 때문에 우리 키보드는 늘 시스템
/// 키보드보다 38pt 높고, 두 키보드를 오갈 때 그 38pt 가 애니메이션으로 보인다.
///
/// | 고른 값 | 판 높이 | 시스템 키보드와 |
/// | --- | --- | --- |
/// | `.compact` | 키 자리만 | 같다. 오갈 때 움직임이 없다 |
/// | `.standard` | 키 자리 + 머리 줄 | 머리 줄만큼 높다(기본값) |
/// | `.roomy` | 거기서 한 줄 더 | 한 줄 더 높다 |
///
/// ⚠️ `.compact` 는 **머리 줄을 없애지 않는다.** 그 줄에는 지구본이 서 있고, 다른 키보드로
///    건너갈 유일한 문이라 심사 요건이기도 하다. 없애는 대신 격자에서 그만큼 덜어낸다.
///    키가 덜 보이는 것은 굴려서 채운다.
///
/// ⚠️ 기본값을 `.standard` 에 둔다. 5.0.6 에서 모두를 `.compact` 자리로 옮겼다가 판이
///    짜부라져 되돌린 적이 있다(`height(for:content:preset:)` 머리말). 같은 일을 다시
///    기본값으로 하지 않는다. 고른 사람에게만 준다.
///
/// ⚠️ 익스텐션 타겟에도 컴파일된다. `UserDefaults` 읽기 하나뿐이니 그대로 둘 것.
enum KeyboardHeightPreset: String, CaseIterable, Identifiable {

    /// 시스템 키보드와 **같은 높이**. 머리 줄 몫을 격자에서 덜어낸다.
    case compact
    /// **기본값.** 시스템 키보드 + 머리 줄 하나.
    case standard
    /// 거기서 키 한 줄만큼 더.
    case roomy

    var id: String { rawValue }

    /// 값이 없거나 모르는 값일 때 쓰는 것.
    static let fallback: KeyboardHeightPreset = .standard

    // MARK: - 저장

    /// 지금 정해져 있는 값. App Group 에 있어 익스텐션도 같은 것을 읽는다.
    static var current: KeyboardHeightPreset {
        let raw = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardHeightPreset) ?? ""
        return KeyboardHeightPreset(rawValue: raw) ?? fallback
    }

    // MARK: - 높이

    /// 시스템 키보드의 키 자리 위에 **더 얹을** 높이.
    ///
    /// 키 높이를 인자로 받는 이유는 `.roomy` 의 "한 줄"이 그 사람이 쓰는 키 높이이기
    /// 때문이다. 44pt 를 쓰는 사람과 80pt 를 쓰는 사람의 한 줄은 같은 한 줄이 아니다.
    func extraHeight(content: KeyboardHeightBook.ContentMetrics) -> CGFloat {
        switch self {
        case .compact:
            return 0
        case .standard:
            return content.headerHeight
        case .roomy:
            return content.headerHeight + content.buttonHeight + content.rowSpacing
        }
    }

    // MARK: - 표시

    var localizedName: String {
        switch self {
        case .compact:
            return NSLocalizedString("시스템과 같게", comment: "Keyboard height preset name: match system keyboard")
        // ⚠️ "기본" 이라고 쓰지 않는다. 그 글자는 이미 갈래 이름으로 쓰이고 있어
        //    영어에서 General 로 나간다(문자열 카탈로그는 한국어 원문이 곧 열쇠다).
        case .standard:
            return NSLocalizedString("표준", comment: "Keyboard height preset name: standard")
        case .roomy:
            return NSLocalizedString("넉넉하게", comment: "Keyboard height preset name: roomy")
        }
    }

    var localizedDescription: String {
        switch self {
        case .compact:
            return NSLocalizedString("기본 키보드와 높이가 같아요. 키보드를 바꿔도 화면이 움직이지 않습니다. 단축어는 굴려서 봅니다.", comment: "Keyboard height preset description: compact")
        case .standard:
            return NSLocalizedString("기본 키보드보다 윗줄 하나만큼 높아요. 단축어가 더 보입니다.", comment: "Keyboard height preset description: standard")
        case .roomy:
            return NSLocalizedString("한 줄을 더 얹어요. 단축어를 굴리지 않고 보고 싶을 때.", comment: "Keyboard height preset description: roomy")
        }
    }
}

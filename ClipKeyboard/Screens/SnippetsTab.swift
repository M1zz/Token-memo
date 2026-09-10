//
//  SnippetsTab.swift
//  ClipKeyboard
//
//  단축어 탭이 무엇을 보여줄지 고르는 자리 - **목록** 이냐 **키보드 무대** 냐.
//
//  ⚠️ 쓰던 사람의 첫 화면은 업데이트로 바뀌지 않는다. 저장된 값이 없으면 목록이고,
//     새 설치에만 첫 실행에서 무대를 뿌린다. 기존 사용자에게는 **한 번 권하고 끝**이다
//     ([[LivingSkin]]·배경 제안과 같은 규칙 - 권할 때마다 빠져나갈 수 있어야 한다).
//
//  ⚠️ 제안 알림을 `ClipKeyboardList` 안에 두지 않았다. 그 화면은 이미 뷰 트리가 깊어
//     한 겹만 더 얹어도 기기에서 무너진 적이 있다(SwiftUI 타입 메타데이터 한계).
//     탭 껍데기인 여기가 그 알림의 자리로 맞다.
//

import SwiftUI
import LeeoKit

// MARK: - 무엇을 첫 화면으로 볼 것인가

enum SnippetsTabStyle: String, CaseIterable, Identifiable {
    /// 예전부터 있던 카드 목록. 문구를 만들고 고치는 곳.
    case list
    /// 키보드가 실제로 올라온 장면.
    case keyboard

    var id: String { rawValue }

    /// 저장된 값이 없으면 **목록** - 쓰던 사람 쪽에 맞춘 기본값이다.
    static var current: SnippetsTabStyle {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.snippetsTabStyle) ?? ""
        return SnippetsTabStyle(rawValue: raw) ?? .list
    }

    var localizedName: String {
        switch self {
        case .list:
            return NSLocalizedString("단축어 목록", comment: "Snippets tab style: list")
        case .keyboard:
            return NSLocalizedString("키보드 화면", comment: "Snippets tab style: keyboard stage")
        }
    }

    var localizedDescription: String {
        switch self {
        case .list:
            return NSLocalizedString("카드 목록이에요. 여기서 만들고 고칩니다.",
                                     comment: "Snippets tab style description: list")
        case .keyboard:
            return NSLocalizedString("다른 앱에서 키보드가 올라온 모습 그대로예요. 눌러서 바로 써 볼 수 있어요.",
                                     comment: "Snippets tab style description: keyboard stage")
        }
    }

    /// 하단 탭바에 적히는 **짧은** 이름.
    ///
    /// ⚠️ `localizedName`("단축어 목록"·"키보드 화면")과 일부러 다르다. 그쪽은 설정에서
    ///    두 선택지를 견주어 고르는 자리라 길어도 되지만, 탭바는 네 칸을 나눠 쓰는 자리라
    ///    긴 이름은 말줄임으로 잘려 오히려 무슨 화면인지 알 수 없게 된다.
    var tabName: String {
        switch self {
        case .list:     return NSLocalizedString("목록", comment: "Tab: snippets showing the list")
        case .keyboard: return NSLocalizedString("키보드", comment: "Tab: snippets showing the keyboard stage")
        }
    }

    var symbolName: String {
        switch self {
        case .list:     return "square.grid.2x2"
        case .keyboard: return "keyboard"
        }
    }

    /// 반대쪽 화면. 툴바의 전환 버튼과 탭바 다시 누르기가 **같은 규칙**을 쓰도록 여기 둔다.
    var toggled: SnippetsTabStyle {
        self == .list ? .keyboard : .list
    }
}

// MARK: - 처음 쓰는 사람이 지나는 길

/// 첫 흐름의 **지금 어디쯤**인가.
///
/// ⚠️ 세 걸음이 **끊기지 않고 이어져야** 한다
///    ① 무엇이 준비돼 있는지 보고 ② 그것들을 하나씩 눌러 보고 ③ 키보드를 켠다.
///
/// ⚠️ 여기서 **아무것도 만들게 하지 않는다.** 예전에는 ①이 "첫 단축어 만들기"였고
///    ②의 자리에 템플릿·콤보를 차례로 만드는 장이 셋 더 있었다. 처음 온 사람에게
///    빈 칸을 네 번 내미는 일이었다 - 만드는 법보다 **무엇을 해주는 물건인지**가 먼저다.
///    쓸 것은 설치 첫 실행에 이미 넣어 두었다(`performSampleInsertion`).
///
/// ⚠️ 쓰던 사람은 이 길을 걷지 않는다(`startedFresh`).
enum SnippetsOnboardingStep: Equatable {
    /// ① 무엇을 넣어 뒀는지 알린다.
    case welcome
    /// ② 넣어 둔 것을 **무대에서 차례로 눌러 본다** (단축어 → 템플릿 → 콤보).
    case tryScenarios
    /// ③ **직접 하나 만들어 본다.** 남의 것을 눌러 본 다음에 오는 걸음이다.
    case makeOwn
    /// 다 지났다. 평소 화면으로.
    case done

    /// 순서: 환영 → 써 보기 → 직접 만들기.
    ///
    /// ⚠️ **직접 만들기가 맨 앞이 아니라 여기 있는 이유.** 처음 온 사람에게 빈 칸부터
    ///    내밀면 무엇을 적어야 할지 모른다. 단축어·템플릿·콤보를 눌러 보고 나면
    ///    "아, 나는 이런 걸 넣으면 되겠다"가 생긴다. 그때 만들게 한다.
    ///
    /// ⚠️ 예전에는 콤보를 눌러 본 뒤 **아무 걸음도 없었다.** 키보드를 이미 켜 둔 사람은
    ///    거기서 튜토리얼이 끝나 버려, 셋을 눌러 본 것으로 끝나고 자기 것은 하나도
    ///    없는 채로 남았다. 눌러 보는 것과 갖는 것은 다르다.
    ///
    /// ⚠️ **키보드 켜기는 이 길에서 뺐다.** 예전에는 여기가 마지막 걸음이라, 다 배우고 나면
    ///    전체 화면 안내가 앞을 막고 섰다. 그런데 그 걸음은 설정 앱으로 나갔다 와야 끝나는
    ///    일이라, 지금 안 할 사람에게는 **지날 길이 없는 문**이었다. 하루 밀어 두는 장치를
    ///    달아 둬도 다음 날 또 막아선다.
    ///
    ///    켜야 한다는 사실은 무대의 띠가 대신 말한다(`InAppKeyboardStage.keyboardSetupBanner`).
    ///    그 띠는 **켜졌다고 확인될 때까지 계속 떠 있고**(`KeyboardInstallState.isUsable`),
    ///    누르면 같은 안내가 시트로 열린다. 막지 않으면서 사라지지도 않는 자리다.
    ///
    ///    그래서 **켜졌는지를 여기서 묻지 않는다.** 예전에는 `keyboardUsable` 을 받아
    ///    걸음을 갈랐는데, 지금 그 값은 걸음과 아무 상관이 없다. 안 쓰는 값을 받아 두면
    ///    다음 사람이 "여기서 뭔가 하겠거니" 하고 다시 문을 세운다.
    static func current(startedFresh: Bool,
                        welcomeDone: Bool,
                        chaptersDone: Bool,
                        makeOwnDone: Bool) -> SnippetsOnboardingStep {
        guard startedFresh else { return .done }
        if !welcomeDone { return .welcome }
        if !chaptersDone { return .tryScenarios }
        if !makeOwnDone { return .makeOwn }
        return .done
    }
}

// MARK: - "화면이 둘이에요" 를 지금 짚고 있는가

/// 안내가 떠 있다는 **한 가지 사실**을 두 화면이 같이 본다.
///
/// ⚠️ 짚어 주는 것이 세 군데다 - 무대의 띠, 무대 머리말의 격자 버튼, 그리고 **하단 탭바**.
///    앞의 둘은 무대 안에 있지만 탭바는 `TabView` 바깥에 그려야 해서(UIKit 이 콘텐츠 위에
///    얹는다) `MainTabView` 몫이다.
///
/// ⚠️ 그래서 조건을 **두 번 적었더니 갈라졌다.** 무대 쪽은 "다 배운 뒤"까지 봤는데
///    탭바 쪽은 그 조건이 빠져, 앱을 켜자마자 탭만 빛나고 정작 그게 무슨 뜻인지 말해 주는
///    띠는 없었다. 가리키는 것만 있고 말이 없으면 그건 안내가 아니라 얼룩이다.
///    조건은 `SnippetsTab.showsSwitchHint` 한 곳에서만 정하고, 여기로 흘려보낸다.
@MainActor
final class SwitchHintBeacon: ObservableObject {
    static let shared = SwitchHintBeacon()
    private init() {}

    @Published var isShowing = false
}

// MARK: - 화면 전환 버튼

/// 단축어 목록 ↔ 키보드 미리보기 **한 개짜리 전환 버튼.**
///
/// ⚠️ 버튼은 **갈 곳**을 보여준다. 목록에 있으면 키보드 모양(= 누르면 키보드 미리보기로),
///    미리보기에 있으면 격자 모양(= 누르면 단축어 목록으로). 누르는 순간 그 버튼이
///    반대편 모양으로 바뀌므로, 한 자리에서 왔다갔다 하는 것이 한눈에 읽힌다.
///
/// ⚠️ 지금 상태를 그리지 않는다. 두 칸짜리 스위치는 "지금 여기"를 보여주지만,
///    버튼 하나는 "다음에 갈 곳"을 보여주는 편이 눌렀을 때 무슨 일이 나는지 분명하다.
///
/// 고른 값은 그대로 저장된다(설정 > 첫 화면과 같은 값) - 다음에 열면 마지막에 본 쪽이 나온다.
struct SnippetsStyleSwitchButton: View {
    /// 유리 서클 버튼들 사이 간격 - **목록 툴바와 무대 머리말이 같은 값을 쓴다.**
    ///
    /// ⚠️ 두 곳이 제각각이던 것을 여기로 모았다. 목록은 `-8`(서클이 8pt 겹침),
    ///    무대는 `14`(넉넉히 떨어짐)라, 같은 버튼 쌍이 화면마다 다른 물건처럼 보였다.
    ///    음수 간격은 44pt 서클끼리 실제로 겹쳐서 두 개가 한 덩어리로 읽힌다.
    static let clusterSpacing: CGFloat = 6

    /// 유리 서클의 지름 - 버튼을 새로 만들 때 이 값을 쓸 것.
    static let diameter: CGFloat = 44

    @Binding var styleRaw: String

    /// 지금 이 버튼을 **짚어 주는 중인가**(화면이 둘이라는 안내가 떠 있을 때).
    ///
    /// ⚠️ 안내는 "위의 버튼을 누르면" 이라고 말하는데 정작 그 버튼은 가만히 있었다.
    ///    유리 서클 셋이 나란한 머리말에서 **어느 것**인지 글만으로는 못 짚는다.
    var highlighted: Bool = false

    private var current: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }
    /// 탭바를 다시 누르는 것과 **같은 규칙**을 쓴다(`SnippetsTabStyle.toggled`).
    /// 두 길이 다른 곳으로 가면 같은 자리에서 누를 때마다 결과가 달라진다.
    private var target: SnippetsTabStyle { current.toggled }

    var body: some View {
        Button {
            HapticManager.shared.light()
            // 값만 바꾼다. 오르내리는 연출은 두 화면을 쥐고 있는 쪽이 건다
            // (`SnippetsTab.content` 의 `screenSwapAnimation`).
            styleRaw = target.rawValue
        } label: {
            // 툴바의 + 와 **같은 유리 언어** - 클리어 글래스 서클(하단 탭바와도 같다).
            // 옆에 나란히 선 버튼이 하나만 맨몸이면 그것만 다른 앱에서 온 것처럼 보인다.
            Image(systemName: target.symbolName)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: Self.diameter, height: Self.diameter)
                .glassEffect(.clear.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        // 머리말의 + 를 가리킬 때와 **같은 물결**이다(`InAppKeyboardStage.stageHeader`).
        // 튜토리얼이 가리키는 것은 늘 같은 모양으로 빛나야 한 가지 뜻으로 읽힌다.
        .overlay {
            if highlighted {
                KeyRipple(shape: Circle(), color: .accentColor, reach: 9)
            }
        }
        .accessibilityLabel(target.localizedName)
        .accessibilityHint(NSLocalizedString("이 화면과 저 화면을 오갑니다", comment: "Switch between list and keyboard preview"))
    }
}

// MARK: - 탭 껍데기

struct SnippetsTab: View {
    @AppStorage(DefaultsKey.snippetsTabStyle) private var styleRaw: String = SnippetsTabStyle.list.rawValue
    @AppStorage(DefaultsKey.keyboardStageOffered) private var offered: Bool = false
    /// 환영 화면을 지났는가(시작했든 나중에 보기로 했든).
    @AppStorage(DefaultsKey.tutorialWelcomeDone) private var welcomeDone: Bool = false
    /// 이 기기가 4.4.4 이후로 처음 시작했는가 - 쓰던 사람에게 튜토리얼을 다시 깔지 않기 위한 표식.
    @AppStorage(DefaultsKey.startedFreshV444) private var startedFresh: Bool = false
    /// 튜토리얼이 끝난 시각·실행 횟수 - 무대의 키보드 켜기 띠가 이 둘을 본다.
    @AppStorage(DefaultsKey.tutorialFinishedAt) private var tutorialFinishedAt: Double = 0
    @AppStorage(DefaultsKey.tutorialFinishedAtLaunch) private var tutorialFinishedAtLaunch: Int = 0
    /// 지금 무대에서 가리키고 있는 단축어 id - 아직 안 눌러 봤으면 값이 남아 있다.
    @AppStorage(DefaultsKey.tutorialFirstUseMemoId) private var firstUseMemoIdRaw: String = ""
    /// 써 보는 장(단축어 → 템플릿 → 콤보) 완료 표식.
    @AppStorage(DefaultsKey.tutorialSnippetDone) private var tutorialSnippetDone: Bool = false
    @AppStorage(DefaultsKey.tutorialTemplateDone) private var tutorialTemplateDone: Bool = false
    @AppStorage(DefaultsKey.tutorialComboDone) private var tutorialComboDone: Bool = false
    /// 콤보 장 안쪽의 걸음. 빈 값이면 그 장이 아니거나 아직 안 열렸다.
    @AppStorage(DefaultsKey.tutorialComboStep) private var comboStepRaw: String = ""
    /// 챕터 기계가 "더 가리킬 것이 없다"고 알려주면 켜진다.
    @AppStorage(DefaultsKey.tutorialChaptersDone) private var chaptersFinished: Bool = false
    /// 직접 하나 만들어 보는 걸음을 지났는가(만들었든 미뤘든).
    @AppStorage(DefaultsKey.tutorialMakeOwnDone) private var makeOwnDone: Bool = false
    /// 샘플을 치울지 물어봤는가 - 답이 무엇이든 한 번만 묻는다.
    @AppStorage(DefaultsKey.tutorialSampleCleanupAsked) private var sampleCleanupAsked: Bool = false
    /// 목록 ↔ 키보드를 오가는 법을 한 번 짚어 줬는가.
    @AppStorage(DefaultsKey.tutorialSwitchHintSeen) private var switchHintSeen: Bool = false

    @State private var showOffer = false
    /// 연습용 단축어를 치울지 묻는 알림.
    @State private var showSampleCleanup = false
    /// "혹시 이런 분이신가요?" - 써 보고 나서 한 번 묻는 판(`PersonaPrompt`).
    @State private var showPersonaPrompt = false
    /// 넣기까지 끝났고 **보내기만 남았다.** 이 동안 보내기 동그라미에 파형이 인다.
    ///
    /// ⚠️ 일부러 저장하지 않는다. 앱을 껐다 켜면 입력창이 비어 있어 보낼 것이 없으므로,
    ///    기다리던 상태만 남으면 아무것도 못 하는 화면이 된다. 그때는
    ///    `resumeTutorialIfStalled` 가 그 장을 다시 열어 준다(키가 다시 빛난다).
    @State private var awaitingSend = false
    /// 다음 장까지 도는 원이 끝나는 시각. nil 이면 안 보인다.
    @State private var countdownEndsAt: Date?
    /// 그 원이 다 돌면 할 일. 눌러서 건너뛸 때 이걸 취소해야 두 번 열리지 않는다.
    @State private var breatherWork: DispatchWorkItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    /// 화면이 갈아 끼워질 때의 모습 - 자리를 옮기지 않고 그 자리에서 바뀐다.
    private var screenTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985))
    }

    // MARK: - 목록 ↔ 무대가 바뀌는 모습

    /// **무대는 키보드처럼 아래에서 올라온다.**
    ///
    /// 이 화면이 보여주는 것이 "다른 앱에서 키보드가 올라온 장면"이라, 오르내리는 방향이
    /// 그 물건의 방향과 같아야 한다. 페이드로 갈아 끼우면 어디서 왔는지가 없어서,
    /// 화면이 바뀐 게 아니라 잘못 그려진 것처럼 보인다(예전 모습).
    private var stageTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom)
    }

    /// 오르내리는 속도. **올라올 때와 내려갈 때가 다르다.**
    ///
    /// ⚠️ **튕기지 않는 곡선이라야 한다.** 스프링에 반동을 조금이라도 남기면 무대가
    ///    자리에 닿고 한 번 더 흔들려서, 화면이 덜그럭거리는 것으로 읽힌다.
    ///    `.smooth` 는 반동이 없는 스프링이다.
    ///
    /// ⚠️ 그런데 **내려갈 때 같은 스프링을 쓰면 끝에서 버벅인다.** 스프링은 끝으로
    ///    갈수록 느려지며 목표에 스며드는 곡선이라, 자리에 안착할 때는 좋지만
    ///    화면 밖으로 나가는 데 쓰면 마지막 몇 pt 를 질질 끈다. 다 사라진 줄 알았는데
    ///    아직 조금 남아 기어가는 그림이 된다.
    ///
    /// ⚠️ 그렇다고 `easeIn` 으로 끝까지 가속하면 **최고 속도로 화면 끝에 부딪혀 툭 끊긴다.**
    ///    한동안 그렇게 두었더니 "자연스럽게 내려가지 않는다"는 말을 들었다. 내려갈 때는
    ///    부드럽게 떠나 부드럽게 빠지는 `easeInOut` 을 쓴다. 스프링처럼 꼬리를 끌지 않는다.
    private var screenSwapAnimation: Animation? {
        guard !reduceMotion else { return nil }
        // `styleRaw` 가 이미 새 값이라, 여기 `style` 은 **가려는 곳**이다.
        return style == .keyboard ? .smooth(duration: 0.36) : .easeInOut(duration: 0.3)
    }

    private var style: SnippetsTabStyle { SnippetsTabStyle(rawValue: styleRaw) ?? .list }

    /// 지금 첫 흐름의 어디쯤인가(위 `SnippetsOnboardingStep` 참고).
    private var onboardingStep: SnippetsOnboardingStep {
        .current(startedFresh: startedFresh,
                 welcomeDone: welcomeDone,
                 chaptersDone: chaptersFinished
                     || (tutorialSnippetDone && tutorialTemplateDone && tutorialComboDone),
                 makeOwnDone: makeOwnDone)
    }

    /// 장과 장 사이 쉼(초). 이 동안 카운트다운 원이 돈다.
    ///
    /// ⚠️ 5초였다가 3초로 줄였다. 방금 한 바퀴를 돈 참에 한 박자 쉬라고 둔 자리인데,
    ///    5초는 쉼이 아니라 **멈춤**으로 읽혔다. 원이 누를 수 있게 된 지금은
    ///    (`NextChapterCountdown.onSkip`) 급한 사람이 기다릴 이유도 없다.
    static let chapterBreather: Double = 3.0

    /// 아직 안 눌러 본, 지금 가리키는 단축어.
    private var highlightedMemoId: UUID? {
        firstUseMemoIdRaw.isEmpty ? nil : UUID(uuidString: firstUseMemoIdRaw)
    }

    /// 콤보 장 안쪽에서 지금 서 있는 걸음. 그 장이 아니면 nil.
    private var comboStep: ComboTutorialStep? {
        ComboTutorialStep(rawValue: comboStepRaw)
    }

    /// 무대에 띄울 안내 한 줄. 콤보 장이면 그 장 안쪽의 걸음이 말하고, 아니면 장 자체가 말한다.
    ///
    /// ⚠️ 넣기까지 끝나고 보내기만 남은 자리에서는 **아무 말도 넘기지 않는다.** 그 자리에
    ///    장의 안내("이걸 눌러보세요")를 그대로 흘리면, 이미 누른 사람에게 또 누르라고
    ///    말하는 꼴이 된다. 그때 할 말은 무대가 스스로 갖고 있다.
    private var stageTutorialLine: String? {
        if let comboStep { return comboStep.coachLine }
        if awaitingSend { return nil }
        return nextChapter?.coachLine
    }

    /// 무대의 키보드에서 **실제로 물결칠** 키.
    ///
    /// ⚠️ 콤보 장에서 보내기를 가리키는 걸음(과 마지막 확인)에서는 키를 끈다. 안 끄면
    ///    키캡과 보내기 동그라미가 **동시에** 물결쳐서, 지금 눌러야 할 곳이 둘이 된다.
    ///    물결은 언제나 한 곳에만 있어야 안내로 읽힌다.
    private var stageHighlightedMemoId: UUID? {
        if let comboStep { return comboStep.comboPart == nil ? nil : highlightedMemoId }
        return highlightedMemoId
    }

    /// 지금 보내기 동그라미가 물결쳐야 하는가.
    ///
    /// 콤보 장에서는 걸음이 정한다(`sendFirst`·`sendSecond`). 나머지 장에서는
    /// "넣었고 보내기만 남은" 상태(`awaitingSend`)가 정한다.
    private var stageHighlightsSend: Bool {
        if let comboStep { return comboStep.highlightsSend }
        return awaitingSend
    }

    /// 목록 ↔ 키보드를 오가는 법을 지금 짚어 줄 때인가.
    ///
    /// ⚠️ **다 배운 뒤에** 한 번만 나온다. 배우는 중에 "다른 화면도 있어요"를 말하면
    ///    지금 하던 걸음에서 눈이 떠나고, 처음 온 사람은 그 길로 나갔다가 안 돌아온다.
    ///
    /// ⚠️ 무대에 있을 때만이다. 목록에 있는 사람에게 무대 머리말의 버튼을 가리켜 봐야
    ///    그 버튼이 화면에 없다.
    private var showsSwitchHint: Bool {
        startedFresh && !switchHintSeen
            && style == .keyboard && onboardingStep == .done
    }

    var body: some View {
        // 두 화면 **뒤에 같은 바닥**을 깐다. 각 화면이 자기 배경을 칠하면 갈아 끼우는 순간
        // 바닥색이 한 번 바뀌어 번쩍인다 - 바뀌는 건 그 위에 놓인 것뿐이어야 한다.
        ZStack {
            theme.bg.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch onboardingStep {
            case .welcome:
                TutorialWelcomeView(
                    onStart: { startTutorial() },
                    onSkip: { skipTutorial() }
                )
                .transition(screenTransition)
            // ⚠️ 이 둘을 **한 분기로 묶는다.** 나눠 두면 단계가 바뀔 때 SwiftUI가 무대를
            //    다른 뷰로 보고 새로 만든다 - 그 순간 입력창을 들고 있던 객체도 새것이 되어
            //    **방금 넣은 글이 사라진다.** 눌러서 배운 결과가 눈앞에서 지워지는 셈이다.
            //    (가리키는 키는 뷰를 갈아 끼우지 않고 `highlightedMemoId` 값만 바뀌면 된다)
            case .tryScenarios, .makeOwn, .done:
                // **목록은 늘 깔려 있고, 무대가 그 위로 오르내린다.**
                //
                // ⚠️ 목록을 넣었다 뺐다 하지 않는다. 그러면 오갈 때마다 목록이 통째로 다시
                //    만들어져서, 미끄러짐이 **끝난 뒤에** 카드·팁·유리가 한 번 더 자리를
                //    잡는다. 움직임은 멈췄는데 화면이 계속 달그락거리는 것으로 보였다.
                //    깔아 두면 돌아왔을 때 이미 다 되어 있다.
                //
                // ⚠️ 목록에는 아무 연출도 걸지 않는다. 무대 바닥이 불투명해서 어차피 가려지는데
                //    (`stageBackground`), 그 밑에서 목록까지 같이 줄었다 커지면 움직이는 것이
                //    둘이 된다. 움직이는 것은 하나여야 눈이 편하다.
                ZStack {
                    // 전환 버튼은 목록의 **툴바 + 왼쪽**에 있다(ClipKeyboardList.toolbarButtons).
                    // 화면 위에 겹쳐 띄우면 카드를 가린다.
                    ClipKeyboardList()
                        .allowsHitTesting(style == .list)
                        .accessibilityHidden(style != .list)

                    // 겹치는 순서를 우리가 정한다. SwiftUI 에 맡기면 내려가는 무대가 목록
                    // 뒤로 숨어서 **아무것도 안 움직이는 것처럼** 보인다.
                    if style == .keyboard {
                        InAppKeyboardStage(styleRaw: $styleRaw,
                                           highlightedMemoId: stageHighlightedMemoId,
                                           highlightedComboPart: comboStep?.comboPart,
                                           tutorialLine: stageTutorialLine,
                                           asksToMakeOwn: onboardingStep == .makeOwn,
                                           onMakeOwnSkipped: { finishMakeOwn() },
                                           highlightsSend: stageHighlightsSend,
                                           awaitsComboConfirm: comboStep == .confirm,
                                           onComboConfirmed: { finishComboChapter() },
                                           showsSwitchHint: showsSwitchHint,
                                           onSwitchHintSeen: { switchHintSeen = true })
                            .transition(stageTransition)
                            .zIndex(1)
                    }
                }
                .animation(screenSwapAnimation, value: styleRaw)
            }
        }
        // 장과 장 사이의 원 - 아래쪽에 잠깐 떠 있다가 스스로 사라진다.
        // 무대 위에 얹되 누를 수 없어서, 뒤에서 하던 것을 가리지 않는다.
        .overlay(alignment: .bottom) {
            if let endsAt = countdownEndsAt {
                NextChapterCountdown(endsAt: endsAt,
                                     total: Self.chapterBreather,
                                     onSkip: { advanceAfterBreather() })
                    .padding(.bottom, 92)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: onboardingStep)
        .onReceive(NotificationCenter.default.publisher(for: .memoUsed), perform: chapterKeyWasUsed)
        // 보내야 한 바퀴가 끝난다 - 넣은 것이 어디로 가는지는 말풍선이 올라와야 보인다.
        .onReceive(NotificationCenter.default.publisher(for: .stageMessageSent)) { _ in
            finishChapterAfterSend()
        }
        // 콤보의 → 는 글을 넣지 않아 `.memoUsed` 가 안 나간다 - 따로 듣는다.
        .onReceive(NotificationCenter.default.publisher(for: .comboValueAdvanced),
                   perform: comboValueWasAdvanced)
        // 자기 것을 하나라도 만들면 그 걸음은 끝난다 - 어디서 만들었든(무대의 +, 목록, 공유 시트).
        .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
            completeMakeOwnIfMadeSomething()
            askPersonaIfEarned()
        }
        .onAppear {
            offerKeyboardStageIfNeeded()
            resumeTutorialIfStalled()
            completeMakeOwnIfMadeSomething()
            askToCleanUpSamplesIfNeeded()
            askPersonaIfEarned()
        }
        // 걸음이 바뀌어 무대로 들어왔는데 가리키는 것이 없으면 여기서 이어 붙인다.
        .onChange(of: onboardingStep) { _, _ in
            resumeTutorialIfStalled()
            markTutorialFinishedIfNeeded()
            askToCleanUpSamplesIfNeeded()
        }
        .onAppear {
            markTutorialFinishedIfNeeded()
            syncListVisibilityForTips()
            SwitchHintBeacon.shared.isShowing = showsSwitchHint
        }
        .onDisappear { SwitchHintBeacon.shared.isShowing = false }
        // 목록이 뒤에 깔려만 있는 동안에는 거기 붙은 팝오버 팁을 재운다.
        // 팝오버는 창 위에 그려져 **무대 안내까지 덮는다**(`AddMemoTip` 주석).
        .onChange(of: styleRaw) { _, _ in syncListVisibilityForTips() }
        // 탭바를 짚는 물결은 `MainTabView` 가 그린다 - 조건은 여기서만 정한다.
        .onChange(of: showsSwitchHint) { _, shows in
            SwitchHintBeacon.shared.isShowing = shows
        }
        .alert(NSLocalizedString("연습용 단축어를 치울까요?", comment: "Sample cleanup title"),
               isPresented: $showSampleCleanup) {
            Button(NSLocalizedString("치우기", comment: "Sample cleanup: delete"), role: .destructive) {
                deleteSampleMemos()
            }
            Button(NSLocalizedString("그대로 둘게요", comment: "Sample cleanup: keep"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("튜토리얼에서 눌러 본 단축어·템플릿·콤보예요. 이제 직접 만드셨으니 치워도 되고, 그대로 두고 고쳐 쓰셔도 돼요.",
                                   comment: "Sample cleanup message"))
        }
        // ⚠️ 시트로 띄운다. 전체 화면으로 세우면 하던 일을 **끊는다** - 부른 적 없는
        //    질문이라 그럴 자격이 없다. 아래로 쓸어내려 닫는 것도 "나중에" 와 같게 둔다.
        .sheet(isPresented: $showPersonaPrompt, onDismiss: { PersonaPrompt.markAsked() }) {
            PersonaSelectionView(onContinue: { showPersonaPrompt = false }, mode: .prompt)
        }
        .alert(NSLocalizedString("새 키보드 화면을 써보시겠어요?", comment: "Keyboard stage offer title"),
               isPresented: $showOffer) {
            Button(NSLocalizedString("써볼게요", comment: "Accept category activation")) {
                styleRaw = SnippetsTabStyle.keyboard.rawValue
            }
            Button(NSLocalizedString("괜찮아요", comment: "Decline category activation"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("다른 앱에서 키보드가 올라온 모습 그대로 보여줘요. 언제든 설정 > 첫 화면에서 목록으로 되돌릴 수 있어요.",
                                   comment: "Keyboard stage offer message"))
        }
    }

    // MARK: - 써 보는 장들 (무대 위에서 돈다)

    /// 아직 안 지난 다음 장. 없으면 nil.
    private var nextChapter: TutorialChapter? {
        TutorialChapter.allCases.first { chapter in
            switch chapter {
            case .snippet:  return !tutorialSnippetDone
            case .template: return !tutorialTemplateDone
            case .combo:    return !tutorialComboDone
            }
        }
    }

    /// 앱을 껐다 켰는데 **가리키는 것이 없는 채로** 써 보는 차례에 서 있으면 이어 붙인다.
    ///
    /// ⚠️ 없으면 튜토리얼이 거기서 멈춘다. 장과 장 사이 5초 동안 앱을 끄면 가리키던 표식은
    ///    이미 비워졌고 다음 장은 아직 안 켜졌다 - 다시 열었을 때 아무 일도 안 일어난다.
    private func resumeTutorialIfStalled() {
        guard onboardingStep == .tryScenarios,
              highlightedMemoId == nil,
              comboStep == nil,
              !awaitingSend,
              countdownEndsAt == nil else { return }
        openNextChapter()
    }

    /// 환영 화면에서 "눌러볼게요" - 무대로 옮기고 첫 장을 연다.
    private func startTutorial() {
        withAnimation(.easeInOut(duration: 0.28)) {
            welcomeDone = true
            // 가리킨 키를 보려면 무대에 있어야 한다.
            styleRaw = SnippetsTabStyle.keyboard.rawValue
        }
        openNextChapter()
    }

    /// "나중에 볼게요" - 남은 장을 다 지난 것으로 두고 평소 화면으로.
    ///
    /// ⚠️ 개별 표식을 켜지 않고 `chaptersFinished` 만 켠다. 나중에 설정에서 다시 하기를
    ///    누르면 그 표식만 지우면 되므로, 건너뛴 사람과 다 해 본 사람의 길이 같아진다.
    private func skipTutorial() {
        withAnimation(.easeInOut(duration: 0.28)) {
            welcomeDone = true
            chaptersFinished = true
        }
    }

    /// 다음 장을 연다 - **가리킬 카드를 찾아 무대의 그 키에 불을 켠다.**
    ///
    /// ⚠️ 가리킬 것이 없으면(사용자가 그 종류를 지웠다면) 조용히 건너뛴다. 없는 카드를
    ///    가리키며 누르라고 하면 튜토리얼이 거기서 멈춘 것처럼 보인다.
    private func openNextChapter() {
        guard let chapter = nextChapter else {
            withAnimation(.easeInOut(duration: 0.28)) { chaptersFinished = true }
            return
        }
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        guard let memo = TutorialScenarios.memo(for: chapter, in: memos) else {
            print("⏭️ [SnippetsTab] \(chapter.rawValue) 장에 가리킬 것이 없어 건너뜁니다")
            markChapterDone(chapter)
            openNextChapter()
            return
        }
        withAnimation(.easeInOut(duration: 0.28)) {
            firstUseMemoIdRaw = memo.id.uuidString
            // 콤보만 장 안쪽에 걸음이 다섯이다 - 첫 걸음부터 연다.
            // (다른 장은 이 값이 늘 비어 있어야 하므로 여기서 확실히 비운다)
            comboStepRaw = chapter == .combo ? ComboTutorialStep.insertFirst.rawValue : ""
        }
    }

    /// 가리킨 키를 실제로 눌렀다 - **아직 끝이 아니다.** 보내기까지가 한 바퀴다.
    ///
    /// ⚠️ 아무 문구나 눌러도 끝난 것으로 치지 않는다. **그 문구**를 눌러야 한다
    ///    가리킨 것과 다른 걸 눌렀는데 안내가 사라지면 무엇 때문에 끝났는지 알 수 없다.
    ///
    /// ⚠️ 예전에는 여기서 0.9초를 기다렸다가 키의 불을 껐다. 그런데 템플릿은 누른 뒤에
    ///    **빈칸을 채우는 시트가 한 번 뜬다.** 채우고 '넣기'를 누르면 시트가 내려가고,
    ///    그 아래에서 키가 0.9초 동안 **다시 물결치다가** 꺼졌다. 다 끝난 걸음이
    ///    한 번 더 빛나니 "아직 저길 눌러야 하나" 로 읽혔다(사용자 보고).
    ///    이제 곧바로 끄고 곧바로 보내기로 옮겨 붙는다 - 물결은 늘 **다음에 할 곳**에만 있다.
    private func chapterKeyWasUsed(_ note: Notification) {
        guard let used = note.userInfo?[MemoUsedKey.memoID] as? UUID,
              used == highlightedMemoId,
              let chapter = nextChapter else { return }

        // 콤보 장은 넣는 걸음이 둘이라 따로 센다.
        if chapter == .combo {
            advanceComboStep(after: [.insertFirst, .insertSecond])
            return
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            firstUseMemoIdRaw = ""   // 키의 파형을 끈다
            awaitingSend = true      // 보내기 동그라미로 옮겨 붙는다
        }
    }

    /// 콤보 키의 오른쪽 → 를 눌러 다음 값으로 넘겼다.
    private func comboValueWasAdvanced(_ note: Notification) {
        guard let used = note.userInfo?["memoId"] as? UUID,
              used == highlightedMemoId else { return }
        advanceComboStep(after: [.advance])
    }

    /// 콤보 장의 걸음을 하나 넘긴다 - **지금 서 있는 걸음이 기다리던 것일 때만.**
    ///
    /// ⚠️ 어느 걸음에서 온 신호인지 확인하지 않으면 순서가 무너진다. 예를 들어 값을
    ///    넣으라고 한 자리에서 → 를 두 번 누르면, 확인 없이는 걸음이 둘 건너뛴다.
    private func advanceComboStep(after expected: [ComboTutorialStep]) {
        guard let step = comboStep, expected.contains(step) else { return }
        let following = step.next
        withAnimation(.easeInOut(duration: 0.28)) {
            // 물결은 걸음을 따라 옮겨 붙는다 - 어디를 누를지는 `comboPart` 가 정한다.
            comboStepRaw = following?.rawValue ?? ""
        }
        print("🎓 [SnippetsTab] 콤보 걸음 \(step.rawValue) → \(following?.rawValue ?? "끝")")
        if following == nil { finishComboChapter() }
    }

    /// "확인했어요" - 콤보 장이 여기서 끝난다. 다음은 직접 만들어 보는 걸음(+).
    private func finishComboChapter() {
        guard !tutorialComboDone else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            comboStepRaw = ""
            firstUseMemoIdRaw = ""
            awaitingSend = false
        }
        markChapterDone(.combo)
        scheduleNextChapter()
    }

    /// 보냈다 - 이제 이 장이 끝났다. 한 박자 쉬고 다음 장으로.
    private func finishChapterAfterSend() {
        // 콤보 장은 보내는 걸음이 둘이라, 보냈다고 장이 끝나지 않는다.
        if nextChapter == .combo {
            advanceComboStep(after: [.sendFirst, .sendSecond])
            return
        }
        guard awaitingSend, let chapter = nextChapter else { return }
        withAnimation(.easeInOut(duration: 0.28)) { awaitingSend = false }
        markChapterDone(chapter)
        // ⚠️ **무대에 그대로 머문다.** 화면을 옮기면 방금 익힌 자리가 사라져서
        //    배우던 흐름이 끊긴 것처럼 느껴진다. 다음 장은 이 화면 **위에서** 이어진다.
        //
        // ⚠️ 곧바로 다음 걸 켜지 않는다. 방금 한 바퀴를 돈 참인데 바로 다음이 빛나면
        //    그 장면을 음미할 틈이 없고, 배우는 게 아니라 떠밀리는 느낌이 된다.
        //    쉬는 동안은 카운트다운 원이 대신 말해 준다.
        scheduleNextChapter()
    }

    /// 장과 장 사이의 쉼. 남은 시간을 원으로 보여주고, 다 돌면 다음 장을 연다.
    ///
    /// ⚠️ 예전에는 곳마다 0.45~0.6초씩 제각각 기다렸다가 곧바로 다음 걸 띄웠다.
    ///    그 사이 화면은 아무 말도 안 해서 끝난 건지 멈춘 건지 알 수 없었다.
    ///    이제 **모든 장 사이가 같은 3초**이고, 그동안 원이 돈다.
    ///
    /// ⚠️ 예약을 `DispatchWorkItem` 으로 붙잡아 둔다. 눌러서 건너뛸 수 있게 되면서
    ///    (`skipBreather`) 취소할 손잡이가 필요해졌다 - 없으면 눌러서 한 번 열고
    ///    3초 뒤에 예약이 또 깨어나 **다음 장을 한 번 더** 연다.
    private func scheduleNextChapter() {
        guard nextChapter != nil else {
            openNextChapter()      // 더 없으면 곧바로 마무리한다 - 셀 이유가 없다.
            return
        }
        let gap = Self.chapterBreather
        countdownEndsAt = Date().addingTimeInterval(gap)
        let work = DispatchWorkItem { advanceAfterBreather() }
        breatherWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + gap, execute: work)
    }

    /// 쉼이 끝났다(혹은 눌러서 건너뛰었다) - 원을 거두고 다음 장을 연다.
    private func advanceAfterBreather() {
        guard countdownEndsAt != nil else { return }
        breatherWork?.cancel()
        breatherWork = nil
        withAnimation(.easeOut(duration: 0.2)) { countdownEndsAt = nil }
        openNextChapter()
    }

    // MARK: - 직접 만들어 보기

    /// 자기 것을 하나라도 갖고 있으면 이 걸음은 끝난 것이다.
    ///
    /// ⚠️ **어디서 만들었는지는 묻지 않는다.** 무대의 +, 목록의 +, 공유 시트, 스타터팩
    ///    어느 길로 들어왔든 자기 단축어가 생겼으면 배운 것이다. 특정 버튼을 누르게
    ///    강요하면 그건 배우는 것이 아니라 시키는 대로 하는 것이다.
    ///
    /// ⚠️ 심어 준 샘플은 자기 것이 아니다(`SampleMemoStorage`). 그걸 세면 첫 실행에
    ///    이미 넷을 갖고 있으므로 이 걸음이 열리자마자 닫힌다.
    private func completeMakeOwnIfMadeSomething() {
        guard onboardingStep == .makeOwn else { return }
        let seeded = SampleMemoStorage.load()
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        guard memos.contains(where: { !seeded.contains($0.id) }) else { return }
        finishMakeOwn()
    }

    /// 지금 목록이 진짜로 보이는 화면인지 팁 쪽에 알려 준다.
    ///
    /// ⚠️ **재우는 것은 지금, 깨우는 것은 나중.** 팁이 깨어나면 TipKit 이 팝오버를
    ///    띄우는데, 그게 무대가 내려가는 도중에 일어나면 미끄러지는 마지막 순간에
    ///    화면이 한 번 걸린다. 무대가 다 내려간 뒤에 깨운다.
    ///    (재우는 쪽은 급하다 - 늦으면 무대 위에 팝오버가 떠 버린다)
    private func syncListVisibilityForTips() {
        let listVisible = (style == .list)
        guard listVisible else {
            AddMemoTip.listIsVisible = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.swapSettleDelay) {
            // 그 사이에 다시 무대로 갔으면 깨우지 않는다.
            guard style == .list else { return }
            AddMemoTip.listIsVisible = true
        }
    }

    /// 화면이 다 바뀌고 나서 뒷일을 하기까지 기다리는 시간(초).
    /// 미끄러지는 동안 무거운 일이 끼면 그 프레임에서 화면이 걸린다.
    static let swapSettleDelay: Double = 0.45

    /// 튜토리얼이 끝난 **시각과 실행 횟수**를 남긴다.
    ///
    /// ⚠️ 무대의 키보드 켜기 띠가 이 둘을 본다(`KeyboardSetupBannerGate`). 방금 자기
    ///    단축어를 만들고 "다 했다" 하는 자리에서 곧바로 "아직 못 쓴다"가 뜨면,
    ///    방금 한 일이 헛일이었다는 말로 읽힌다. 한 호흡 쉬고 말하려고 여기서 재 둔다.
    ///
    /// ⚠️ **한 번만 남긴다.** 다시 쓰면 띠가 뜰 시각이 계속 뒤로 밀려 영영 안 뜬다.
    private func markTutorialFinishedIfNeeded() {
        guard startedFresh, onboardingStep == .done, tutorialFinishedAt == 0 else { return }
        tutorialFinishedAt = Date().timeIntervalSince1970
        tutorialFinishedAtLaunch = UserDefaults.standard.integer(forKey: DefaultsKey.appLaunchCount)
        print("🎓 [SnippetsTab] 튜토리얼 종료 시각 기록 (실행 \(tutorialFinishedAtLaunch)회차)")
    }

    /// 만들었든 미뤘든 이 걸음을 지난 것으로 둔다.
    private func finishMakeOwn() {
        guard !makeOwnDone else { return }
        withAnimation(.easeInOut(duration: 0.28)) { makeOwnDone = true }
        print("🎓 [SnippetsTab] 직접 만들기 걸음 종료")
    }

    // MARK: - "혹시 이런 분이신가요?"

    /// 써 볼 만큼 써 봤으면 그때 한 번 묻는다.
    ///
    /// ⚠️ 다른 판이 이미 떠 있으면 **비켜 있는다.** 판이 둘 겹치면 하나는 아예 안 보이거나
    ///    (iOS 가 나중 것을 무시한다) 답한 것이 엉뚱한 판으로 간다. 다음 기회에 다시 본다
    ///    - 이 함수는 화면에 들어올 때마다, 단축어가 바뀔 때마다 불린다.
    ///
    /// ⚠️ 카테고리는 **사용자가 직접 만든 것만** 센다. 기본 제공(타입별 모아보기)은
    ///    켜기만 하면 생기는 것이라 "이 사람이 무엇을 모으려 하는가" 를 말해 주지 않는다.
    private func askPersonaIfEarned() {
        guard !showPersonaPrompt, !showOffer, !showSampleCleanup else { return }
        let snippets = (try? MemoStore.shared.load(type: .memo))?.count ?? 0
        guard PersonaPrompt.shouldAsk(snippetCount: snippets,
                                      customCategoryCount: CategoryStore.shared.allCategories.count,
                                      tutorialDone: onboardingStep == .done) else { return }
        showPersonaPrompt = true
    }

    // MARK: - 연습용 단축어 치우기

    /// 다 지나고 나면 **한 번만** 묻는다.
    ///
    /// ⚠️ 묻는 자리를 여기 둔 이유: 자기 것을 만들기 전에 물으면 "치우기"를 고른 사람의
    ///    화면이 텅 빈다. 만들고 난 뒤라야 치워도 남는 것이 있다.
    ///
    /// ⚠️ 답이 무엇이든 다시 묻지 않는다. 지울지 말지는 한 번 고르면 그만인 일이고,
    ///    남겨 둔 사람에게 되풀이해 물으면 그건 묻는 게 아니라 재촉하는 것이다.
    ///    (나중에 마음이 바뀌면 목록에서 그냥 지우면 된다)
    private func askToCleanUpSamplesIfNeeded() {
        guard startedFresh, onboardingStep == .done, !sampleCleanupAsked else { return }
        guard !SampleMemoStorage.load().isEmpty else {
            sampleCleanupAsked = true   // 이미 지운 사람에게 물을 것이 없다
            return
        }
        sampleCleanupAsked = true
        // 화면이 자리를 잡은 뒤에 - 마지막 걸음이 끝나는 순간에 겹쳐 뜨면 무엇에 대한 물음인지 안 보인다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showSampleCleanup = true
        }
    }

    /// 심어 준 것만 지운다 - 사용자가 만든 것은 건드리지 않는다.
    private func deleteSampleMemos() {
        let sampleIds = SampleMemoStorage.load()
        guard !sampleIds.isEmpty else { return }
        do {
            let all = try MemoStore.shared.load(type: .memo)
            try MemoStore.shared.save(memos: all.filter { !sampleIds.contains($0.id) }, type: .memo)
            SampleMemoStorage.clear()
            MemoStore.postDataChanged()
            print("🗑️ [SnippetsTab] 연습용 단축어 \(sampleIds.count)개 정리")
        } catch {
            print("❌ [SnippetsTab.deleteSampleMemos] 실패: \(error)")
        }
    }

    private func markChapterDone(_ chapter: TutorialChapter) {
        switch chapter {
        case .snippet:  tutorialSnippetDone = true
        case .template: tutorialTemplateDone = true
        case .combo:    tutorialComboDone = true
        }
    }

    /// 쓰던 사람에게 **한 번만** 권한다.
    ///
    /// 새 설치는 이미 무대로 시작하므로 권할 일이 없고, 한 번 권한 뒤에는
    /// 고르든 넘기든 다시 묻지 않는다. 설정에 자리가 있으므로 언제든 바꿀 수 있다.
    private func offerKeyboardStageIfNeeded() {
        guard !offered, style == .list else { return }
        offered = true
        // 화면이 자리를 잡은 뒤에 - 열자마자 알림이 뜨면 무엇에 대한 물음인지 안 보인다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showOffer = true
        }
    }
}

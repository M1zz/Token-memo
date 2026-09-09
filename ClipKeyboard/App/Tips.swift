import TipKit
import SwiftUI

// MARK: - 팁을 건네는 얼굴
//
// 팁은 TipKit 기본 모양을 쓴다.
//
// ⚠️ 팁 그림은 전부 마스코트다. 예전에는 팁마다 다른 SF 기호였는데, 기호는 내용을
//    설명하지만 정작 **누가 말하고 있는지**는 매번 달라졌다.

// MARK: - 팁이 뜨고 사라지는 모습

/// 팁을 **닫기(X) 자리에서** 늘어났다가 그 자리로 줄어들게 감싼다.
///
/// 왜 감싸는가: `TipView` 는 팁이 무효화되면 스스로 내용을 비운다. 뷰는 그대로 있고
/// 안이 비는 것이라 SwiftUI 가 보기에는 **넣고 빼는 일이 없어** 전이가 걸리지 않는다.
/// 그래서 팁은 늘 툭 나타났다 툭 사라졌다.
///
/// 여기서는 팁의 상태를 직접 듣고(`statusUpdates`) 우리가 넣고 뺀다. 그래야 전이가 산다.
///
/// ⚠️ 애니메이션을 `withAnimation` 이 아니라 `.animation(_:value:)` 으로 건다.
///    목록 화면은 처음 1초 동안 암묵 애니메이션을 통째로 끄는데
///    (`ClipKeyboardList` 의 `settling`), `withAnimation` 은 그 규칙에 걸려 죽는다.
///    팁이 사라지는 것은 **사용자가 X 를 누른 결과**라 언제나 보여야 한다.
///
/// 자리가 위-오른쪽인 이유는 `TipView` 의 닫기 단추가 거기 있기 때문이다.
/// 오른쪽에서 왼쪽으로 읽는 언어에서는 `.topTrailing` 이 알아서 반대편이 된다.
extension AnyTransition {
    /// 닫기(X) 자리에서 늘어났다 줄어드는 몸짓.
    ///
    /// 팁과 배너가 **같은 몸짓**을 쓴다. 둘 다 "줄 하나가 얹혔다가 사용자가 X 를 눌러
    /// 걷어내는 것" 이라, 사라지는 모양이 다르면 같은 종류로 안 읽힌다.
    ///
    /// 배율이 0 이 아니라 0.02 인 것은, 0 에서는 크기가 없어 어느 자리에서 줄어드는지가
    /// 안 보이기 때문이다. 오른쪽에서 왼쪽으로 읽는 언어에서는 `.topTrailing` 이
    /// 알아서 반대편이 된다.
    static var closeButtonAnchored: AnyTransition {
        .scale(scale: 0.02, anchor: .topTrailing).combined(with: .opacity)
    }
}

/// 닫을 수 있는 줄(배너)을 감싼다. 사라질 때 X 자리로 줄어든다.
///
/// ⚠️ **빈 `VStack` 을 그릇으로 둔다.** `Group` 이나 맨 `if` 로 두면 안 된다.
///    이 줄들은 페이지의 `LazyVStack` 안에 사는데, 조건이 거짓이 되는 순간 게으른 스택이
///    행을 그냥 걷어내 버려서 전이가 걸릴 자리가 없다. 크기 0 인 그릇이 남아 있어야
///    SwiftUI 가 "여기 있던 것이 사라진다"를 알아본다.
///
/// ⚠️ 애니메이션을 `withAnimation` 이 아니라 `.animation(_:value:)` 으로 건다.
///    목록 화면은 처음 1초 동안 암묵 애니메이션을 통째로 끄는데(`settling`),
///    `withAnimation` 은 그 규칙에 걸려 죽는다. 닫는 것은 사용자가 X 를 누른 결과라
///    언제나 보여야 한다.
struct DismissibleRow<Content: View>: View {
    let isShowing: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if isShowing {
                content().transition(.closeButtonAnchored)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isShowing)
    }
}

struct AnimatedTip<T: Tip, Content: View>: View {
    let tip: T
    @ViewBuilder let content: () -> Content

    @State private var isShowing = false

    var body: some View {
        // ⚠️ `Group` 을 쓰면 안 된다. `Group` 은 모디파이어를 **자식마다** 붙이는데,
        //    팁이 아직 안 보이는 동안에는 자식이 없어서 아래 `.task` 가 붙을 곳이 없다.
        //    그러면 상태를 구독하지 못하고, 구독을 못 하니 영영 보이지 않는다.
        //    (실제로 그렇게 만들었다가 팁이 통째로 사라졌다)
        //    자식이 없어도 남아 있는 그릇이 필요하다. 빈 `VStack` 은 크기가 0 이라
        //    레이아웃에 아무 자국도 남기지 않는다.
        VStack(spacing: 0) {
            if isShowing {
                content().transition(.closeButtonAnchored)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isShowing)
        .task {
            // 팁의 상태를 계속 듣는다. 다시 조건이 맞아 떠야 할 때도 같은 흐름으로 온다.
            for await status in tip.statusUpdates {
                isShowing = (status == .available)
            }
        }
    }
}

// MARK: - WelcomeTip

struct WelcomeTip: Tip {
    var title: Text {
        Text(NSLocalizedString("탭하면 바로 복사돼요", comment: "Welcome tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("단축어를 탭해보세요. 클립보드에 바로 복사돼요.", comment: "Welcome tip message"))
    }
}

// MARK: - AddMemoTip

/// ⚠️ 이 팁만 `popoverTip` 이라 **화면 밖으로 튀어나온다.** 나머지 팁은 목록 안에
///    줄로 얹혀 있어 무대가 올라오면 같이 가려지는데, 팝오버는 창 위에 그려져
///    무대의 안내 띠까지 덮었다(실측: "이 탭에는 화면이 둘이에요"가 통째로 가려짐).
///    목록이 뒤에 깔려만 있을 때는 뜨지 않게 규칙을 하나 더 둔다.
struct AddMemoTip: Tip {
    @Parameter
    static var welcomeTipInvalidated: Bool = false

    /// 목록이 **지금 보이는 화면**인가. 무대가 위에 올라와 있으면 목록은 뒤에 깔려만
    /// 있고, 거기 붙은 팝오버가 뜨면 무대 위 안내를 덮는다.
    @Parameter
    static var listIsVisible: Bool = true

    var title: Text {
        Text(NSLocalizedString("내 것을 저장해보세요", comment: "Add memo tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("+ 버튼으로 자주 쓰는 텍스트를 저장할 수 있어요.", comment: "Add memo tip message"))
    }

    var rules: [Rule] {
        #Rule(Self.$welcomeTipInvalidated) { $0 == true }
        #Rule(Self.$listIsVisible) { $0 == true }
    }
}

// MARK: - KeyboardTip

struct KeyboardTip: Tip {
    @Parameter
    static var hasCopiedMemo: Bool = false

    var title: Text {
        Text(NSLocalizedString("키보드에서도 쓸 수 있어요", comment: "Keyboard tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("ClipKeyboard 키보드를 활성화하면 어디서든 바로 입력돼요.", comment: "Keyboard tip message"))
    }

    var rules: [Rule] {
        #Rule(Self.$hasCopiedMemo) { $0 == true }
    }

    var actions: [Action] {
        [Action(id: "setup", title: NSLocalizedString("키보드 설정하기", comment: "Tip action: set up keyboard"))]
    }
}

// MARK: - CleanUpSamplesTip


// MARK: - ComboInfoTip
// 콤보 메모를 탭해서 ComboEditSheet를 처음 열었을 때 동작 방식을 설명.

struct ComboInfoTip: Tip {
    var title: Text {
        Text(NSLocalizedString("Combo는 이렇게 동작해요", comment: "Combo info tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("탭할 때마다 저장된 값이 순서대로 하나씩 입력돼요. 키보드에서 이어서 다음 값을 넣을 수 있어요.", comment: "Combo info tip message"))
    }
}

// MARK: - TemplateInfoTip
// 템플릿 메모를 탭해서 TemplateEditSheet를 처음 열었을 때 채우는 방법을 설명.

struct TemplateInfoTip: Tip {
    var title: Text {
        Text(NSLocalizedString("템플릿은 이렇게 채워요", comment: "Template info tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("강조된 칸만 채우면 나머지 문장은 그대로 완성돼요. 자주 쓰는 양식을 빠르게 입력하세요.", comment: "Template info tip message"))
    }
}

// MARK: - AttachedTemplateTip
// 메모+템플릿(attachedTemplate) 입력 시트 상단 설명.

struct AttachedTemplateTip: Tip {
    var title: Text {
        Text(NSLocalizedString("단축어 + 템플릿", comment: "Memo plus template header"))
    }
    var message: Text? {
        Text(NSLocalizedString("이 단축어에 템플릿이 연결돼 있어요. 빈칸을 채우면 단축어 내용과 합쳐서 복사돼요. 아래 '입력될 결과'에서 미리 볼 수 있어요.", comment: "Attached template explanation"))
    }
}

// MARK: - QuickNoteInboxTip
// 빠른 메모(Inbox) 캡처를 가르치는 팁. 앱을 어느 정도 써본(engaged) 사용자에게,
// "어디서든 담아 보관함에 모인다"는 외부 캡처 진입점을 자연스럽게 안내한다.
// 더보기(⋯) 메뉴 버튼에 popoverTip으로 부착된다.

struct QuickNoteInboxTip: Tip {
    @Parameter
    static var engaged: Bool = false

    var title: Text {
        Text(NSLocalizedString("어디서든 빠르게 담으세요", comment: "Quick note inbox tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("공유 시트·단축어·제어 센터로 담은 항목은 ⋯ 메뉴의 보관함에 모여요. 나중에 키보드 단축어로 저장하면 돼요.", comment: "Quick note inbox tip message"))
    }

    var rules: [Rule] {
        #Rule(Self.$engaged) { $0 == true }
    }
}

// MARK: - Sample UUID Storage

/// 온보딩이 심어 준 샘플 단축어의 id 를 적어 두는 곳.
///
/// ⚠️ **App Group 에 적는다.** 이 표를 보고 한도가 "자기 것" 을 센다
/// (`ProFeatureManager.ownMemoCount`). 앱만 볼 수 있는 자리에 두면 키보드는
/// 심어 준 것과 만든 것을 구분하지 못해, 같은 화면에서 남은 칸을 다르게 말한다.
enum SampleMemoStorage {
    private static let key = DefaultsKey.sampleMemoIdsV1

    /// 표준 UserDefaults 에 적던 시절의 자리. 옮겨 오기 위해서만 읽는다.
    private static let legacyKey = "sampleMemoUUIDs_v1"

    static func save(ids: [UUID]) {
        AppGroup.defaults?.set(ids.map { $0.uuidString }, forKey: key)
    }

    /// 두 자리를 **합쳐서** 읽는다. 한 번 샘플이었던 것은 계속 샘플이다.
    ///
    /// 옮겨 오기 전에 앱이 먼저 물어볼 수 있어서, 읽는 쪽에서도 옛 자리를 같이 본다.
    /// (옮기는 일 자체는 `migrateToAppGroupIfNeeded` 가 한 번만 한다)
    static func load() -> Set<UUID> {
        let current = AppGroup.defaults?.stringArray(forKey: key) ?? []
        let legacy = UserDefaults.standard.stringArray(forKey: legacyKey) ?? []
        return Set((current + legacy).compactMap { UUID(uuidString: $0) })
    }

    /// 옛 자리에 있던 샘플 id 를 App Group 으로 옮긴다.
    ///
    /// 이걸 안 하면 이미 쓰고 있던 사람의 샘플이 전부 "자기 것" 으로 세어져,
    /// 늘려 주려던 칸이 도리어 줄어든다.
    static func migrateToAppGroupIfNeeded() {
        let legacy = UserDefaults.standard.stringArray(forKey: legacyKey) ?? []
        guard !legacy.isEmpty else { return }
        let merged = Set((AppGroup.defaults?.stringArray(forKey: key) ?? []) + legacy)
        guard merged.count != (AppGroup.defaults?.stringArray(forKey: key) ?? []).count else { return }
        AppGroup.defaults?.set(Array(merged), forKey: key)
        print("🔄 [SampleMemoStorage] 샘플 id \(merged.count)개를 App Group 으로 옮김")
    }

    static func clear() {
        AppGroup.defaults?.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }
}

//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI
import UIKit
import CryptoKit
import LeeoKit

/// 지구본 키의 **손잡이**. 그림은 SwiftUI 가 그리고, 손가락은 이 투명 버튼이 받는다.
///
/// ## 왜 SwiftUI Button 으로는 안 되나
///
/// 예전 지구본은 SwiftUI Button 에서 `advanceToNextInputMode()` 를 불렀다.
/// 그런데 그 API 는 **글자 키보드만** 순서대로 돈다. 이모지 키보드는 그 회전에
/// 끼지 않아서, 타사 키보드를 함께 쓰는 사람은 지구본을 몇 번을 눌러도 이모지에
/// 닿지 못했다(사용자 제보: "타사 키보드와 함께 사용 시 이모지로 변경이 되질 않네요").
/// 키보드가 하나뿐인 사람에게는 멀쩡해 보여서 더 늦게 드러난 종류의 버그다.
///
/// 시스템 지구본과 **같은 물건**은 `handleInputModeList(from:with:)` 하나뿐이다.
/// 탭이면 다음 키보드로 넘기고, 길게 누르면 이모지가 들어 있는 키보드 목록을 띄운다.
/// 이건 UIControl 의 터치 이벤트를 통째로(`.allTouchEvents`) 받아야 동작하므로
/// SwiftUI 제스처로는 흉내 낼 수 없다. 그래서 UIKit 버튼을 얹는다.
///
/// 배경은 투명하다 - 키캡 모양·색·코너는 아래 SwiftUI 뷰가 그대로 그린다.
private struct InputModeSwitchOverlay: UIViewRepresentable {
    let proxy: TypingInputProxy

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.isAccessibilityElement = true
        button.accessibilityLabel = NSLocalizedString("다음 키보드", comment: "Next keyboard button")
        button.accessibilityHint = NSLocalizedString(
            "길게 누르면 이모지를 포함한 키보드 목록이 열립니다",
            comment: "Hint for the globe key: long press opens the keyboard list including emoji")
        proxy.attachInputModeSwitch(to: button)
        // 햅틱은 우리 몫이다. 시스템은 전환만 하고 손맛은 주지 않는다.
        // 다른 키캡과 같은 순간(누르는 순간)에 울려야 줄이 따로 놀지 않는다.
        button.addTarget(context.coordinator,
                         action: #selector(Coordinator.pressed),
                         for: .touchDown)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        @objc func pressed() { KeyboardHaptics.tap() }
    }
}

var showOnlyTemplates: Bool = false
var showOnlyFavorites: Bool = false
var selectedTheme: String?  // 선택된 테마 필터

// 미리 정의된 값들 저장소 - 새로운 구조 사용
class PredefinedValuesStore {
    static let shared = PredefinedValuesStore()

    // PlaceholderValue 모델 (키보드 전용 - 메인 앱의 PlaceholderValue와 같은 구조)
    private struct KeyboardPlaceholderValue: Codable {
        var id: UUID
        var value: String
        var sourceMemoId: UUID
        var sourceMemoTitle: String
        var addedAt: Date
    }

    // UserDefaults에서 불러오기 (새로운 구조)
    func getValues(for placeholder: String) -> [String] {
        print("🔍 [PredefinedValuesStore] getValues 호출 - placeholder: \(placeholder)")
        let key = "placeholder_values_\(placeholder)"
        print("   Key: \(key)")

        // 새로운 형식으로 로드 시도
        if let data = AppGroup.defaults?.data(forKey: key) {
            print("   ✅ 데이터 발견 - 크기: \(data.count) bytes")

            if let placeholderValues = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) {
                let values = placeholderValues.map { $0.value }
                print("   ✅ 디코딩 성공 - \(values.count)개 값: \(values)")
                return values
            } else {
                print("   ❌ 디코딩 실패")
            }
        } else {
            print("   ⚠️ 새 형식 데이터 없음")
        }

        // 이전 형식 호환성 (마이그레이션)
        let oldKey = "predefined_\(placeholder)"
        print("   🔄 이전 형식 시도 - Key: \(oldKey)")

        if let saved = AppGroup.defaults?.stringArray(forKey: oldKey) {
            print("   ✅ 이전 형식에서 로드 - \(saved.count)개 값: \(saved)")
            return saved
        } else {
            print("   ⚠️ 이전 형식 데이터도 없음")
        }

        // 데이터가 없으면 빈 배열 반환
        print("   📭 데이터 없음 - 빈 배열 반환")
        return []
    }

    /// 값을 하나 **적어 넣는다.** 앱 쪽 `MemoStore.addPlaceholderValue` 와 같은 자리·같은 형식.
    ///
    /// ⚠️ 두 타깃이 같은 파일을 보므로 여기 하나만 있으면 된다. 형식이 갈리면 한쪽이 쓴 값을
    ///    다른 쪽이 못 읽는다 - `KeyboardPlaceholderValue` 는 앱의 `PlaceholderValue` 와
    ///    필드 이름까지 같아야 한다(그래서 같은 JSON 을 주고받는다).
    ///
    /// ⚠️ 같은 값이 이미 있으면 **맨 앞으로 끌어올린다.** 두 번 적히면 고를 때 같은 칩이
    ///    두 개 보인다.
    @discardableResult
    func addValue(_ value: String,
                  for placeholder: String,
                  sourceMemoId: UUID?,
                  sourceMemoTitle: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let defaults = AppGroup.defaults else { return false }

        let key = "placeholder_values_\(placeholder)"
        var values: [KeyboardPlaceholderValue] = []
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) {
            values = decoded
        }
        values.removeAll { $0.value == trimmed }
        values.insert(KeyboardPlaceholderValue(id: UUID(),
                                               value: trimmed,
                                               sourceMemoId: sourceMemoId ?? UUID(),
                                               sourceMemoTitle: sourceMemoTitle,
                                               addedAt: Date()),
                      at: 0)
        guard let data = try? JSONEncoder().encode(values) else { return false }
        defaults.set(data, forKey: key)
        print("✅ [PredefinedValuesStore] '\(placeholder)' 에 값 추가: \(trimmed)")
        return true
    }

    // 특정 템플릿에서 쓸 값
    //
    // ⚠️ **공용 저장소(`placeholder_values_{이름}`)를 먼저 본다.** 값은 이름으로 묶이고,
    //    앱의 빈칸 관리·입력 화면이 손대는 곳도 거기다. 예전에는 단축어에 붙은 사본
    //    (`Memo.placeholderValues`)을 먼저 봤는데, 그래서 **앱에서 지운 값이 키보드에는
    //    그대로 남았다.** 지운 것이 다시 나오는 것만큼 못 미더운 일이 없다.
    //
    //    단축어에 붙은 사본은 **옛 데이터를 위한 폴백**으로만 남긴다. 공용 저장소가 비어 있을
    //    때만 쓴다(4.4 이전에 만든 템플릿, 그리고 맥이 쓴 데이터가 여기 해당한다).
    func getValuesForTemplate(placeholder: String, templateId: UUID?) -> [String] {
        print("\n🔍 [PredefinedValuesStore] getValuesForTemplate 호출")
        print("   플레이스홀더: \(placeholder), 템플릿 ID: \(templateId?.uuidString ?? "nil")")
        logClipMemosState()

        let shared = getValuesFromUserDefaults(placeholder: placeholder, templateId: templateId)
        if !shared.isEmpty {
            return shared
        }
        if let legacy = getValuesFromMemos(placeholder: placeholder, templateId: templateId) {
            print("   ↩️ 공용 저장소가 비어 단축어에 붙은 옛 값을 쓴다")
            return legacy
        }
        return []
    }

    /// clipMemos 배열 상태 디버그 출력
    private func logClipMemosState() {
        print("   📚 clipMemos 배열: \(clipMemos.count)개")
        for (index, memo) in clipMemos.enumerated() {
            print("      [\(index)] ID: \(memo.id.uuidString), 제목: \(memo.title)")
            for (key, vals) in memo.placeholderValues {
                print("              \(key): \(vals)")
            }
        }
    }

    /// Memo 객체에서 플레이스홀더 값 조회
    private func getValuesFromMemos(placeholder: String, templateId: UUID?) -> [String]? {
        guard let templateId else {
            print("   ⚠️ templateId가 nil입니다")
            return nil
        }
        print("   🔎 템플릿 ID로 검색 중: \(templateId.uuidString)")
        guard let memo = clipMemos.first(where: { $0.id == templateId }) else {
            print("   ❌ templateId로 Memo를 찾을 수 없음: \(templateId.uuidString)")
            clipMemos.forEach { print("         - \($0.id.uuidString) (\($0.title))") }
            return nil
        }
        print("   ✅ Memo 객체에서 찾음: \(memo.title)")
        if let values = memo.placeholderValues[placeholder], !values.isEmpty {
            print("   ✅ Memo에 저장된 값 발견: \(values)")
            return values
        }
        print("   ⚠️ Memo에 '\(placeholder)' 값 없음, 사용 가능한 키: \(memo.placeholderValues.keys)")
        return nil
    }

    /// UserDefaults에서 플레이스홀더 값 조회
    private func getValuesFromUserDefaults(placeholder: String, templateId: UUID?) -> [String] {
        let key = "placeholder_values_\(placeholder)"
        print("   🔍 UserDefaults 확인 - Key: \(key)")
        guard let userDefaults = AppGroup.defaults,
              let data = userDefaults.data(forKey: key),
              let placeholderValues = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) else {
            print("   ⚠️ 저장된 플레이스홀더 값 없음 - iOS 앱에서 값을 추가하세요")
            return []
        }
        print("   ✅ UserDefaults에서 디코딩 성공 - 총 \(placeholderValues.count)개")
        if let templateId {
            let filtered = placeholderValues.filter { $0.sourceMemoId == templateId }
            print("   📊 템플릿 ID로 필터링: \(filtered.count)개")
            if !filtered.isEmpty { return filtered.map { $0.value } }
        }
        let allValues = placeholderValues.map { $0.value }
        print("   ℹ️ 전체 값 반환: \(allValues)")
        return allValues
    }

}

// 템플릿 입력 상태 관리
class TemplateInputState: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var placeholders: [String] = []
    @Published var inputs: [String: String] = [:]
    @Published var originalText: String = ""
    @Published var currentFocusedPlaceholder: String?
    @Published var allPlaceholdersFilled: Bool = false
    @Published var templateId: UUID?  // 현재 편집 중인 템플릿 ID
    /// v4.0.8: attachedTemplate 흐름에서 본 메모(계좌번호 등)의 ID. nil이면 일반 템플릿 흐름.
    @Published var baseMemoId: UUID?
    /// v4.0.8: 본 메모 본문 - preview 표시용으로 매번 MemoStore 조회 안 하도록 캐싱.
    @Published var baseMemoValue: String = ""

    func updateAllPlaceholdersFilled() {
        allPlaceholdersFilled = !inputs.values.contains(where: { $0.isEmpty })
    }

    /// **다음에 채울 칸.** 한 칸만 펼쳐 보여줄 때 어디를 펼칠지 정한다.
    ///
    /// 규칙은 하나다: 아직 안 채운 칸 중 `after` 다음 것. 뒤에 없으면 앞으로 돌아가 찾고,
    /// 다 채웠으면 nil (그때는 아무것도 펼치지 않고 입력하기만 남는다).
    ///
    /// ⚠️ 순서대로만 가지 않는다. 사람이 셋째 칸을 먼저 눌러 채울 수 있고, 그 다음은
    ///    넷째가 아니라 **아직 빈 첫째** 여야 한다. 순서대로만 가면 건너뛴 칸이
    ///    영영 안 펼쳐지고, 사용자는 왜 입력하기가 안 눌리는지 모른 채 남는다.
    static func nextUnfilled(in placeholders: [String],
                             inputs: [String: String],
                             after current: String?) -> String? {
        guard !placeholders.isEmpty else { return nil }
        let isEmpty: (String) -> Bool = { (inputs[$0] ?? "").isEmpty }
        guard let start = current.flatMap({ placeholders.firstIndex(of: $0) }) else {
            return placeholders.first(where: isEmpty)
        }
        let after = placeholders[(start + 1)...]
        let before = placeholders[..<start]
        return after.first(where: isEmpty) ?? before.first(where: isEmpty)
    }

    /// 현재 입력값 기준 결합 미리보기. baseMemoValue가 있으면 결합 형태, 없으면 치환 결과.
    var previewText: String {
        let resolvedTemplate = TemplateVariableProcessor.substitute(originalText, with: inputs)
        if baseMemoValue.isEmpty {
            return resolvedTemplate
        }
        return baseMemoValue + "\n" + resolvedTemplate
    }
}

struct KeyboardView: View {

    @AppStorage("keyboardColumnCount", store: AppGroup.defaults) private var keyboardColumnCount: Int = 2
    @AppStorage("keyboardButtonHeight", store: AppGroup.defaults) private var buttonHeight: Double = 44.0
    @AppStorage("keyboardButtonFontSize", store: AppGroup.defaults) private var buttonFontSize: Double = 17.0

    // 색상 커스터마이즈 - 기본은 false (Paper 테마 사용), true면 hex 오버라이드
    @AppStorage("keyboardUseCustomColors", store: AppGroup.defaults) private var useCustomColors: Bool = false
    @AppStorage("keyboardCustomBgHex", store: AppGroup.defaults) private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: AppGroup.defaults) private var customKeyHex: String = ""
    /// 키캡 물성 프리셋 - 색이 아니라 두께·빛·모서리·눌림만 정한다.
    @AppStorage(DefaultsKey.keyboardSkin, store: AppGroup.defaults)
    private var keyboardSkinRaw: String = KeyboardSkin.classic.rawValue
    /// 단축어 줄을 악어 입속처럼 - 켜면 키가 송곳니가 되고 그 위에 잇몸이 얹힌다.
    /// 콤보 키캡의 눌림 표현에 쓴다(개별 키는 KeycapButtonStyle이 각자 읽는다).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 옵션 토글 - 기본 OFF로 화면 공간 확보
    @AppStorage("keyboardShowSearch", store: AppGroup.defaults) private var showSearchBar: Bool = false
    @AppStorage("keyboardShowRecent", store: AppGroup.defaults) private var showRecentSection: Bool = false
    /// 위줄에 리턴(보내기) 키를 세울지. 잘못 눌러 보내는 것이 무서운 사람은 끌 수 있다.
    /// 기본은 켬 - 없어서 못 보내던 것이 신고로 들어온 쪽이라, 꺼 둔 채로 두면 고친 것이 아니다.
    @AppStorage(DefaultsKey.keyboardShowReturnKey, store: AppGroup.defaults) private var showReturnKey: Bool = true
    // 한국어 입력 사용 여부(기본 OFF). 꺼져 있으면 한/EN 토글과 한글 자판이 아예 노출되지 않아
    // 영어 전용 사용자는 한글을 볼 일이 없다. 한국어 사용자가 설정에서 직접 켠다.
    @AppStorage("keyboardKoreanEnabled", store: AppGroup.defaults) private var koreanInputEnabled: Bool = false
    @AppStorage("keyboardTypingLang", store: AppGroup.defaults) private var defaultTypingLang: String = "english"
    /// 메모 구분 표시 마스터 토글(메인 앱과 공유). 기본 OFF = 키도 심플(타입 테두리·카테고리 틴트 숨김).
    @AppStorage("showVisualCues", store: AppGroup.defaults) private var showVisualCues: Bool = false
    /// 메모 내용 힌트(메인 앱과 공유, 기본 ON) - 키보드에서는 셀이 2초 머물면
    /// 제목이 잠시 내용으로 바뀌었다가 돌아온다(공간이 좁아 제목 자리를 빌리는 방식).
    /// ⚠️ 기본값은 앱과 **같아야** 한다(꺼짐). 같은 App Group 키인데 기본값이 다르면
    ///    토글을 만진 적 없는 사람에게 앱에서는 안 보이고 키보드에서만 보인다.
    @AppStorage(DefaultsKey.contentHintEnabled, store: AppGroup.defaults) private var contentHintEnabled: Bool = false

    /// 메모 구분 장치 노출 여부 - 오직 설정 "메모 구분 표시" 토글만 따른다
    /// (iOS "색상 없이 구별"과 무관, 앱과 동일 정책).
    private var visualCuesVisible: Bool { showVisualCues }

    /// KeyboardViewController가 init으로 주입 (let - SwiftUI 재렌더에도 유지)
    let typingProxy: TypingInputProxy?

    /// 호스트 텍스트 필드 상태 - clearAll(X) 버튼은 hasText일 때만 노출.
    /// nil이면 (preview 등) 항상 표시.
    @ObservedObject var documentState: KeyboardDocumentState

    /// 누가 이 키보드를 띄우고 있는가 - 앱 안이면 키마다 복사 버튼이 하나 더 붙는다.
    let hostKind: KeyboardHostKind

    /// 지금 **눌러 보라고 가리키는** 키. 튜토리얼에서 방금 만든 문구다.
    /// nil이면 아무것도 가리키지 않는다(평소).
    let highlightedMemoId: UUID?

    /// 가리키는 키가 콤보라면 **그 키의 어느 쪽**을 가리키는가.
    ///
    /// ⚠️ nil 이면 키캡 전체가 인다(콤보가 아닌 보통 키의 평소 모습). 콤보 키는 좌·우가
    ///    하는 일이 달라서, 통째로 빛나면 "어디를 누르라는 거지"가 된다 - 실제로 콤보
    ///    튜토리얼에서 사람들이 오른쪽 → 를 못 찾았다.
    let highlightedComboPart: ComboKeyPart?

    /// 콤보 키의 두 쪽. 왼쪽은 값을 넣고, 오른쪽은 다음 값으로 넘긴다.
    enum ComboKeyPart: String, Equatable {
        /// 왼쪽 2/3 - 지금 값을 입력창에 넣는다.
        case value
        /// 오른쪽 1/3 - 다음 값으로 넘긴다(글은 안 들어간다).
        case next
    }

    init(typingProxy: TypingInputProxy? = nil,
         documentState: KeyboardDocumentState = KeyboardDocumentState(),
         hostKind: KeyboardHostKind = .keyboardExtension,
         highlightedMemoId: UUID? = nil,
         highlightedComboPart: ComboKeyPart? = nil) {
        self.typingProxy = typingProxy
        self.documentState = documentState
        self.hostKind = hostKind
        self.highlightedMemoId = highlightedMemoId
        self.highlightedComboPart = highlightedComboPart
    }

    // 동적 그리드 레이아웃 (열 개수에 따라 변경)
    private var gridItemLayout: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, min(5, keyboardColumnCount)))
    }

    /// 튜토리얼 물결이 키 밖으로 번져 나가는 거리이자, 그리드가 위아래로 비워 두는 여백.
    /// **한 값을 둘이 같이 본다** - 어긋나면 그 차이만큼 물결이 잘린다.
    /// 가로 여백(12pt)보다 크지 않게 둔다. 가로는 늘릴 수 없다(키가 좁아진다).
    private static let gridRippleReach: CGFloat = 12

    // 데이터 상태
    @State private var allMemos: [Memo] = []
    @State private var templateObserverToken: NSObjectProtocol?
    @State private var showImageCopiedToast = false
    @State private var showPinNotSetToast = false
    /// 전체 접근이 꺼진 상태에서 클립보드 동작을 시도했을 때의 안내.
    @State private var showFullAccessToast = false
    /// 배운 캐럿 자리를 처음 적용했을 때 한 번만 뜨는 줄. 단축어당 한 번뿐이다.
    @State private var showCursorMemoryToast = false
    /// 매번 같은 자리를 고치는 것을 알아챘을 때 뜨는 제안. 단축어당 한 번뿐이다.
    @State private var editSuggestion: (memoId: UUID, kind: EditPattern.Suggestion)?
    /// 제안을 받아들여 단축어를 바꾼 직후 잠깐 뜨는 줄.
    @State private var showEditAppliedToast = false
    /// 앱 안에서 길게 눌러 복사했다는 확인. (익스텐션에서는 뜰 일이 없다)
    @State private var showCopiedToast = false
    /// 길게 눌러 판을 연 시각. 바로 뒤에 따라오는 탭 한 번을 삼키는 데 쓴다.
    ///
    /// ⚠️ 참·거짓 깃발로 두지 않는다. 길게 누른 뒤 탭이 **안 올 수도 있어서**(SwiftUI 가
    ///    이미 삼킨 경우) 깃발이 켜진 채로 남고, 그러면 다음에 제대로 누른 한 번이 사라진다.
    ///    시각으로 두면 스스로 풀린다.
    @State private var clipboardLongPressAt: Date?
    @State private var showEmptyClipboardToast = false
    /// 복사한 것에서 조각을 고르는 판. nil 이면 안 떠 있다.
    /// (사용자 요청: "웹페이지에서 내용을 복사한 후 일부만 붙여넣고 싶을 때")
    @State private var clipboardPickerText: String?
    /// 길게 눌러 복사한 직후의 키 - 이어서 들어오는 탭을 한 번 무시한다.
    /// (길게 눌렀는데 글까지 입력되면 "복사만 하려 했는데"가 된다)
    @State private var suppressTapAfterLongPress: UUID?

    // 검색 상태
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchKeyboardLang: SearchLang = .english
    /// 검색창 한글 조합기 - 자모 버튼 입력을 음절로 결합해 searchQuery에 반영(그대로 append 시 "ㅇㅣㄴㅅㅏ" 깨짐 방지).
    @State private var hangul = HangulSearchController()

    // v4.1.0: 카테고리 swipe 현재 페이지 인덱스 (즐겨찾기 별 토글은 제거됨)
    @State private var currentCategoryPage: Int = 0

    // 보안 메모 PIN 인증
    @State private var showPINEntry = false
    @State private var pendingSecureMemo: Memo?
    /// 인증을 통과하면 넣을 콤보 단계. nil 이면 콤보가 아니라 본체 값을 넣는다.
    /// (잠긴 콤보도 값을 고를 수 있어야 한다는 요청 - 고른 자리를 인증 너머까지 들고 간다.)
    @State private var pendingSecureComboIndex: Int?
    @State private var enteredPIN = ""
    @State private var pinEntryWrong = false

    @StateObject private var templateInputState = TemplateInputState()
    @State private var pendingBypassTemplate: Bool = false

    @Environment(\.colorScheme) var colorScheme

    /// 설정 > 손쉬운 사용 > 디스플레이 > 대비 증가.
    @Environment(\.colorSchemeContrast) private var contrast

    enum SearchLang { case english, korean }

    /// iOS 앱과 동일한 Paper 테마 - light/dark는 시스템 모드 따름.
    /// ⚠️ 익스텐션은 앱의 `AppThemedContainer` 를 거치지 않으므로 대비 증가를 **직접 본다.**
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark,
                         increasedContrast: contrast == .increased)
    }

    // MARK: - Computed Properties

    /// v4.1.0: 카테고리 기능 활성 시 선택된 카테고리 + 검색 적용, 비활성 시 검색만.
    /// 별 토글은 v4.1.0에서 제거됨 - 즐겨찾기는 카테고리 swipe(★favorites 페이지)로 접근.
    private var filteredMemos: [Memo] {
        var result = memos(onPage: selectedCategoryFilter)

        if !searchQuery.isEmpty {
            let q = searchQuery
            result = result.filter {
                $0.title.localizedStandardContains(q) ||
                $0.value.localizedStandardContains(q) ||
                $0.category.localizedStandardContains(q)
            }
        }
        return result
    }

    /// **한 페이지**에 서는 단축어들. 검색은 얹지 않는다.
    ///
    /// ⚠️ 페이지를 인자로 받는다. `filteredMemos` 가 지금 페이지만 알던 동안에는
    ///    "가리키는 키가 어느 페이지에 있는가"를 물을 방법이 없었다(`pageIndex(containing:)`).
    private func memos(onPage page: String?) -> [Memo] {
        var result = allMemos

        if isCategoryFeatureEnabled, let category = page {
            switch category {
            case "★basic":
                // 기본 = **갈 수 있는** 어떤 카테고리 페이지에도 속하지 않은 비즐겨찾기 메모.
                // ⚠️ 판정은 앱과 **같은 함수**(`CategoryBucketRule`)로 한다. 두 벌로 적어 두었던
                //    동안 양쪽 다 숨긴 카테고리를 빠뜨려, 그 안의 단축어가 어느 페이지에도
                //    나타나지 않았다(검색은 고른 페이지 위에서 도므로 검색으로도 못 찾는다).
                let visible = CategoryBucketRule.visibleCategories(all: sharedUserCategories,
                                                                   hidden: sharedHiddenCategoryTabs)
                let favoritesVisible = !sharedHiddenCategoryTabs.contains(CategoryBucketRule.favoritesTabKey)
                result = result.filter {
                    CategoryBucketRule.belongsToBasicBucket(category: $0.category,
                                                            isFavorite: $0.isFavorite,
                                                            visibleCustomCategories: visible,
                                                            favoritesTabVisible: favoritesVisible)
                }
            case "★favorites":
                result = result.filter { $0.isFavorite }
            case "★all":
                break   // (레거시 안전장치 - 현재 페이지 목록엔 없음) 전체 표시
            case let c where c.hasPrefix(Self.builtInPrefix):
                let raw = String(c.dropFirst(Self.builtInPrefix.count))
                result = result.filter { builtInMatches(raw, $0) }
            default:
                result = result.filter { $0.category == category }
            }
        }
        return result
    }

    /// 그 단축어가 서 있는 페이지의 번호. 어느 페이지에도 없으면 nil.
    private func pageIndex(containing id: UUID) -> Int? {
        categoryPages.firstIndex { page in
            memos(onPage: page).contains { $0.id == id }
        }
    }

    /// 튜토리얼이 가리키는 키가 **다른 페이지에 있으면** 그 페이지로 옮긴다.
    ///
    /// ⚠️ 이게 없으면 처음 온 사람의 첫 걸음이 그대로 끊긴다. 심어 둔 샘플은 즐겨찾기와
    ///    사용자 카테고리로 들어가는데, 키보드는 늘 첫 페이지(★basic)에서 열린다.
    ///    그 페이지는 **비어 있다** - "이걸 눌러보세요 ↓" 아래에 아무것도 없는 화면이 된다.
    private func revealHighlightedPageIfNeeded() {
        guard let id = highlightedMemoId, isCategoryFeatureEnabled else { return }
        // 이미 보이면 건드리지 않는다 - 사용자가 넘긴 페이지를 도로 끌고 오지 않기 위해서다.
        guard !filteredMemos.contains(where: { $0.id == id }) else { return }
        guard let index = pageIndex(containing: id), index != currentCategoryPage else { return }
        currentCategoryPage = index
    }

    /// 키보드 익스텐션은 메인 앱 타겟의 CategoryStore에 직접 접근할 수 없으므로
    /// App Group UserDefaults에서 같은 flag/배열을 읽어 동일 동작 보장.
    private var isCategoryFeatureEnabled: Bool {
        // 앱 안 무대에서는 카테고리를 항상 켠 것으로 본다 - 처음부터 탭이 보여야 하고,
        // 페이지만 보여주고 거르지 않으면 **골라도 반응이 없는** 죽은 탭이 된다.
        // (탭 노출과 필터가 같은 값을 봐야 하는 이유)
        if hostKind == .inApp { return true }
        return AppGroup.defaults?
            .bool(forKey: DefaultsKey.categoryFeatureEnabledV1) ?? false
    }

    /// iOS 앱 ClipKeyboardListViewModel과 같은 키 - 완전 동기화
    private var sharedUserCategories: [String] {
        AppGroup.defaults?
            .stringArray(forKey: DefaultsKey.userDefinedCategoriesV1) ?? []
    }

    /// iOS 앱에서 숨긴 탭 목록 - "__favorites__" 또는 카테고리 이름
    private var sharedHiddenCategoryTabs: Set<String> {
        let arr = AppGroup.defaults?
            .stringArray(forKey: DefaultsKey.hiddenCategoryTabsV1) ?? []
        return Set(arr)
    }

    /// iOS 앱에서 켠 기본 제공 카테고리 rawValue 목록(allCases 순서 유지) - 앱 BuiltInCategory와 동일.
    /// (타깃 분리로 enum을 공유하지 못해 rawValue 문자열로 인라인 처리.)
    private static let builtInOrder = ["templates", "textMemos", "images", "combos"]
    private var sharedEnabledBuiltIns: [String] {
        let enabled = Set(AppGroup.defaults?
            .stringArray(forKey: DefaultsKey.enabledBuiltInCategoriesV1) ?? [])
        return Self.builtInOrder.filter { enabled.contains($0) }
    }

    /// 기본 제공 카테고리 페이지 키 prefix(커스텀 카테고리 이름과 충돌 방지).
    private static let builtInPrefix = "★builtin:"

    /// 앱 BuiltInCategory.matches와 동일한 타입 판정.
    private func builtInMatches(_ raw: String, _ memo: Memo) -> Bool {
        switch raw {
        case "templates": return memo.isTemplate
        case "textMemos": return !memo.isCombo && memo.contentType != .image && memo.contentType != .mixed
        case "images":    return memo.contentType == .image || memo.contentType == .mixed
        case "combos":    return memo.isCombo
        default:          return false
        }
    }

    /// 앱 BuiltInCategory.displayName과 동일(다국어 키 공유).
    private func builtInDisplayName(_ raw: String) -> String {
        switch raw {
        case "templates": return NSLocalizedString("템플릿", comment: "Built-in category: templates only")
        case "textMemos": return NSLocalizedString("단축어+템플릿", comment: "Built-in category: text memos and templates")
        case "images":    return NSLocalizedString("이미지 단축어", comment: "Built-in category: image memos only")
        case "combos":    return NSLocalizedString("콤보", comment: "Built-in category: combos only")
        default:          return raw
        }
    }

    /// 앱 BuiltInCategory.icon과 동일.
    private func builtInIcon(_ raw: String) -> String {
        switch raw {
        case "templates": return "wand.and.stars"
        case "textMemos": return "doc.text.fill"
        case "images":    return "photo.fill"
        case "combos":    return "square.stack.3d.up.fill"
        default:          return "folder.fill"
        }
    }

    /// 앱 BuiltInCategory.tint와 동일.
    private func builtInTint(_ raw: String) -> Color {
        switch raw {
        case "templates": return .purple
        case "textMemos": return .indigo
        case "images":    return .green
        case "combos":    return .orange
        default:          return .blue
        }
    }

    /// v4.1.0: 키보드 페이지 인디케이터로 선택된 카테고리. "★all"=전체, "★favorites"=즐겨찾기,
    /// 그 외=실제 카테고리 이름. 기본 nil → 전체.
    private var selectedCategoryFilter: String? {
        guard !categoryPages.isEmpty else { return nil }
        let index = max(0, min(currentCategoryPage, categoryPages.count - 1))
        return categoryPages[index]
    }

    /// 카테고리 페이지 목록 - iOS 앱 ClipKeyboardListViewModel.allCategoryTabs와 완전 동일.
    /// 순서: 기본(★basic) → 즐겨찾기(숨김 아니면 항상) → 기본 제공(켠 것) → 사용자 카테고리(메모 있는 것).
    /// "전체(★all)" 탭은 앱에서 제거됐으므로 키보드에서도 노출하지 않는다.
    private var categoryPages: [String] {
        guard isCategoryFeatureEnabled else { return [] }
        let hidden = sharedHiddenCategoryTabs
        var pages: [String] = ["★basic"]
        // 즐겨찾기: 숨기지 않은 한 메모 유무와 무관하게 항상 노출 (앱과 동일).
        if !hidden.contains("__favorites__") {
            pages.append("★favorites")
        }
        // 기본 제공 카테고리 - 사용자가 켠 것만(타입 기준이라 메모 유무 무관).
        for b in sharedEnabledBuiltIns {
            pages.append(Self.builtInPrefix + b)
        }
        // 사용자 카테고리: 숨김 아니고 해당 카테고리 메모 1개 이상일 때만.
        let usedCategories = sharedUserCategories
            .filter { name in
                !hidden.contains(name) &&
                allMemos.contains { $0.category == name }
            }
        pages.append(contentsOf: usedCategories)
        return pages
    }

    /// 그리드 표시 항목 - 메모 하나당 셀 하나.
    private var displayItems: [DisplayItem] {
        filteredMemos.map { DisplayItem(memo: $0, useTemplate: false) }
    }

    /// 최근 사용 메모 5개 - lastUsedAt 기준 1주 이내, 최신순
    private var recentMemos: [Memo] {
        let weekAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7)
        return allMemos
            .filter { ($0.lastUsedAt ?? .distantPast) >= weekAgo }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    /// 최근 사용 섹션 노출 조건 - 검색 비활성일 때만
    private var shouldShowRecentSection: Bool {
        searchQuery.isEmpty && !recentMemos.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                memoModeContent
            }

            if showPINEntry {
                pinEntryOverlay
            }

            // 길게 눌러 값을 크게 보는 판 - 시스템 컨텍스트 메뉴는 키보드 창에 갇혀
            // 150pt 남짓으로 잘린다. 이 자리는 우리 것이라 꽉 채워 쓸 수 있다.
            // 복사한 것에서 필요한 데까지만 고르는 판.
            if let text = clipboardPickerText {
                KeyboardClipboardPicker(
                    text: text,
                    theme: theme,
                    onInsert: { picked in
                        typingProxy?.insertText(picked)
                        clipboardPickerText = nil
                    },
                    onClose: { clipboardPickerText = nil }
                )
                .transition(.opacity)
            }

            if let memo = peekMemo {
                KeyboardMemoPeek(
                    memo: memo,
                    theme: theme,
                    onCopy: {
                        copyTextToClipboard(memo.comboValues.first ?? memo.value)
                        peekMemo = nil
                    },
                    // 하나뿐이면 바꿀 순서가 없다 - 버튼도 두지 않는다.
                    onReorder: allMemos.count > 1 ? { enterReorderMode() } : nil,
                    onClose: { peekMemo = nil }
                )
                .transition(.opacity)
            }
        }
    }

    /// 한 글자 지우기. 붙잡고 있으면 이어서 지운다.
    ///
    /// 왜 X(전체 삭제) 만으로는 모자란가: 오타는 한 글자다. 전체를 지우면 다시 다 써야 하고,
    /// 그래서 사람들은 지구본을 눌러 다른 키보드로 건너갔다가 돌아왔다.
    /// 넣어 주는 키보드인데 고치러는 나가야 했다.
    private func backspaceDocumentKey(proxy: TypingInputProxy) -> some View {
        RepeatingKey {
            KeyboardHaptics.tap()
            proxy.deleteBackward()
        } label: {
            Image(systemName: AppSymbol.deleteLeftFill)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 36, height: 28)
                .background(theme.divider)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .frame(minWidth: 44, minHeight: 44)
        .padding(.trailing, 2)
        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace key"))
        .accessibilityHint(NSLocalizedString("한 글자씩 지웁니다. 누르고 있으면 이어서 지웁니다", comment: "Backspace key hint"))
    }

    /// 호스트가 시키는 대로 이름이 바뀌는 리턴 키.
    ///
    /// 왜 필요한가: 문구는 키보드에서 넣는데 **보내기가 시스템 키보드에만 있었다.** 넣자마자
    /// 지구본을 눌러 건너가야 했으니, 넣어 준 시간을 나가는 데 다 썼다(사용자 요청:
    /// "빨리 문구는 넣었는데 보내기 버튼을 못 찾겠다"). 지우기 키가 생긴 이유와 같은 뿌리다.
    ///
    /// ⚠️ **우리가 할 수 있는 것은 `"\n"` 을 넣는 것뿐이다.** 리턴 키를 눌렀다고 호스트에게
    ///    알리는 API 는 없다. 대부분의 채팅 앱은 이 줄바꿈을 받아 보내기로 처리하지만,
    ///    그렇게 안 만든 앱에서는 줄만 바뀐다.
    /// ⚠️ 그래서 **이름을 우리가 짓지 않는다.** 호스트가 말한 `returnKeyType` 을 그대로 적는다.
    ///    우리가 "보내기" 라고 지어 부르면, 안 보내지는 앱에서 그 글자가 거짓말이 된다.
    private func returnDocumentKey(proxy: TypingInputProxy) -> some View {
        let name = returnKeyName
        return Button {
            KeyboardHaptics.tap()
            proxy.insertNewline()
        } label: {
            Group {
                if let name {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 9)
                        .foregroundColor(theme.accentFg)
                } else {
                    // 호스트가 이름을 안 줬다(메모장 같은 곳). 그럴 때 줄바꿈은 '행동'이 아니라
                    // 그냥 줄바꿈이라, 강조색으로 세우지 않는다.
                    Image(systemName: AppSymbol.returnLeft)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 36)
                        .foregroundColor(theme.text)
                }
            }
            .frame(height: 28)
            .background(name == nil ? theme.divider : theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .padding(.trailing, 2)
        .contentShape(Rectangle())
        // 마찬가지로 "줄바꿈" 도 이미 다른 뜻(글의 줄바꿈 설정)으로 쓰여 "Line breaks" 다.
        .accessibilityLabel(name ?? NSLocalizedString("리턴 키", comment: "Return key accessibility label"))
        .accessibilityHint(NSLocalizedString("입력창에 줄바꿈을 넣습니다. 앱에 따라 보내기로 동작합니다", comment: "Return key hint"))
    }

    /// 호스트가 말한 리턴 키의 이름. 모르는 종류면 nil 이고, 그때는 줄바꿈 화살표로 그린다.
    /// **없는 이름을 지어내지 않는다** - 틀린 이름은 없는 것보다 나쁘다.
    private var returnKeyName: String? {
        switch documentState.returnKeyType {
        case .send:   return NSLocalizedString("보내기", comment: "Return key label: send")
        case .search: return NSLocalizedString("검색", comment: "Return key label: search")
        // ⚠️ "이동" 은 못 쓴다. 이미 목록에서 **자리를 옮긴다**는 뜻으로 쓰고 있어서
        //    영어가 "Move" 로 번역돼 있다. 사파리 주소창 키에 "Move" 가 서면 거짓말이다.
        //    String Catalog 는 한 낱말에 뜻을 둘 담지 못하므로 문구를 달리한다.
        case .go:     return NSLocalizedString("이동하기", comment: "Return key label: go")
        case .done:   return NSLocalizedString("완료", comment: "Return key label: done")
        case .next:   return NSLocalizedString("다음", comment: "Return key label: next")
        default:      return nil
        }
    }

    /// 복사한 것을 넣는 키.
    ///
    /// **짧게 누르면 통째로, 길게 누르면 조각을 골라서.**
    /// 이 저장소가 이미 쓰는 손짓이다(키 하나가 두 가지 일을 한다 - `InAppLongPressCopy`).
    private func clipboardKey(proxy: TypingInputProxy) -> some View {
        Button {
            if let at = clipboardLongPressAt, Date().timeIntervalSince(at) < 0.8 { return }
            guard let text = clipboardTextForInsert() else { return }
            KeyboardHaptics.tap()
            proxy.insertText(text)
        } label: {
            Image(systemName: AppSymbol.docOnClipboard)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 32, height: 28)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .padding(.trailing, 2)
        .onLongPressGesture(minimumDuration: 0.4) {
            clipboardLongPressAt = Date()
            openClipboardPicker()
        }
        .accessibilityLabel(NSLocalizedString("붙여넣기", comment: "Paste clipboard key"))
        .accessibilityHint(NSLocalizedString("복사한 것을 넣습니다. 길게 누르면 필요한 부분만 고를 수 있습니다", comment: "Paste key hint"))
        // 길게 누르기를 모르는 사람도, 손이 불편한 사람도 쓸 수 있게.
        .accessibilityAction(named: Text(NSLocalizedString("부분만 고르기", comment: "Accessibility action: pick part of clipboard"))) {
            openClipboardPicker()
        }
    }

    private func openClipboardPicker() {
        guard let text = clipboardTextForInsert() else { return }
        KeyboardHaptics.mediumTap()
        withAnimation { clipboardPickerText = text }
    }

    /// 클립보드의 글. 없거나 못 읽으면 안내를 띄우고 nil.
    ///
    /// ⚠️ 읽는 때는 **사용자가 키를 누른 순간뿐이다.** 저절로 읽지 않는다
    ///    (`docs/postmortem/HANG_PASTEBOARD_5_0_1.md` - 유니버설 클립보드가 켜져 있으면
    ///     읽기가 옆 기기를 기다린다). 누른 사람에게는 그 기다림이 곧 대답이다.
    private func clipboardTextForInsert() -> String? {
        if hostKind == .keyboardExtension, !requireFullAccess() { return nil }
        // pasteboard-ok: 사용자가 붙여넣기 키를 직접 눌렀다
        let text = UIPasteboard.general.string ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            KeyboardHaptics.softTap()
            withAnimation { showEmptyClipboardToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showEmptyClipboardToast = false }
            }
            return nil
        }
        return text
    }

    private func clearAllButton(proxy: TypingInputProxy) -> some View {
        Button {
            KeyboardHaptics.mediumTap()
            proxy.clearAll()
        } label: {
            Image(systemName: AppSymbol.xmarkCircle)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 36, height: 28)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(NSLocalizedString("전체 삭제", comment: "Clear all text"))
        .accessibilityHint(NSLocalizedString("현재 입력된 텍스트를 모두 지웁니다", comment: "Clear all button hint"))
    }

    @ViewBuilder
    private var memoModeContent: some View {
        VStack(spacing: 0) {
            // 무료 유저: 숨겨진 메모 있을 때 또는 한도 임박(2개 이내) 시 업그레이드 배너
            if isFreeUser && !isReorderMode && (hiddenMemoCount > 0 || isMemoLimitNear) {
                freeUpgradeBanner
            }

            // 순서를 바꾸는 동안에는 위 줄을 이 안내가 대신 쓴다.
            // 카테고리 탭은 이때 뜻이 없다 - 페이지와 무관하게 전체를 한 줄로 늘어놓고 옮긴다.
            if isReorderMode {
                reorderBanner
            }

            // 상단 헤더 - 카테고리 탭 + clear 버튼
            if !isReorderMode {
                HStack(spacing: 0) {
                    // 지구본이 이 줄의 첫 자리다. 카테고리 탭 **안**이 아니라 밖이라는 게
                    // 중요하다 - 안에 있던 시절에는 카테고리가 하나뿐이면 아래 else 로 빠져
                    // 지구본까지 같이 사라졌다.
                    if KeyboardCapability.needsInputModeSwitchKey, let proxy = typingProxy {
                        globeKey(proxy: proxy)
                    }
                    // 앱 안에서는 탭이 하나뿐이어도 보여준다 - 카테고리가 **처음부터** 있어야
                    // "여기서 갈라 볼 수 있다"가 읽힌다. 익스텐션은 자리가 귀해 예전대로 둘 이상일 때만.
                    if hostKind == .inApp ? !categoryPages.isEmpty : categoryPages.count > 1 {
                        categoryTabRow
                    } else {
                        Spacer()
                    }
                    // X(전체 삭제)도 앱 안에서는 **처음부터** 서 있다. 글이 생길 때 나타나면
                    // 그 순간 줄이 흔들리고, 무엇보다 "지울 수 있다"를 미리 알 수 없다.
                    // 복사한 것을 넣는 키. 지울 수 있게 된 김에 붙여넣을 수도 있어야 한다.
                    if let proxy = typingProxy {
                        clipboardKey(proxy: proxy)
                    }
                    // 넣고 나서 보내는 키. **X 옆에 두지 않는다** - 하나는 보내 버리고 하나는
                    // 다 지우는 키라, 붙여 놓으면 잘못 누른 값이 양쪽 다 크다. 사이에 지우기를 끼운다.
                    if let proxy = typingProxy, showReturnKey,
                       documentState.hasText || hostKind == .inApp {
                        returnDocumentKey(proxy: proxy)
                    }
                    // 한 글자 지우기. 이게 없어서 오타 하나를 고치려고 **다른 키보드로
                    // 건너갔다가 돌아와야 했다**(사용자 요청).
                    if let proxy = typingProxy, documentState.hasText || hostKind == .inApp {
                        backspaceDocumentKey(proxy: proxy)
                    }
                    if let proxy = typingProxy, documentState.hasText || hostKind == .inApp {
                        clearAllButton(proxy: proxy)
                            .padding(.trailing, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            // 빈 칸에서는 눌러도 지울 게 없다 - 있지만 흐리게.
                            .opacity(documentState.hasText ? 1 : 0.4)
                            .disabled(!documentState.hasText)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: documentState.hasText)
            }

            // 검색 바 - 사용자 토글 ON일 때만
            if showSearchBar && !isReorderMode {
                searchBar
            }

            // 최근 사용 섹션 - 사용자 토글 ON + 검색 비활성일 때만
            if showRecentSection && !isReorderMode && !isSearching && shouldShowRecentSection {
                recentSection
            }

            // 메모 그리드
            ZStack {
                backgroundColor

                if isReorderMode {
                    reorderGrid
                } else if filteredMemos.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 10) {
                            ForEach(displayItems) { item in
                                memoButton(for: item.memo, useTemplate: item.useTemplate)
                                    // 앱 안에서는 키 하나가 두 가지 일을 한다
                                    // **짧게 누르면 입력창에, 길게 누르면 클립보드에.**
                                    //
                                    // ⚠️ 예전에는 키마다 작은 복사 버튼을 얹었는데, 좁은 키에
                                    //    누를 곳이 둘이라 잘못 누르기 쉬웠고 제목도 가렸다.
                                    //    길게 누르기는 자리를 차지하지 않는다.
                                    //    (익스텐션에서는 같은 길게 누르기가 값을 크게 펼친다
                                    //     `MemoPeekOnLongPress` - 한 손짓에 주인은 하나여야 한다)
                                    .modifier(InAppLongPressCopy(
                                        enabled: hostKind == .inApp,
                                        onCopy: { copyMemoInApp(item.memo) },
                                        suppressed: $suppressTapAfterLongPress,
                                        memoId: item.memo.id
                                    ))
                                    // 튜토리얼이 가리키는 키 - **말이 아니라 파형으로** 알린다.
                                    // 글로 설명하면 아무도 안 읽는다.
                                    //
                                    // ⚠️ 콤보 키의 **한쪽만** 가리키는 중이면 여기서는 안 그린다.
                                    //    좌·우가 각자 자기 물결을 그린다(`comboSplitButton`).
                                    //    둘 다 그리면 키 전체가 빛나는 위에 반쪽이 또 빛나서
                                    //    가리키는 곳이 오히려 흐려진다.
                                    .overlay {
                                        if item.memo.id == highlightedMemoId,
                                           highlightedComboPart == nil {
                                            KeyRipple(shape: keycapShape, color: theme.accent,
                                                      reach: Self.gridRippleReach)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        // ⚠️ 세로 여백은 물결이 번져 나갈 자리이기도 하다. `ScrollView` 는
                        //    넘치는 것을 잘라내므로, 여기가 물결보다 좁으면 첫 줄·끝 줄 키의
                        //    물결이 위아래로 싹둑 잘린다(예전 6pt, 물결 14pt).
                        //    가로 12pt 는 그대로 둔다 - 늘리면 키가 그만큼 좁아진다.
                        .padding(.vertical, Self.gridRippleReach)
                    }
                    // v4.1.0: 좌우 swipe로 카테고리 페이지 전환
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                guard categoryPages.count > 1 else { return }
                                let h = value.translation.width
                                let v = value.translation.height
                                guard abs(h) > abs(v) * 1.5, abs(h) > 60 else { return }
                                if h < 0, currentCategoryPage < categoryPages.count - 1 {
                                    KeyboardHaptics.tap()
                                    currentCategoryPage += 1
                                } else if h > 0, currentCategoryPage > 0 {
                                    KeyboardHaptics.tap()
                                    currentCategoryPage -= 1
                                }
                            }
                    )
                }
            }
            // 인디케이터 점 제거 - 상단 categoryTabRow에서 심볼 버튼으로 이동

            // 미니 검색 키보드 - 검색 중일 때만
            if isSearching && !isReorderMode {
                miniSearchKeyboard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: isSearching)
        .overlay(
            Group {
                if templateInputState.isShowing {
                    // 가리키는 키가 있다는 것은 지금 튜토리얼이 돌고 있다는 뜻이다.
                    // 그 키를 눌러 여기까지 왔으므로, 다음에 누를 곳도 이어서 알려 준다.
                    TemplateInputOverlay(state: templateInputState,
                                         hostKind: hostKind,
                                         guidesUser: highlightedMemoId != nil)
                }
            }
        )
        .overlay(alignment: .bottom) {
            if showImageCopiedToast {
                Text(NSLocalizedString("이미지 복사됨 · 붙여넣기 하세요", comment: "Image copied toast"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showEmptyClipboardToast {
                Text(NSLocalizedString("복사해 둔 것이 없어요", comment: "Toast: clipboard is empty"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showCopiedToast {
                Text(NSLocalizedString("복사됨 · 다른 앱에 붙여넣기 하세요", comment: "Copied to clipboard toast (in-app keyboard)"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showSecureCopyBlockedToast {
                Text(NSLocalizedString("잠긴 단축어라 복사되지 않아요. 눌러서 인증하면 입력돼요.",
                                       comment: "Toast: secure memo cannot be copied by long press"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showPinNotSetToast {
                Text(NSLocalizedString("앱에서 보안 PIN을 먼저 설정하세요", comment: "Set PIN in app first"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let suggestion = editSuggestion {
                // ⚠️ 말만 하지 않는다. 누르면 그 자리에서 바꿔 준다.
                //    "이런 기능이 있어요"는 알림이고, "바꿔 드릴까요"는 도움이다.
                editSuggestionBar(suggestion)
            }
            if showEditAppliedToast {
                Text(NSLocalizedString("바꿨어요. 앱에서 다시 손볼 수 있어요.",
                                       comment: "Toast after applying an edit-pattern suggestion"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showCursorMemoryToast {
                // 조용히 해 주는 게 목적이라 매번 말하지 않는다. 다만 한 번도 안 알리면
                // 사용자는 자기 키보드가 왜 이러는지 모른다. 그래서 단축어당 딱 한 번.
                Text(NSLocalizedString("여기서 이어 쓰시길래 커서를 여기 세워 뒀어요. 단축어 편집에서 끌 수 있어요.",
                                       comment: "Toast shown once when a learned caret position is first applied"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showFullAccessToast {
                // 무엇을 켜야 하는지·어디서 켜는지를 한 줄에 담는다.
                // 이 토스트가 없으면 클립보드 동작이 조용히 실패해 앱이 고장 난 것처럼 보인다.
                Text(NSLocalizedString("설정 > 키보드에서 '전체 접근 허용'을 켜주세요", comment: "Full Access required toast"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        // {clipboard} 치환이 전체 접근 때문에 막혔을 때 KeyboardViewController가 알려 준다.
        .onReceive(NotificationCenter.default.publisher(for: .needsFullAccess)) { _ in
            showFullAccessNotice()
        }
        // 매번 같은 자리를 고치는 것을 알아챘다 - KeyboardViewController 가 알려 준다.
        .onReceive(NotificationCenter.default.publisher(for: .editPatternSuggestion)) { note in
            guard let memoId = note.userInfo?["memoId"] as? UUID,
                  let raw = note.userInfo?["suggestion"] as? String,
                  let kind = EditPattern.Suggestion(rawValue: raw) else { return }
            withAnimation { editSuggestion = (memoId, kind) }
        }
        // 배운 캐럿 자리를 처음 써먹었다 - KeyboardViewController 가 알려 준다.
        .onReceive(NotificationCenter.default.publisher(for: .cursorMemoryApplied)) { _ in
            withAnimation { showCursorMemoryToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation { showCursorMemoryToast = false }
            }
        }
        // 장이 넘어가면 가리키는 키가 바뀐다 - 뷰는 그대로라 onAppear 가 다시 돌지 않는다.
        .onChange(of: highlightedMemoId) { _, _ in revealHighlightedPageIfNeeded() }
        .onAppear {
            loadAllMemos()
            revealHighlightedPageIfNeeded()

            guard templateObserverToken == nil else { return }
            // 템플릿 입력 알림 구독
            templateObserverToken = NotificationCenter.default.addObserver(forName: Notification.Name.showTemplateInput, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let text = userInfo["text"] as? String,
                   let placeholders = userInfo["placeholders"] as? [String],
                   let memoId = userInfo["memoId"] as? UUID {

                    print("🔍 템플릿 입력 요청 받음")
                    print("   메모 ID: \(memoId)")
                    print("   플레이스홀더: \(placeholders)")

                    templateInputState.originalText = text
                    templateInputState.placeholders = placeholders
                    templateInputState.templateId = memoId
                    // v4.0.8: attached 흐름이면 baseMemoId + baseMemoValue 캐시. 없으면 비움.
                    let baseMemoId = userInfo["baseMemoId"] as? UUID
                    templateInputState.baseMemoId = baseMemoId
                    if let baseId = baseMemoId,
                       let baseMemo = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == baseId }) {
                        templateInputState.baseMemoValue = baseMemo.value
                    } else {
                        templateInputState.baseMemoValue = ""
                    }

                    var initialInputs: [String: String] = [:]

                    for placeholder in placeholders {
                        print("   🔍 [KeyboardView] 플레이스홀더 값 로드 시도: \(placeholder)")
                        let values = PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder, templateId: memoId)
                        print("   📊 [KeyboardView] \(placeholder): \(values.count)개 - \(values)")

                        if let firstValue = values.first, !firstValue.isEmpty {
                            initialInputs[placeholder] = firstValue
                            print("   ✅ [KeyboardView] \(placeholder) 기본값 설정: \(firstValue)")
                        } else {
                            initialInputs[placeholder] = ""
                            print("   ⚠️ [KeyboardView] \(placeholder) 값 없음 - 빈 문자열 설정")
                        }
                    }

                    templateInputState.inputs = initialInputs
                    templateInputState.updateAllPlaceholdersFilled()

                    print("   초기 입력값: \(initialInputs)")

                    print("🎨 템플릿 값 선택 UI 표시")
                    withAnimation {
                        templateInputState.isShowing = true
                    }
                }
            }
        }
        .onDisappear {
            if let token = templateObserverToken {
                NotificationCenter.default.removeObserver(token)
                templateObserverToken = nil
            }
        }
    }

    // MARK: - Free Upgrade Banner

    private var freeUpgradeBanner: some View {
        Button {
            // KeyboardViewController가 이 알림을 받아 URL scheme으로 메인 앱 열기
            NotificationCenter.postOnMain(name: Notification.Name.openMainAppPaywall, object: nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.lockFill)
                    .font(.caption2)
                Text(upgradeBannerText)
                    .font(.caption2.weight(.medium))
                Spacer()
                Image(systemName: AppSymbol.chevronRight)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    /// 배너 문구: hidden 메모가 있으면 그 개수, 없으면 한도까지 남은 개수
    private var upgradeBannerText: String {
        if hiddenMemoCount > 0 {
            return String(format: NSLocalizedString("%d개 단축어 더 보기 → Pro 업그레이드", comment: "Hidden memos upgrade banner"), hiddenMemoCount)
        }
        let remaining = max(0, ProFeatureManager.memoLimit - ownMemoCount)
        return String(format: NSLocalizedString("단축어 한도까지 %d개 남음 → Pro 업그레이드", comment: "Memo limit near banner"), remaining)
    }

    /// 한도 도달 임박 (남은 슬롯 2개 이하)
    private var isMemoLimitNear: Bool {
        guard isFreeUser else { return false }
        let remaining = ProFeatureManager.memoLimit - ownMemoCount
        return remaining > 0 && remaining <= 2
    }

    // MARK: - Search Bar

    /// 키보드 상단 검색 바 - 탭하면 미니 QWERTY 펼침.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.magnifyingglass)
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            if isSearching {
                Text(searchQuery.isEmpty
                     ? NSLocalizedString("Type to filter…", comment: "Search bar placeholder when active")
                     : searchQuery)
                    .font(.footnote)
                    .foregroundColor(searchQuery.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    KeyboardHaptics.softTap()
                    hangul.reset()
                    searchQuery = ""
                    isSearching = false
                } label: {
                    Image(systemName: AppSymbol.xmarkCircleFill)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(NSLocalizedString("검색어 지우기", comment: "Clear search"))
            } else {
                Text(NSLocalizedString("Search snippets", comment: "Search bar idle"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isSearching else { return }
            KeyboardHaptics.softTap()
            isSearching = true
        }
        .accessibilityLabel(isSearching
            ? (searchQuery.isEmpty ? NSLocalizedString("검색 중", comment: "Search bar active empty") : searchQuery)
            : NSLocalizedString("단축어 검색", comment: "Search field accessibility label"))
        .accessibilityHint(isSearching
            ? NSLocalizedString("x 버튼을 탭하면 검색을 닫습니다", comment: "Search bar active hint")
            : NSLocalizedString("탭하면 단축어를 검색합니다", comment: "Search bar hint"))
        .accessibilityAddTraits(isSearching ? [] : .isButton)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyStateIcon)
                .font(.title)
                .foregroundColor(theme.textFaint)

            VStack(spacing: 3) {
                Text(emptyStateTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                Text(emptyStateSubtitle)
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // 빠져나갈 액션 - 검색·필터·콤보 탭에서 항상 명시적 escape 제공
            if let escapeAction = emptyStateEscape {
                Button {
                    KeyboardHaptics.softTap()
                    escapeAction.handler()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .font(.caption)
                        Text(escapeAction.label)
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(theme.accentFg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(theme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    /// empty state에서 노출되는 escape 버튼 (있으면).
    private var emptyStateEscape: (label: String, handler: () -> Void)? {
        if !searchQuery.isEmpty {
            return (NSLocalizedString("Clear search", comment: "Empty escape: clear search"), {
                hangul.reset()
                searchQuery = ""
                isSearching = false
            })
        }
        if selectedCategoryFilter == "★favorites" {
            return (NSLocalizedString("Show all", comment: "Empty escape: show all memos"), {
                currentCategoryPage = 0
            })
        }
        return nil
    }

    private var emptyStateIcon: String {
        if !searchQuery.isEmpty { return "magnifyingglass" }
        if selectedCategoryFilter == "★favorites" { return "heart.slash" }
        return "sparkles"
    }

    private var emptyStateTitle: String {
        if !searchQuery.isEmpty {
            return String(format: NSLocalizedString("No matches for \"%@\"", comment: "Empty search result"), searchQuery)
        }
        if selectedCategoryFilter == "★favorites" {
            return NSLocalizedString("No favorites yet", comment: "Empty: no favorites")
        }
        return NSLocalizedString("Save it once. Paste it forever.", comment: "Empty: zero memos")
    }

    private var emptyStateSubtitle: String {
        if !searchQuery.isEmpty {
            return NSLocalizedString("Try a shorter keyword or clear the filter.", comment: "Empty hint: search")
        }
        if selectedCategoryFilter == "★favorites" {
            return NSLocalizedString("Mark snippets as favorite in the main app to see them here.", comment: "Empty hint: favorites")
        }
        return NSLocalizedString("Add snippets in the main app, they'll appear here in seconds.", comment: "Empty hint: zero memos")
    }

    // MARK: - Mini Search Keyboard

    /// 검색 전용 미니 QWERTY (높이 ~120pt). TextField 사용 X - 자체 버튼이 searchQuery 문자열에 append.
    private var miniSearchKeyboard: some View {
        VStack(spacing: 4) {
            ForEach(Array(currentRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 3) {
                    ForEach(row, id: \.self) { letter in
                        searchKey(letter: letter)
                    }
                }
            }
            HStack(spacing: 3) {
                if koreanInputEnabled { langToggleKey }   // 한국어 미사용 시 토글 숨김
                spaceKey
                backspaceKey
            }
        }
        .padding(.horizontal, 3)
        .onAppear {
            // 한국어 미사용이면 항상 영어 자판. 사용 중이면 기본 언어 설정을 시작값으로.
            searchKeyboardLang = (koreanInputEnabled && defaultTypingLang == "korean") ? .korean : .english
        }
        .padding(.vertical, 4)
        .background(theme.surfaceAlt)
    }

    private func searchKey(letter: String) -> some View {
        Button {
            KeyboardHaptics.tap()
            // 자모/영문 모두 조합기로 라우팅 - 한글은 음절로 결합, 영문은 현재 음절 확정 후 삽입.
            if let ch = letter.first { hangul.input(ch) }
            searchQuery = hangul.buffer
        } label: {
            Text(letter)
                .font(.subheadline.weight(.medium))
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(theme.surface)
                .cornerRadius(theme.radiusXs)
        }
    }

    private var spaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            hangul.input(" ")   // 현재 조합 중인 음절을 확정하고 공백 삽입.
            searchQuery = hangul.buffer
        } label: {
            HStack {
                Spacer()
                Image(systemName: AppSymbol.space)
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                Spacer()
            }
            .frame(height: 28)
            .background(theme.surface)
            .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("스페이스", comment: "Space key"))
    }

    private var backspaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            hangul.backspace()   // 조합 중이면 한 단계 되돌리고, 아니면 마지막 글자 삭제.
            searchQuery = hangul.buffer
        } label: {
            Image(systemName: AppSymbol.deleteLeftFill)
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.text)
                .frame(width: 56, height: 28)
                .background(theme.divider)
                .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace key"))
    }

    private var langToggleKey: some View {
        Button {
            KeyboardHaptics.softTap()
            hangul.commitComposition()   // 전환 전 진행 중이던 음절을 확정(반쪽 음절이 다른 언어와 이어지지 않게).
            searchKeyboardLang = (searchKeyboardLang == .english) ? .korean : .english
        } label: {
            Text(searchKeyboardLang == .english ? "한" : "EN")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.text)
                .frame(width: 40, height: 28)
                .background(theme.divider)
                .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("입력 언어 전환", comment: "Toggle input language key"))
    }

    private var currentRows: [[String]] {
        // 한국어 미사용이면 무조건 영어 자판 (한글 노출 방지 방어)
        switch koreanInputEnabled ? searchKeyboardLang : .english {
        case .english:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"]
            ]
        case .korean:
            return [
                ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅛ", "ㅕ", "ㅑ", "ㅐ", "ㅔ"],
                ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅗ", "ㅓ", "ㅏ", "ㅣ"],
                ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅠ", "ㅜ", "ㅡ"]
            ]
        }
    }

    // MARK: - Category Tab Row

    private var categoryTabRow: some View {
        HStack(spacing: 6) {
            categoryTabScroller
        }
        .padding(.vertical, 5)
    }

    // MARK: - 지구본(다음 키보드)

    /// 지구본. **카테고리 탭 밖, 늘 같은 자리에 선다.**
    ///
    /// 예전에는 `categoryTabRow` 안에 있어서 카테고리가 하나뿐인 사람에게는 줄째로
    /// 사라졌다. 다른 키보드로 건너갈 유일한 문이라(심사 요건이기도 하다) 카테고리
    /// 개수와 무관하게 세운다.
    ///
    /// 보이는 것은 SwiftUI 가 그리고, 누르는 것은 위에 덮은 투명 UIButton 이 받는다.
    /// 이유는 `InputModeSwitchOverlay` 주석 참고.
    private func globeKey(proxy: TypingInputProxy) -> some View {
        Image(systemName: AppSymbol.globe)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .frame(width: 32, height: 28)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
            .frame(minWidth: 44, minHeight: 44)
            .overlay(InputModeSwitchOverlay(proxy: proxy))
            .padding(.leading, 8)
    }

    private var categoryTabScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(categoryPages.enumerated()), id: \.offset) { index, key in
                    let isSelected = currentCategoryPage == index
                    let accent = colorForCategoryKey(key)
                    Button {
                        KeyboardHaptics.tap()
                        currentCategoryPage = index
                    } label: {
                        Image(systemName: iconForCategoryKey(key))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : theme.textMuted)
                            .frame(width: 32, height: 28)
                            .background(isSelected ? accent : theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(labelForCategoryKey(key))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 8)
        }
    }

    /// 카테고리 페이지 키에 표시할 짧은 라벨.
    private func labelForCategoryKey(_ key: String) -> String {
        if key == "★basic" { return NSLocalizedString("기본", comment: "Category tab: default/basic") }
        if key == "★all" { return NSLocalizedString("전체", comment: "Category tab: all") }
        if key == "★favorites" { return NSLocalizedString("즐겨찾기", comment: "Category tab: favorites") }
        if key.hasPrefix(Self.builtInPrefix) {
            return builtInDisplayName(String(key.dropFirst(Self.builtInPrefix.count)))
        }
        return key
    }

    // MARK: - Recent Section

    /// 최근 1주 사용한 메모 5개 - 헤더 없이 가로 스크롤 미니 카드만 (공간 절약)
    private var recentSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                Image(systemName: AppSymbol.clockArrowCirclepath)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.textFaint)
                    .accessibilityHidden(true)
                ForEach(recentMemos) { memo in
                    recentChip(memo)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 2)
    }

    private func recentChip(_ memo: Memo) -> some View {
        Button {
            memoButtonAction(for: memo)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: categoryIconFor(memo))
                    .font(.caption2)
                    .foregroundColor(categoryColorFor(memo) ?? theme.textMuted)
                Text(memo.title.templateAwareAttributed(accent: theme.accent,
                                                        accentSoft: theme.accentSoft,
                                                        font: .caption.weight(.medium)))
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
            .overlay(
                // 카테고리색 테두리 - 구분 표시 ON일 때만 (기본은 테두리 없이).
                Capsule()
                    .stroke(((visualCuesVisible ? categoryColorFor(memo) : nil) ?? .clear).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(format: NSLocalizedString("최근: %@", comment: "Recent memo chip label"), memo.title))
        .accessibilityHint(memoAccessibilityHint(for: memo))
    }

    // MARK: - Memo Button

    @ViewBuilder
    private func memoButton(for memo: Memo, useTemplate: Bool = false) -> some View {
        // 카테고리 색 틴트는 카테고리 정체성이라 항상 표시(구분 표시 토글과 무관).
        let catColor = categoryColorFor(memo)
        let isImageMemo = (memo.contentType == .image || memo.contentType == .mixed)
        let imageFileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        let bypass = false

        if isImageMemo && !imageFileName.isEmpty && !memo.isCombo {
            // 이미지 메모(콤보 아님): 전체 배경으로 이미지 표시.
            // 이미지+여러 값(콤보)이면 아래 분할 버튼으로 값을 넣게 하고, 이미지는 롱프레스로 복사.
            Button {
                memoButtonAction(for: memo)
            } label: {
                ImageMemoButton(
                    title: memo.title,
                    fileName: imageFileName,
                    buttonHeight: buttonHeight,
                    buttonFontSize: buttonFontSize
                )
            }
            .buttonStyle(KeycapButtonStyle(skin: skin, cornerRadius: keycapRadius, skirtColor: keycapSkirtColor))
            .modifier(MemoPeekOnLongPress(memo: memo, enabled: hostKind != .inApp, onPeek: showPeek))
            .accessibilityLabel(memoAccessibilityLabel(for: memo))
            .accessibilityHint(memoAccessibilityHint(for: memo))
        } else if memo.isCombo {
            // 여러 값(콤보) - 2/3 분할: 왼쪽 현재 값 삽입, 오른쪽 → 다음 값.
            //
            // ⚠️ **잠긴 콤보도 여기로 온다.** 예전에는 `&& !memo.isSecure` 로 빼 두었는데,
            //    그러면 잠긴 콤보는 아래 통짜 키로 떨어져 **1번 값만** 나가고 2번부터는
            //    키보드에서 꺼낼 길이 아예 없었다(사용자 요청: "잠금 푼 뒤에 고를 수가 없다").
            //    고르는 일에는 값이 필요 없다 - 값이 나가는 왼쪽만 인증을 받으면 된다.
            comboSplitButton(for: memo, catColor: catColor)
                .modifier(MemoPeekOnLongPress(memo: memo, enabled: hostKind != .inApp, onPeek: showPeek))
                .accessibilityLabel(memoAccessibilityLabel(for: memo))
                .accessibilityHint(memo.isSecure
                    ? NSLocalizedString("오른쪽 화살표로 값을 고르고, 왼쪽을 누르면 PIN 인증 후 넣어요", comment: "Secure combo split button hint")
                    : NSLocalizedString("왼쪽을 누르면 현재 값을, 오른쪽 화살표로 다음 값을 넣어요", comment: "Combo split button hint"))
        } else {
            Button {
                memoButtonAction(for: memo, bypassTemplate: bypass)
            } label: {
                memoButtonLabel(for: memo, catColor: catColor, useTemplate: useTemplate)
            }
            .buttonStyle(KeycapButtonStyle(skin: skin, cornerRadius: keycapRadius, skirtColor: keycapSkirtColor))
            .modifier(MemoPeekOnLongPress(memo: memo, enabled: hostKind != .inApp, onPeek: showPeek))
            .accessibilityLabel(memoAccessibilityLabel(for: memo))
            .accessibilityHint(memoAccessibilityHint(for: memo))
        }
    }

    // MARK: - Combo Split Button (여러 값: 왼쪽 현재 값 삽입 / 오른쪽 → 다음 값)

    /// 지금 껍데기가 깨지고 있는 키. nil 이면 아무 데서도 안 벌어진다.
    ///
    /// ⚠️ 미리보기(`hostKind == .inApp`)에서만 값이 들어간다. 익스텐션에서는 이 값이
    ///    영원히 nil 이라 연출이 그려지지 않는다.

    /// 지금 크게 들여다보고 있는 단축어(길게 누르기). nil 이면 판이 닫혀 있다.
    @State private var peekMemo: Memo?
    /// 보안 단축어를 길게 눌러 복사하려 했을 때의 안내.
    @State private var showSecureCopyBlockedToast = false

    /// 길게 눌렀다 - 값을 크게 펼친다.
    ///
    /// ⚠️ 뒤이어 들어올 탭을 막아 둔다. 값을 보려고 눌렀는데 글까지 입력되면
    ///    지우는 일이 하나 더 생긴다(`memoButtonAction` 이 이 표식을 본다).
    private func showPeek(_ memo: Memo) {
        suppressTapAfterLongPress = memo.id
        KeyboardHaptics.mediumTap()
        withAnimation(.easeOut(duration: 0.16)) { peekMemo = memo }
    }

    /// 콤보(여러 값) 메모의 현재 선택 값 인덱스 - 메모별로 기억.
    @State private var comboValueIndex: [UUID: Int] = [:]
    /// → 누를 때마다 증가 - 값을 잠깐 보여줬다 사라지는 디졸브를 트리거한다.
    @State private var comboFlash: [UUID: Int] = [:]
    /// 지금 눌려 있는 콤보 키. 좌·우 어느 쪽을 눌러도 **키캡 하나**가 통째로 내려앉는다.
    /// (동시에 두 키를 누를 수는 없으므로 단일 값으로 충분)
    @State private var pressedComboId: UUID?

    private func comboSplitButton(for memo: Memo, catColor: Color?) -> some View {
        let values = memo.comboValues.isEmpty ? [memo.value] : memo.comboValues
        let idx = min(max(comboValueIndex[memo.id] ?? 0, 0), values.count - 1)
        let current = values[idx]
        // 좌·우 어느 쪽을 눌러도 **키캡 하나**가 통째로 내려앉는다.
        let pressedBinding = Binding<Bool>(
            get: { pressedComboId == memo.id },
            set: { pressedComboId = $0 ? memo.id : nil }
        )
        // 튜토리얼이 이 키의 어느 쪽을 가리키고 있는가(가리키는 키일 때만).
        let guided: ComboKeyPart? = memo.id == highlightedMemoId ? highlightedComboPart : nil

        return HStack(spacing: 0) {
            // 왼쪽 2/3 - 평소엔 키(제목), → 누르면 현재 값이 디졸브로 잠깐 보였다 사라진다(iOS와 동일).
            Button {
                if memo.isSecure {
                    // 값이 나가는 쪽만 인증을 받는다. 고른 자리(idx)를 인증 너머로 들고 간다.
                    authenticateAndInsert(memo: memo, comboIndex: idx)
                } else {
                    insertComboValue(memo: memo, value: current)
                }
            } label: {
                ComboKeyValueLabel(
                    title: memo.title,
                    // ⚠️ 잠긴 콤보에서는 값을 넘기지 않는다. 이 라벨은 → 를 누를 때마다 값을
                    //    잠깐 비추는데(디졸브), 잠가 둔 값이 화면에 비치면 잠근 뜻이 사라진다.
                    //    (게다가 잠긴 값은 암호문이라 비쳐도 읽을 것이 없다.)
                    value: memo.isSecure ? "" : current,
                    masked: memo.isSecure,
                    fontSize: buttonFontSize,
                    titleColor: theme.text,
                    valueColor: theme.textMuted,
                    accent: theme.accent,
                    accentSoft: theme.accentSoft,
                    flashToken: comboFlash[memo.id] ?? 0
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .frame(height: buttonHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(KeycapPressReporter(pressed: pressedBinding))

            // 두 키 사이의 '틈'이 아니라 하나의 캡에 파인 '홈'으로 읽히도록 옅게.
            Rectangle()
                .fill(theme.divider.opacity(0.6))
                .frame(width: 1, height: buttonHeight * 0.42)

            // 오른쪽 1/3 - 다음 값으로 전환(값이 잠깐 보였다 사라짐).
            Button {
                advanceComboValue(memo: memo, count: values.count)
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: buttonFontSize * 0.9, weight: .semibold))
                    Text("\(idx + 1)/\(values.count)")
                        .font(.system(size: buttonFontSize * 0.6, weight: .medium))
                }
                // 가리키는 중에는 흐린 회색이 아니라 **강조색**으로 선다.
                // 물결만으로는 자리가 좁아 눈에 안 걸린다(실측).
                .foregroundColor(guided == .next ? theme.accent : theme.textMuted)
                .frame(width: comboNextWidth)
                .frame(height: buttonHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(KeycapPressReporter(pressed: pressedBinding))
        }
        .background(
            keycapShape
                .foregroundColor(keyColor)
                .overlay(
                    Group {
                        if let catColor {
                            keycapShape
                                .fill(catColor.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
                )
                .overlay(keycapSheen)
                .shadow(color: Color.black.opacity(skin.shadowOpacity), radius: 2, y: 1)
        )
        // 점선 테두리(콤보 구분) - "메모 구분 표시" 설정이 켜졌을 때만(iOS와 동일하게 기본 심플).
        .overlay(
            keycapShape
                .strokeBorder(visualCuesVisible ? Color.orange : .clear,
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
        )
        .clipShape(keycapShape)
        // ⚠️ 물결은 **`clipShape` 뒤에** 얹는다. 좌·우 버튼에 직접 달았더니 키캡 윤곽에
        //    통째로 잘려 나가, 번져 나가야 할 물결이 잘린 조각으로 보였다. 물결은
        //    키 밖으로 나가는 것이 전부라 안쪽으로 가두면 뜻이 사라진다.
        //    (자리는 좌·우 버튼과 똑같이 잡는다 - 오른쪽 폭 + 홈 1pt)
        .overlay {
            if guided == .value {
                KeyRipple(shape: RoundedRectangle(cornerRadius: 8, style: .continuous),
                          color: theme.accent, reach: 7)
                    .padding(.trailing, comboNextWidth + 1)
            }
        }
        .overlay(alignment: .trailing) {
            if guided == .next {
                KeyRipple(shape: RoundedRectangle(cornerRadius: 8, style: .continuous),
                          color: theme.accent, reach: 7)
                    .frame(width: comboNextWidth)
            }
        }
        // 통짜 키캡 - 좌·우 어디를 눌러도 한 덩어리로 내려앉는다.
        .modifier(KeycapSurface(skin: skin,
                                cornerRadius: keycapRadius,
                                skirtColor: keycapSkirtColor,
                                pressed: pressedComboId == memo.id,
                                enabled: keycapPressEnabled))
    }

    /// 콤보 키 오른쪽(다음 값) 칸의 폭. 버튼과 그 위의 물결이 **같은 값**을 봐야
    /// 가리키는 자리가 어긋나지 않는다.
    private var comboNextWidth: CGFloat {
        max(46, buttonHeight)
    }

    private func insertComboValue(memo: Memo, value: String) {
        if isSearching {
            withAnimation(.easeOut(duration: 0.18)) {
                hangul.reset()
                searchQuery = ""
                isSearching = false
            }
        }
        NotificationCenter.postOnMain(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: value,
            userInfo: ["memoId": memo.id, "skipCombo": true]
        )
    }

    private func advanceComboValue(memo: Memo, count: Int) {
        guard count > 0 else { return }
        KeyboardHaptics.softTap()
        let cur = comboValueIndex[memo.id] ?? 0
        comboValueIndex[memo.id] = (cur + 1) % count
        // 값을 잠깐 보여줬다 사라지게(디졸브) 트리거.
        comboFlash[memo.id] = (comboFlash[memo.id] ?? 0) + 1
        // ⚠️ 여기서는 **글이 하나도 안 들어간다** - 값만 바뀐다. 그래서 `.memoUsed` 가
        //    나가지 않고, 튜토리얼은 이 걸음을 지났는지 알 길이 없었다. 따로 알린다.
        NotificationCenter.postOnMain(name: .comboValueAdvanced, object: nil,
                                        userInfo: ["memoId": memo.id])
    }

    private func memoAccessibilityLabel(for memo: Memo) -> String {
        var parts: [String] = [memo.title]
        if memo.isSecure { parts.append(NSLocalizedString("보안 단축어", comment: "VoiceOver: secure memo badge")) }
        if memo.isTemplate { parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge")) }
        if memo.isCombo { parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge")) }
        if memo.contentType == .image || memo.contentType == .mixed {
            parts.append(NSLocalizedString("이미지 단축어", comment: "VoiceOver: image memo"))
        } else if !memo.isSecure, !memo.value.isEmpty {
            // ⚠️ 잠긴 단축어의 값은 읽어 주지 않는다. 저장된 것이 암호문("smenc1:...")이라
            //    보이스오버가 base64 를 40글자 읽는 꼴이었고, 잠근 것을 소리로 흘리는 길이기도
            //    했다. 화면에 안 보여 주기로 한 것은 소리로도 안 나가야 한다.
            let preview = String(memo.value.strippingTemplateBraces.prefix(40))
            parts.append(preview)
        }
        return parts.joined(separator: ", ")
    }

    private func memoAccessibilityHint(for memo: Memo) -> String {
        if memo.isTemplate {
            return NSLocalizedString("탭하면 빈칸을 채워 붙여넣습니다", comment: "Template memo button hint")
        } else if memo.isCombo {
            return NSLocalizedString("탭하면 여러 값이 순서대로 입력됩니다", comment: "Combo memo button hint")
        } else if memo.isSecure {
            return NSLocalizedString("탭하면 PIN 인증 후 붙여넣기합니다", comment: "Secure memo button hint")
        } else {
            return NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Clipboard item copy hint")
        }
    }

    /// attachedTemplateId가 있는 메모용 분할 버튼 - 왼쪽: 메모값만 입력, 오른쪽: 템플릿 포함 입력
    /// 키보드에서 메모 길게 누르면 떠오르는 미리보기 - Mail 스타일
    private func memoButtonAction(for memo: Memo, bypassTemplate: Bool = false) {
        // 길게 눌러 복사한 직후에 들어온 탭은 무시한다
        // 복사만 하려 했는데 글까지 입력되면 지우는 일이 하나 더 생긴다.
        if suppressTapAfterLongPress == memo.id {
            suppressTapAfterLongPress = nil
            return
        }

        // ⚠️ 여기서 햅틱을 울리지 않는다. 각 종착지가 자기 피드백을 갖고 있어서
        //    여기서도 울리면 한 번 눌렀는데 "또깍-또깍" 두 번 난다.
        //    (일반 삽입 → stamp / 이미지 → 복사 완료 / 보안 → 인증 UI)

        if isSearching {
            withAnimation(.easeOut(duration: 0.18)) {
                hangul.reset()
                searchQuery = ""
                isSearching = false
            }
        }

        let proceed = {
            if memo.contentType == .image || memo.contentType == .mixed {
                copyImageToClipboard(memo: memo)
                return
            }
            if memo.isSecure {
                authenticateAndInsert(memo: memo, bypassTemplate: bypassTemplate)
                return
            }
            insertMemo(memo, bypassTemplate: bypassTemplate)
        }

        proceed()
    }

    private func insertMemo(_ memo: Memo, bypassTemplate: Bool = false) {
        // 보안 메모면 복호화한 값을 넣는다(PIN 인증 후 호출됨). 키 미동기화로 복호화 불가면 중단.
        let valueToInsert: String
        if SecureMemoCrypto.isEncrypted(memo.value) {
            guard let decrypted = SecureMemoCrypto.decrypt(memo.value) else {
                print("🔒 [insertMemo] 보안 키 미동기화 - 복호화 불가, 삽입 중단")
                return
            }
            valueToInsert = decrypted
        } else {
            valueToInsert = memo.value
        }
        let userInfo: [String: Any] = ["memoId": memo.id]
        NotificationCenter.postOnMain(
            name: NSNotification.Name(rawValue: "addTextEntry"),
            object: valueToInsert,
            userInfo: userInfo
        )
    }

    /// - Parameter comboIndex: 잠긴 콤보에서 고른 단계. nil 이면 본체 값을 넣는다.
    private func authenticateAndInsert(memo: Memo, bypassTemplate: Bool = false, comboIndex: Int? = nil) {
        let storedHash = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardSecurePinHash) ?? ""
        guard !storedHash.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation { showPinNotSetToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation { showPinNotSetToast = false }
            }
            return
        }
        pendingSecureMemo = memo
        pendingBypassTemplate = bypassTemplate
        pendingSecureComboIndex = comboIndex
        enteredPIN = ""
        pinEntryWrong = false
        showPINEntry = true
    }

    /// 잠긴 콤보의 한 단계를 복호화해서 넣는다. 키가 아직 안 내려왔으면 넣지 않는다
    /// (암호문을 그대로 흘리면 상대에게 "smenc1:..." 이 붙여넣어진다).
    private func insertSecureComboValue(memo: Memo, index: Int) {
        let raw = memo.comboValues.indices.contains(index) ? memo.comboValues[index] : memo.value
        guard !raw.isEmpty else { return }
        let value: String
        if SecureMemoCrypto.isEncrypted(raw) {
            guard let decrypted = SecureMemoCrypto.decrypt(raw) else {
                print("🔒 [insertSecureComboValue] 보안 키 미동기화 - 복호화 불가, 삽입 중단")
                return
            }
            value = decrypted
        } else {
            value = raw
        }
        insertComboValue(memo: memo, value: value)
    }

    private func verifyPIN() {
        let digest = SHA256.hash(data: Data(enteredPIN.utf8))
        let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
        let storedHash = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardSecurePinHash) ?? ""
        if hash == storedHash {
            showPINEntry = false
            if let memo = pendingSecureMemo {
                if let index = pendingSecureComboIndex {
                    insertSecureComboValue(memo: memo, index: index)
                } else {
                    insertMemo(memo, bypassTemplate: pendingBypassTemplate)
                }
            }
            pendingSecureMemo = nil
            pendingSecureComboIndex = nil
            enteredPIN = ""
            pinEntryWrong = false
            pendingBypassTemplate = false
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            enteredPIN = ""
            pinEntryWrong = true
        }
    }

    /// 이미지 단축어를 클립보드에 얹는다.
    ///
    /// ⚠️ **`UIImage` 를 거치지 않는다.** 예전에는 `loadImage()` 로 원본을 통째로 펼친 뒤
    ///    `UIPasteboard.general.image = image` 로 넘겼다. 그러면 펼친 것(3000x2000 이면 24MB)과
    ///    다시 인코딩한 것이 동시에 잡히는데, **키보드 익스텐션의 메모리 한도는 그걸 못 견딘다.**
    ///    한도를 넘으면 iOS 가 익스텐션을 조용히 죽인다 - 사용자 눈에는 에러도 없이
    ///    "눌렀는데 아무 일도 안 일어남" 으로만 보인다(사용자 신고: "앱에서는 복사되는데
    ///    키보드에서는 안 된다"). 앱에서만 되던 이유가 이것이다. 앱에는 그 한도가 없다.
    ///
    ///    파일 바이트를 그대로 건네면 펼치는 일도 인코딩도 없다.
    ///    자세한 것은 `docs/postmortem/KEYBOARD_IMAGE_MEMORY.md`.
    private func copyImageToClipboard(memo: Memo) {
        guard requireFullAccess() else { return }
        let fileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        guard !fileName.isEmpty,
              let data = MemoStore.shared.imageData(fileName: fileName) else {
            print("⚠️ [KeyboardView] 이미지 로드 실패: \(memo.title)")
            return
        }
        UIPasteboard.general.setData(data, forPasteboardType: MemoStore.shared.imagePasteboardType(fileName: fileName))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("✅ [KeyboardView] 이미지 클립보드 복사 완료: \(memo.title) (\(data.count) bytes)")

        // 앱 무대에서는 복사에서 끝내지 않는다 - 입력창이 우리 것이라 붙여넣은 모습까지
        // 보여줄 수 있다. 익스텐션에서는 남의 텍스트 필드라 넣을 길이 없어 복사가 끝이다.
        if hostKind == .inApp {
            NotificationCenter.postOnMain(
                name: .addImageEntry,
                object: fileName,
                userInfo: ["memoId": memo.id]
            )
        }

        withAnimation { showImageCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showImageCopiedToast = false }
        }
    }

    /// 클립보드를 만지기 전에 반드시 통과해야 하는 관문.
    ///
    /// 전체 접근이 꺼져 있으면 `UIPasteboard` 접근을 iOS가 막는데 **에러도 예외도 없다.**
    /// 확인 없이 호출하면 사용자에게는 "눌렀는데 아무 일도 안 일어남"으로만 보인다.
    /// - Returns: 진행해도 되면 true. false면 이미 안내 토스트를 띄웠다.
    private func requireFullAccess() -> Bool {
        guard KeyboardCapability.hasFullAccess else {
            print("⚠️ [KeyboardView] 전체 접근 꺼짐 - 클립보드 동작 차단")
            showFullAccessNotice()
            return false
        }
        return true
    }

    // MARK: - 앱 안에서의 복사(길게 누르기)

    /// 길게 누르면 클립보드로 - **앱 안에서만.**
    ///
    /// 익스텐션에서는 같은 길게 누르기가 값을 크게 펼친다(`KeyboardMemoPeek`). 앱 무대에서는
    /// 목록으로 건너가면 값을 볼 수 있으므로, 여기서는 바로 복사한다.
    /// **고치는 일은 목록 화면에서** 한다. 무대는 써 보는 자리다.
    private struct InAppLongPressCopy: ViewModifier {
        let enabled: Bool
        let onCopy: () -> Void
        @Binding var suppressed: UUID?
        let memoId: UUID

        func body(content: Content) -> some View {
            if enabled {
                content
                    .onLongPressGesture(minimumDuration: 0.45) {
                        suppressed = memoId
                        onCopy()
                    }
                    // 길게 누르기를 모르는 사람도, 손이 불편한 사람도 쓸 수 있게.
                    .accessibilityAction(named: Text(NSLocalizedString("클립보드에 복사", comment: "Accessibility action: copy"))) {
                        onCopy()
                    }
            } else {
                content
            }
        }
    }

    // MARK: - 고친 자리 제안

    /// "매번 여기만 바꾸시네요" 한 줄. 누르면 그 자리에서 바꿔 준다.
    ///
    /// ⚠️ 단축어당 한 번만 뜬다(`EditPattern.markAsked` 는 띄우는 쪽에서 이미 찍었다).
    ///    되풀이하면 그때부터 광고로 읽힌다.
    /// ⚠️ 거절은 **거절로 남긴다.** 닫기만 하고 잊으면 다음에 또 물어보게 된다.
    @ViewBuilder
    private func editSuggestionBar(_ suggestion: (memoId: UUID, kind: EditPattern.Suggestion)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: AppSymbol.textCursor)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))

            Text(suggestion.kind == .makeTemplate
                 ? NSLocalizedString("넣고 나서 매번 같은 자리만 바꾸시네요. 그 자리를 빈칸으로 만들까요?",
                                     comment: "Suggestion bar: turn the repeatedly edited spot into a template placeholder")
                 : NSLocalizedString("넣고 나서 매번 같은 곳을 같게 고치시네요. 단축어를 그 값으로 바꿀까요?",
                                     comment: "Suggestion bar: update the snippet itself with the repeated correction"))
                .font(.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(NSLocalizedString("아니요", comment: "Decline the edit-pattern suggestion")) {
                EditPattern.markDeclined(for: suggestion.memoId)
                withAnimation { editSuggestion = nil }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))

            Button(NSLocalizedString("바꾸기", comment: "Accept the edit-pattern suggestion")) {
                let changed = EditPattern.apply(suggestion.kind, memoId: suggestion.memoId)
                withAnimation { editSuggestion = nil }
                if changed {
                    loadAllMemos()
                    KeyboardHaptics.tap()
                    withAnimation { showEditAppliedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                        withAnimation { showEditAppliedToast = false }
                    }
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 복사 버튼의 동작 - 이미지 문구는 이미지를, 그 밖에는 값을 클립보드에 넣는다.
    ///
    /// ⚠️ **보안 단축어는 여기서 나가지 않는다.** 길게 누르기는 인증을 거치지 않는 길이라,
    ///    값을 클립보드에 얹으면 잠가 둔 의미가 사라진다(화면에 안 보여줘도 붙여넣으면 나온다).
    ///    입력은 PIN 을 받고 나서만 되는데 복사만 무료 통행이던 구멍을 막는다.
    private func copyMemoInApp(_ memo: Memo) {
        guard !memo.isSecure else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation { showSecureCopyBlockedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation { showSecureCopyBlockedToast = false }
            }
            return
        }
        if memo.contentType == .image || memo.contentType == .mixed,
           !(memo.imageFileNames.first ?? memo.imageFileName ?? "").isEmpty {
            copyImageToClipboard(memo: memo)
            return
        }
        guard requireFullAccess() else { return }
        UIPasteboard.general.string = memo.value
        KeyboardHaptics.tap()
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }

    /// 롱프레스 메뉴의 "클립보드에 복사" - 전체 접근이 있어야 동작한다.
    private func copyTextToClipboard(_ text: String) {
        guard requireFullAccess() else { return }
        UIPasteboard.general.string = text
        KeyboardHaptics.tap()
    }

    private func showFullAccessNotice() {
        KeyboardHaptics.softTap()
        withAnimation { showFullAccessToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showFullAccessToast = false }
        }
    }

    private func memoButtonLabel(for memo: Memo, catColor: Color?, useTemplate: Bool = false) -> some View {
        let style = typeStyle(for: memo, useTemplate: useTemplate)
        return ZStack {
            // 기본 키 색(커스텀 색 설정 존중) 위에, 사용자 카테고리가 있을 때만 그 색을 옅게 틴트.
            // 제목 가독성을 위해 라이트 0.14 / 다크 0.22로 약하게만 입힌다.
            keycapShape
                .foregroundColor(keyColor)
                .overlay(
                    Group {
                        if let catColor {
                            keycapShape
                                .fill(catColor.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
                )
                .overlay(keycapSheen)
                .shadow(color: Color.black.opacity(skin.shadowOpacity), radius: 2, y: 1)

            // 메모 칸 안 텍스트는 제목. 보안 메모 자물쇠는 구분 표시 ON일 때만(앱과 동일, 기본 숨김).
            // 내용 힌트가 켜져 있으면 셀이 2초 머문 뒤 제목이 잠시 내용으로 바뀌었다 돌아온다.
            HStack(spacing: 4) {
                // 타입 심볼 - 앱 카드와 **같은 그림**(MemoTypeStyle). 예전에는 자물쇠만 있어서
                // 같은 템플릿 단축어가 앱에서는 지팡이, 키보드에서는 아무 표시도 없었다.
                if visualCuesVisible, MemoTypeStyle.hasDistinctType(memo, forceTemplate: useTemplate) {
                    Image(systemName: MemoTypeStyle.symbolName(for: memo, forceTemplate: useTemplate))
                        .font(.system(size: buttonFontSize * 0.82, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                        .accessibilityHidden(true)
                }
                MemoTitleHintSwap(title: memo.title,
                                  hint: keyboardHintText(for: memo),
                                  seed: memo.id.hashValue,
                                  fontSize: buttonFontSize,
                                  titleColor: theme.text,
                                  hintColor: theme.textMuted,
                                  accent: theme.accent,
                                  accentSoft: theme.accentSoft)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(10)
        }
        .frame(height: buttonHeight)
        // 메모 칸 기본 테두리 - 구분 표시 ON일 때만 (기본은 배경·그림자만으로 깔끔하게).
        .overlay(
            keycapShape
                .strokeBorder(visualCuesVisible ? theme.divider : .clear, lineWidth: 1)
        )
        // 타입 구분 테두리(템플릿/콤보/보안) - 색맹 친화, 기본 테두리 위에 덧입힌다.
        .overlay(
            keycapShape
                .strokeBorder(style.color,
                              style: StrokeStyle(lineWidth: style.lineWidth, dash: style.dash))
        )
    }

    /// 키보드 셀 내용 힌트 텍스트 - 설정 OFF면 nil(스왑 없음).
    /// 사용자가 메모에 힌트를 직접 적었으면 그것이 우선이되, 메모별 동기화 토글
    /// (hintShownOnKeyboard)이 꺼져 있으면 키보드에서는 스왑하지 않는다.
    /// ⚠️ 자동 요약은 보안 메모 내용 노출 금지(값이 암호문이기도 함) → nil. 앱 카드와 동일 기준.
    private func keyboardHintText(for memo: Memo) -> String? {
        guard contentHintEnabled else { return nil }
        if let custom = memo.hint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return memo.hintShownOnKeyboard ? custom : nil
        }
        guard !memo.isSecure else { return nil }
        let text = MemoPreviewFormatter.preview(for: memo, resolvedType: memo.autoDetectedType)
        return text.isEmpty ? nil : text
    }

    /// 메모 타입 시각 스타일 - 테두리 색·dash 패턴. 색맹 보조용 (색 + 패턴 이중 큐).
    /// iOS "색상 없이 구별"이 켜진 경우에만 노출(기본은 칸 경계 테두리만).
    /// 우선순위: useTemplate(템플릿 적용 셀) > 콤보 > 보안 > 본체 템플릿.
    /// 사용자가 고른 키캡 물성 프리셋. 색은 건드리지 않는다(테마·커스텀 색이 담당).
    private var skin: KeyboardSkin {
        KeyboardSkin.resolved(keyboardSkinRaw)
    }

    /// 키캡 모서리 - 테마 스케일을 스킨 비율로 조정한다.
    private var keycapRadius: CGFloat {
        skin.cornerRadius(base: theme.radiusMd)
    }

    /// 키캡 윤곽.
    /// ⚠️ 키를 그리는 곳이 여럿이라(배경·틴트·표면광·테두리·클립·가리키는 빛) 모양을
    ///    한 곳에서 꺼내 쓴다. 한 군데만 사각형으로 남으면 그 겹만 튀어나온다.
    private var keycapShape: KeycapShape {
        KeycapShape(radius: keycapRadius)
    }

    /// 눌림을 그릴 수 있는 상태인가. `KeycapButtonStyle`과 같은 조건
    /// 연출 토글이 꺼졌거나, 동작 줄이기가 켜졌거나, 두께가 0인 스킨이면 내려앉지 않는다.
    private var keycapPressEnabled: Bool {
        KeyboardHaptics.delightEnabled && !reduceMotion && skin.skirtDepth > 0
    }

    /// 키캡 옆면(스커트) 색 - 키가 얹혀 있는 두께.
    /// 사용자가 키 색을 바꿔도 항상 "그 색의 그늘"이 되도록 검정을 깔아 만든다.
    private var keycapSkirtColor: Color {
        Color.black.opacity(skin.skirtOpacity(isDark: theme.isDark))
    }

    /// 키캡 표면광 - 앱 카드의 유리에 대응하는 "빛을 받는 물성".
    ///
    /// ⚠️ 여기에는 일부러 `glassEffect` 를 쓰지 않는다. 유리는 뒤가 비쳐야 의미가 있는데
    ///    키보드 배경은 불투명해서 비칠 것이 없다. 비용(익스텐션 메모리·GPU)만 내고
    ///    납작한 반투명 판이 될 뿐이다. 대신 같은 언어의 다른 재질 - 위에서 빛을 받아
    ///    윗면이 밝고 아래로 갈수록 어두워지는 **키캡**으로 간다.
    ///    (눌리는 동작은 `KeycapButtonStyle` 이 담당한다)
    private var keycapSheen: some View {
        keycapShape
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(skin.sheenOpacity(isDark: theme.isDark)), .clear],
                    startPoint: .top, endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }

    /// 앱 카드와 **같은 규칙**을 본다 (DesignSystem/MemoTypeStyle.swift).
    private func typeStyle(for memo: Memo, useTemplate: Bool) -> TypeVisualStyle {
        MemoTypeStyle.border(for: memo,
                             visualCuesVisible: visualCuesVisible,
                             forceTemplate: useTemplate)
    }

    // MARK: - 순서 바꾸기

    // 왜 여기에 있는가: 자주 쓰는 문구가 저장한 순서에 묻힌다는 이야기가 들어왔다.
    // 앱에는 이미 '순서 바꾸기'가 있지만, 문구를 실제로 고르는 자리는 키보드다.
    // 앱까지 다녀와야 순서를 고칠 수 있으면 대개 안 고친다.
    //
    // ⚠️ 들어오는 길은 **값 판 안의 버튼** 하나다. 길게 누르기는 그 판이 이미 쓰고 있어서
    //    (`MemoPeekOnLongPress`) 같은 손짓에 둘을 얹으면 한 번 눌렀는데 판도 열리고
    //    키도 들린다. 한 손짓에 주인은 하나여야 한다.

    /// 순서를 바꾸는 중인가.
    @State private var isReorderMode = false
    /// 끌어서 실시간으로 바뀌는 작업용 목록.
    ///
    /// ⚠️ 지금 보는 페이지가 아니라 **보이는 전체**다. 페이지 안에서만 바꾸게 하면
    ///    "1번 페이지의 3번을 2번 페이지 맨 위로" 같은 걸 아예 할 수 없다.
    @State private var reorderList: [Memo] = []
    /// 지금 손에 들려 있는 키. nil 이면 아무것도 안 들고 있다.
    @State private var draggingMemoId: UUID?
    /// 들고 있는 키가 지금 있는 자리(그리드 좌표계).
    @State private var dragLocation: CGPoint?
    /// 키마다의 자리. 손가락 밑에 어느 키가 있는지는 이 표로만 안다.
    @State private var reorderCellFrames: [UUID: CGRect] = [:]
    /// 방금 자리를 내준 키. 같은 키를 연달아 다시 밀지 않도록 기억해 둔다.
    @State private var lastReorderHitId: UUID?

    /// 자리를 재는 좌표계 이름. 재는 쪽(셀)과 그리는 쪽(떠 있는 키)이 같은 자를 써야 한다.
    private static let reorderSpace = "reorderSpace"

    /// 순서 바꾸기 안내 줄. 헤더 자리를 대신 쓴다.
    private var reorderBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.arrowUpArrowDown)
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(NSLocalizedString("잠깐 눌렀다 끌면 자리가 바뀌어요",
                                       comment: "Keyboard reorder mode: how to move a key"))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.text)
                // 바꾼 순서가 앱에도 간다는 걸 **미리** 적는다. 끝난 뒤 알려 주면
                // 그때는 이미 "여기서만 바뀌나" 하고 앱을 열어 본 뒤다.
                Text(NSLocalizedString("바꾼 순서는 앱에도 그대로 반영돼요",
                                       comment: "Keyboard reorder mode: the order syncs to the app"))
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
            }
            Spacer(minLength: 0)
            Button(action: exitReorderMode) {
                Text(NSLocalizedString("완료", comment: "Keyboard reorder mode: done"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.accentFg)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(theme.surface)
    }

    /// 순서를 바꾸는 격자.
    private var reorderGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 10) {
                ForEach(reorderList) { memo in
                    reorderCell(for: memo)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .coordinateSpace(name: Self.reorderSpace)
        .onPreferenceChange(ReorderCellFrameKey.self) { reorderCellFrames = $0 }
        // 들고 있는 키는 격자 **안이 아니라 위에** 그린다. 격자 안에서 옮기면
        // 자리를 재는 자와 자리를 옮기는 손이 서로를 물어 좌표가 떨린다
        // (잰 값에 오프셋이 섞이고, 그 값으로 다시 오프셋을 정하게 된다).
        .overlay { carriedKey }
    }

    /// 격자 안의 키 하나. 순서 바꾸기 중에는 **눌러도 글이 안 들어간다** -
    /// 버튼이 아니라 겉모습(`memoButtonLabel`)만 쓴다.
    ///
    /// 이미지 단축어도 여기서는 같은 이름표 모양으로 선다. 옮길 때 보는 것은 제목이고,
    /// 크기가 제각각이면 어디로 들어가는지가 오히려 안 읽힌다.
    private func reorderCell(for memo: Memo) -> some View {
        let isCarried = draggingMemoId == memo.id
        return memoButtonLabel(for: memo, catColor: categoryColorFor(memo))
            // 들려 나간 자리는 빈 자리로 남는다 - 어디서 떠났는지가 보여야 한다.
            .opacity(isCarried ? 0.22 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ReorderCellFrameKey.self,
                        value: [memo.id: geo.frame(in: .named(Self.reorderSpace))]
                    )
                }
            )
            .contentShape(Rectangle())
            .gesture(reorderDrag(for: memo))
            // 끌기는 손이 불편한 사람에게는 없는 길이다. 한 칸씩 옮기는 길을 따로 둔다.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(memo.title)
            .accessibilityValue(reorderPositionLabel(for: memo))
            .accessibilityAction(named: Text(NSLocalizedString("앞으로 옮기기",
                                                              comment: "Reorder accessibility action: move earlier"))) {
                shiftCarried(memo, by: -1)
            }
            .accessibilityAction(named: Text(NSLocalizedString("뒤로 옮기기",
                                                              comment: "Reorder accessibility action: move later"))) {
                shiftCarried(memo, by: 1)
            }
    }

    /// 지금 손에 들려 격자 위에 떠 있는 키.
    @ViewBuilder
    private var carriedKey: some View {
        if let id = draggingMemoId,
           let memo = reorderList.first(where: { $0.id == id }),
           let point = dragLocation,
           let width = reorderCellFrames[id]?.width {
            memoButtonLabel(for: memo, catColor: categoryColorFor(memo))
                .frame(width: width)
                .scaleEffect(1.06)
                .shadow(color: Color.black.opacity(0.28), radius: 8, y: 4)
                .position(x: point.x, y: point.y)
                .allowsHitTesting(false)
        }
    }

    /// "3번째, 전체 12개" - 화면을 못 보는 사람에게 지금 자리를 알려 준다.
    private func reorderPositionLabel(for memo: Memo) -> String {
        guard let index = reorderList.firstIndex(where: { $0.id == memo.id }) else { return "" }
        return String(format: NSLocalizedString("%1$d번째, 전체 %2$d개",
                                                comment: "Reorder position: current index of total"),
                      index + 1, reorderList.count)
    }

    /// 키를 드는 손짓.
    ///
    /// ⚠️ 잠깐 누른 **뒤에** 끌어야 든다(`sequenced`). 바로 끌리게 하면 목록을 훑어보려는
    ///    쓸어내림까지 키를 들어 올려, 순서 바꾸기 중에는 스크롤을 아예 못 하게 된다.
    private func reorderDrag(for memo: Memo) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0,
                                           coordinateSpace: .named(Self.reorderSpace)))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if draggingMemoId != memo.id {
                    draggingMemoId = memo.id
                    lastReorderHitId = nil
                    KeyboardHaptics.mediumTap()
                }
                dragLocation = drag.location
                moveCarriedKey(to: drag.location)
            }
            .onEnded { _ in dropCarriedKey() }
    }

    /// 손가락 밑에 다른 키가 오면 그 자리를 넘겨받는다.
    private func moveCarriedKey(to point: CGPoint) {
        guard let carried = draggingMemoId,
              let from = reorderList.firstIndex(where: { $0.id == carried }) else { return }
        guard let hit = reorderCellFrames.first(where: { $0.key != carried && $0.value.contains(point) })?.key,
              hit != lastReorderHitId,
              let to = reorderList.firstIndex(where: { $0.id == hit }) else { return }
        lastReorderHitId = hit
        withAnimation(.easeInOut(duration: 0.18)) {
            let item = reorderList.remove(at: from)
            reorderList.insert(item, at: to)
        }
        KeyboardHaptics.softTap()
    }

    /// 손을 뗐다.
    ///
    /// ⚠️ **뗄 때마다 적는다.** 키보드는 우리가 내리는 게 아니라 호스트 앱이 내린다 -
    ///    '완료'를 눌러야만 적으면, 옮겨 놓고 그대로 다른 앱으로 넘어간 사람은
    ///    다음에 열었을 때 아무것도 안 바뀐 화면을 본다.
    private func dropCarriedKey() {
        guard draggingMemoId != nil else { return }
        draggingMemoId = nil
        dragLocation = nil
        lastReorderHitId = nil
        KeyboardHaptics.tap()
        saveReorder()
    }

    /// 접근성 동작으로 한 칸 옮긴다(끌기 없이).
    private func shiftCarried(_ memo: Memo, by delta: Int) {
        guard let from = reorderList.firstIndex(where: { $0.id == memo.id }) else { return }
        let to = from + delta
        guard reorderList.indices.contains(to) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            let item = reorderList.remove(at: from)
            reorderList.insert(item, at: to)
        }
        KeyboardHaptics.softTap()
        saveReorder()
    }

    /// 지금 순서를 앱과 같은 자리에 적고, 이 화면의 목록도 그 순서로 맞춘다.
    private func saveReorder() {
        KeyboardMemoFeed.commitManualOrder(reorderList, within: clipMemos)
        loadAllMemos()
    }

    private func enterReorderMode() {
        peekMemo = nil
        reorderList = allMemos
        draggingMemoId = nil
        dragLocation = nil
        lastReorderHitId = nil
        KeyboardHaptics.mediumTap()
        withAnimation(.easeInOut(duration: 0.22)) { isReorderMode = true }
    }

    private func exitReorderMode() {
        saveReorder()
        draggingMemoId = nil
        dragLocation = nil
        lastReorderHitId = nil
        reorderCellFrames = [:]
        KeyboardHaptics.tap()
        withAnimation(.easeInOut(duration: 0.22)) { isReorderMode = false }
    }

    // MARK: - Data Loading

    private func loadAllMemos() {
        // 앞에서 그냥 자르지 않는다. 심어 준 샘플이 앞자리를 차지한 만큼 자기 단축어가
        // 뒤로 밀려 안 보이게 되는데, 그러면 한도에서 빼 준 것을 화면에서 도로 세는 셈이다.
        allMemos = ProFeatureManager.memosWithinLimit(clipMemos)
    }

    // MARK: - Free tier

    private var isFreeUser: Bool {
        !ProFeatureManager.hasFullAccess
    }

    private var totalMemoCount: Int { clipMemos.count }

    /// 한도가 세는 개수 - **자기 것만.** 온보딩이 심어 준 샘플은 칸을 차지하지 않는다.
    /// 앱의 설정 화면·저장 관문과 같은 값을 봐야 한 화면이 두 말을 하지 않는다.
    private var ownMemoCount: Int { ProFeatureManager.ownMemoCount(clipMemos) }

    private var hiddenMemoCount: Int {
        guard isFreeUser else { return 0 }
        return max(0, ownMemoCount - ProFeatureManager.memoLimit)
    }

    // MARK: - PIN Entry Overlay

    private var pinEntryOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: AppSymbol.lockFill)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("보안 PIN 입력", comment: "PIN entry overlay title"))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 14)

                // ⚠️ 틀림 안내와 **같은 줄자리**를 쓴다. 키보드 높이 안에 숫자판까지 들어가야 해서
                //    줄을 하나 더 늘리면 작은 기기에서 아래가 잘린다.
                //
                // 왜 여기서 Face ID 를 말하나: 앱에서는 Face ID 로 열리는데 키보드에서만 번호를
                // 묻는다. 그 차이를 설명하지 않으면 고장으로 읽힌다(실제로 그런 문의가 왔다).
                // iOS 가 키보드 익스텐션에 LocalAuthentication 을 안 열어 준다.
                // 자세한 것은 docs/postmortem/KEYBOARD_FACEID.md
                if pinEntryWrong {
                    Text(NSLocalizedString("PIN이 올바르지 않습니다", comment: "PIN wrong error"))
                        .font(.caption2)
                        .foregroundColor(.red)
                } else {
                    Text(NSLocalizedString("키보드에서는 Face ID를 쓸 수 없어 번호로 엽니다", comment: "PIN entry: why not Face ID"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                // 4-dot indicator
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < enteredPIN.count ? Color.orange : Color(UIColor.systemGray4))
                            .frame(width: 11, height: 11)
                    }
                }
                .padding(.vertical, 4)

                // Number grid
                VStack(spacing: 4) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.first) { row in
                        HStack(spacing: 4) {
                            ForEach(row, id: \.self) { n in
                                pinOverlayDigitKey(String(n))
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        pinOverlayCancelKey
                        pinOverlayDigitKey("0")
                        pinOverlayBackspaceKey
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 10)
            )
            .padding(.horizontal, 40)
        }
    }

    private func pinOverlayDigitKey(_ digit: String) -> some View {
        Button {
            KeyboardHaptics.tap()
            guard enteredPIN.count < 4 else { return }
            enteredPIN.append(digit)
            pinEntryWrong = false
            if enteredPIN.count == 4 { verifyPIN() }
        } label: {
            Text(digit)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pinOverlayCancelKey: some View {
        Button {
            KeyboardHaptics.softTap()
            showPINEntry = false
            pendingSecureMemo = nil
            pendingSecureComboIndex = nil
            enteredPIN = ""
            pinEntryWrong = false
        } label: {
            Text(NSLocalizedString("취소", comment: "Cancel"))
                .font(.footnote.weight(.medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pinOverlayBackspaceKey: some View {
        Button {
            KeyboardHaptics.tap()
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
        } label: {
            Image(systemName: AppSymbol.deleteLeft)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace button"))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Color Helpers

    /// 메모가 **사용자가 만든 카테고리**에 속할 때만 그 카테고리 색을 반환한다.
    /// 카테고리가 없으면(자동 분류값만 있는 경우 포함) nil → 색을 입히지 않는다.
    /// (이전엔 자동 분류 타입에도 색을 반환해, 사용자 카테고리가 없는데도 메모에 색이
    ///  칠해지는 버그가 있었음. 카테고리는 이제 사용자가 직접 만들어 쓰므로 그 색만 사용.)

    private func categoryColorFor(_ memo: Memo) -> Color? {
        // 즐겨찾기는 카테고리처럼 분홍색 정체성을 갖는다 - 카테고리 색보다 우선(앱과 동일).
        if memo.isFavorite { return .clipFavorite }
        guard let idx = sharedUserCategories.firstIndex(of: memo.category) else { return nil }
        if let hex = customCategoryColors[memo.category], let c = Color(hex: hex) { return c }
        let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .indigo, .cyan]
        return palette[idx % palette.count]
    }

    private func categoryIconFor(_ memo: Memo) -> String {
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == memo.category }) {
            return type.icon
        }
        return "doc.text"
    }

    /// 카테고리 페이지 키(★all/★favorites/이름)에 대응되는 SF Symbol.
    /// 사용자 커스텀 아이콘 - userCategoryIcons_v1 에서 로드
    private var customCategoryIcons: [String: String] {
        AppGroup.defaults?
            .dictionary(forKey: DefaultsKey.userCategoryIconsV1) as? [String: String] ?? [:]
    }

    /// 사용자가 지정한 카테고리 색 - userCategoryColors_v1 에서 로드(앱과 동일 키).
    private var customCategoryColors: [String: String] {
        AppGroup.defaults?
            .dictionary(forKey: DefaultsKey.userCategoryColorsV1) as? [String: String] ?? [:]
    }

    /// 커스텀 > 인덱스 팔레트 순으로 폴백 (iOS 앱과 동일)
    private func iconForCategoryKey(_ key: String) -> String {
        if key == "★basic" { return "tray.full.fill" }
        if key == "★all" { return "square.grid.2x2.fill" }
        if key == "★favorites" { return "heart.fill" }
        if key.hasPrefix(Self.builtInPrefix) {
            return builtInIcon(String(key.dropFirst(Self.builtInPrefix.count)))
        }
        if let custom = customCategoryIcons[key] { return custom }
        let icons = ["folder.fill", "bookmark.fill", "tag.fill", "briefcase.fill",
                     "star.fill", "heart.circle.fill", "person.fill", "house.fill"]
        let idx = sharedUserCategories.firstIndex(of: key) ?? 0
        return icons[idx % icons.count]
    }

    /// iOS 앱 ClipKeyboardList.customCategoryColor과 동일한 팔레트 + 인덱스 기반
    private func colorForCategoryKey(_ key: String) -> Color {
        if key == "★basic" { return .gray }   // 앱 .basic 인디케이터 색과 동일
        if key == "★all" { return .blue }
        if key == "★favorites" { return .clipFavorite }
        if key.hasPrefix(Self.builtInPrefix) {
            return builtInTint(String(key.dropFirst(Self.builtInPrefix.count)))
        }
        if let hex = customCategoryColors[key], let c = Color(hex: hex) { return c }
        let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .indigo, .cyan]
        let idx = sharedUserCategories.firstIndex(of: key) ?? 0
        return palette[idx % palette.count]
    }

    // MARK: - Theme-derived Colors (Paper 테마 + 사용자 커스텀 오버라이드)

    /// 기본은 iOS 앱 Paper 테마. `useCustomColors=true`이면 사용자 hex로 오버라이드.
    ///
    /// ⚠️ **익스텐션에서는 기본이 투명이다.** 뒤에 시스템 키보드 재질을 깔아 두었으므로
    ///    (`KeyboardViewController.setupSystemBackdrop`) 여기서 색을 칠하면 그 재질을 가린다.
    ///    가리면 iOS 26 이 우리 뷰 **밖에** 그리는 지구본 줄과 바탕이 갈려 이음매가 보인다.
    ///    앱 안(무대)에는 그 재질이 없으니 예전대로 테마 색을 칠한다.
    ///
    ///    색을 직접 고른 사람은 그 색이 이긴다. 고른 것을 안 보여 주면 그건 고장이다.
    private var backgroundColor: Color {
        if useCustomColors, !customBgHex.isEmpty, let custom = Color(hex: customBgHex) {
            return custom
        }
        return hostKind == .inApp ? theme.bg : .clear
    }

    private var keyColor: Color {
        if useCustomColors, !customKeyHex.isEmpty, let custom = Color(hex: customKeyHex) {
            return custom
        }
        return theme.surface
    }
}

// MARK: - Memo Title ↔ Content Hint Swap

/// 키보드 메모 셀의 제목 ↔ 내용 힌트 스왑 - 키보드는 공간이 좁아 앱 카드처럼 별도 줄을
/// 두는 대신 제목 자리를 잠시 빌린다. 셀이 화면에 나타나 2초쯤 머물면 제목이 내용으로
/// 부드럽게 바뀌었다가, 잠시 후 다시 제목으로 돌아온다. 이번 등장에서 한 번만
/// 셀이 화면 밖으로 나갔다 다시 들어오면 처음부터(앱 카드 힌트와 동일 기준).
/// 셀(seed)마다 바뀌는 시점·읽히는 시간이 조금씩 달라 키보드 전체가 동시에 변하지 않는다.
/// 콤보 분할 버튼 왼쪽 라벨 - 평소엔 키(제목), flashToken이 바뀌면(→ 누르거나 처음 나타날 때)
/// 현재 값이 디졸브(블러+페이드)로 잠깐 보였다가 다시 키로 돌아온다. iOS의 값 미리보기와 같은 경험.
/// 여러 값이면 → 를 누를 때마다 값1·값2… 가 차례로 스쳐 보인다.
struct ComboKeyValueLabel: View {
    let title: String
    let value: String
    /// 잠긴 콤보. 값을 **한 번도** 비추지 않는다 - 디졸브까지 끈다.
    let masked: Bool
    let fontSize: Double
    let titleColor: Color
    let valueColor: Color
    /// 변수 칩 색 - 앱 카드와 같은 테마 토큰을 받는다.
    let accent: Color
    let accentSoft: Color
    /// → 를 누르거나 처음 나타날 때 증가 - 디졸브 미리보기를 트리거하는 토큰.
    let flashToken: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingValue = false

    var body: some View {
        ZStack {
            Text(title.templateAwareAttributed(accent: accent, accentSoft: accentSoft,
                                               font: .system(size: fontSize, weight: .semibold)))
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(titleColor)
                .opacity(showingValue ? 0 : 1)
                .blur(radius: !reduceMotion && showingValue ? 3 : 0)
            Text(value.isEmpty
                 ? AttributedString("-")
                 : value.templateAwareAttributed(accent: accent, accentSoft: accentSoft,
                                                 font: .system(size: fontSize * 0.92)))
                .font(.system(size: fontSize * 0.92))
                .foregroundColor(valueColor)
                .opacity(showingValue ? 1 : 0)
                .blur(radius: !reduceMotion && !showingValue ? 3 : 0)
        }
        // 이름이 길 때 어디를 접을지는 설정을 따른다(기본: 가운데 접기).
        .keyLabelTruncation(KeyLabelTruncation.current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        // flashToken 변경(→ 또는 최초 등장) 때마다: 값을 잠깐 보여줬다 다시 키로.
        // 잠긴 콤보에서는 아무것도 비추지 않는다(제목만 서 있는다).
        .task(id: flashToken) {
            showingValue = false
            guard !masked else { return }
            do {
                try await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeInOut(duration: 0.45)) { showingValue = true }
                try await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 0.5)) { showingValue = false }
            } catch { showingValue = false }
        }
    }
}

struct MemoTitleHintSwap: View {
    let title: String
    /// nil이면(설정 OFF·보안 메모·빈 내용) 스왑 없이 제목만 표시한다.
    let hint: String?
    /// 셀별 위상 시드(메모 id 해시) - 스왑 시점·머묾 시간에 결정적 편차를 준다.
    let seed: Int
    let fontSize: Double
    let titleColor: Color
    let hintColor: Color
    /// 변수 칩 색 - 앱 카드와 같은 테마 토큰을 받는다.
    let accent: Color
    let accentSoft: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingHint = false

    /// 최소 2초는 머문 뒤에 바뀐다(바닥값, 앱 카드 힌트와 동일) - 카드별 편차가 더해진다.
    static let baseRevealDelay: Double = 2.0
    /// 제목 ↔ 내용 전환 시간 - 키보드는 시선 바로 아래라 확 바뀌면 어지럽다. 천천히 녹아들게.
    static let swapDuration: Double = 1.0

    /// 스왑 시점 2.0~3.6s - 셀들이 하나둘 차례로 바뀐다.
    private var revealDelay: Double { Self.baseRevealDelay + unit(0) * 1.6 }
    /// 내용이 읽히는 시간 3.2~4.6s - 전환이 느려진 만큼 읽는 시간도 살짝 여유 있게.
    private var holdDuration: Double { 3.2 + unit(1) * 1.4 }

    /// seed에서 뽑은 결정적 0..<1 (salt로 서로 독립적인 값) - 같은 셀은 항상 같은 리듬.
    private func unit(_ salt: UInt64) -> Double {
        var h = UInt64(bitPattern: Int64(seed)) &+ (salt &+ 1) &* 0x9E3779B97F4A7C15
        h ^= h >> 33
        h = h &* 0xFF51AFD7ED558CCD
        h ^= h >> 33
        return Double(h % 1024) / 1024.0
    }

    var body: some View {
        ZStack {
            Text(title.templateAwareAttributed(accent: accent, accentSoft: accentSoft,
                                               font: .system(size: fontSize, weight: .semibold)))
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(titleColor)
                .opacity(showingHint ? 0 : 1)
                .blur(radius: !reduceMotion && showingHint ? 3 : 0)
            if let hint {
                Text(hint.templateAwareAttributed(accent: accent, accentSoft: accentSoft,
                                                  font: .system(size: fontSize * 0.92)))
                    .font(.system(size: fontSize * 0.92))
                    .foregroundColor(hintColor)
                    .opacity(showingHint ? 1 : 0)
                    .blur(radius: !reduceMotion && !showingHint ? 3 : 0)
            }
        }
        .keyLabelTruncation(KeyLabelTruncation.current)
        .multilineTextAlignment(.center)
        // VoiceOver는 셀 버튼의 accessibilityLabel(제목+내용)이 안내 - 일시 표시는 숨김.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .task {
            // 셀이 화면을 벗어나면 task가 취소되고, 다시 나타나면 처음부터 시작된다.
            guard hint != nil else { return }
            showingHint = false
            do {
                try await Task.sleep(for: .seconds(revealDelay))
                withAnimation(.easeInOut(duration: Self.swapDuration)) { showingHint = true }
                try await Task.sleep(for: .seconds(Self.swapDuration + holdDuration))
                withAnimation(.easeInOut(duration: Self.swapDuration)) { showingHint = false }
            } catch { /* 화면 이탈로 취소 - 다음 등장 때 다시 */ }
        }
    }
}

// MARK: - Image Memo Button

// MARK: - Keycap Press (날인)

/// 문구 버튼이 **실제로 눌리는** 스타일.
///
/// 이 앱의 입력은 도장을 찍는 동작과 같다 - 한 번 눌러서, 흔적을 남기고, 끝.
/// 그래서 버튼이 그림자를 잃으며 아래로 내려가고, 뗄 때 제자리로 돌아온다.
///
/// ⚠️ 하루 20~50번 반복되는 연출이라 0.18초를 넘기지 않는다(메인 앱 `Delight.Tier.daily`와 동일).
///    타겟이 분리돼 상수를 공유할 수 없어 값만 맞춰 둔다.
/// ⚠️ 접근성 '동작 줄이기'와 사용자 토글을 모두 존중한다.
/// 키캡의 **두께와 눌림**을 입히는 단 하나의 규칙.
///
/// 스커트는 제자리에 두고 캡만 내려앉게 하려고 offset을 두 겹으로 건다:
/// 스커트를 먼저 배경으로 붙인 뒤 전체를 내리면, 스커트의 절대 위치는 그대로이고
/// 캡만 그 위로 덮인다. (`.background` → `.offset` 순서가 핵심이다)
struct KeycapSurface: ViewModifier {
    let skin: KeyboardSkin
    let cornerRadius: CGFloat
    /// 키캡 옆면(스커트) 색. 키 색에 상관없이 어둡게 깔아 두께를 만든다.
    let skirtColor: Color
    let pressed: Bool
    /// 눌림을 그릴 수 있는 상태인가(연출 토글·동작 줄이기·두께 0 스킨 반영).
    let enabled: Bool

    func body(content: Content) -> some View {
        let travel = skin.skirtDepth
        let down = pressed && enabled

        content
            // 스커트 - 평소엔 키 아래로 삐져나와 **두께**를 만들고,
            // 누르면 키가 그 위로 내려앉아 가려진다. 이 한 겹이 "또깍"의 정체다.
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(skirtColor)
                    .offset(y: (down || !enabled) ? 0 : travel)
            )
            .offset(y: down ? travel : 0)
            // 내려갈 땐 즉각(기계식 키는 travel이 거의 없다), 올라올 땐 살짝 튕기며.
            .animation(down
                       ? .easeOut(duration: skin.pressDuration)
                       : .spring(response: skin.releaseResponse, dampingFraction: skin.releaseDamping),
                       value: down)
    }
}

struct KeycapButtonStyle: ButtonStyle {
    /// 두께·눌림 곡선을 정하는 물성 프리셋.
    let skin: KeyboardSkin
    let cornerRadius: CGFloat
    let skirtColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        // 두께가 0인 스킨(납작)은 눌림도 없다 - 내려앉을 바닥이 없기 때문.
        let enabled = KeyboardHaptics.delightEnabled && !reduceMotion && skin.skirtDepth > 0
        return configuration.label
            .modifier(KeycapSurface(skin: skin,
                                    cornerRadius: cornerRadius,
                                    skirtColor: skirtColor,
                                    pressed: configuration.isPressed,
                                    enabled: enabled))
    }
}

/// 자기 눌림 상태를 부모에게 알려 주기만 하는 스타일.
///
/// 콤보 키는 좌·우 두 영역이 각각 눌리지만 **키캡은 하나**다. 두 버튼이 각자
/// 내려앉으면 한 덩어리가 반으로 쪼개져 보인다. 그래서 눌림 표현은 부모가 통짜로
/// 그리고, 이 스타일은 "지금 눌렸다"는 사실만 올려보낸다.
struct KeycapPressReporter: ButtonStyle {
    @Binding var pressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            // 뷰 갱신 중이 아니라 갱신 이후에 반영된다 - 상태 변경 경고를 피한다.
            .onChange(of: configuration.isPressed) { _, now in pressed = now }
    }
}

// MARK: - Template Chip Rendering
// `{변수}` 칩은 앱과 키보드가 **같은 코드**를 쓴다.
// DesignSystem/TemplatePlaceholder.swift (`templateAwareAttributed`) - 양쪽 타겟에 들어간다.

// MARK: - Search Hangul Composition

/// 검색창 한글 조합 컨트롤러.
/// 검색 미니 키보드는 자모 버튼을 직접 누르는 방식이라, 자모를 그대로 append하면
/// "인사"가 "ㅇㅣㄴㅅㅏ"처럼 깨진다. 메인 입력과 동일한 `HangulComposer`(2벌식 오토마타)에
/// 통과시켜 자모를 음절로 조합한 뒤 `buffer`(가시 검색 텍스트)에 반영한다.
final class HangulSearchController: HangulInputProxy {
    /// 조합 결과가 반영된 검색 문자열 - 화면에 보이는 텍스트와 항상 일치.
    private(set) var buffer: String = ""
    private let composer = HangulComposer()

    init() { composer.proxy = self }

    /// 키 한 글자 입력 - 한글 자모는 조합되고, 영문·숫자·기호·스페이스는 현재 음절을 확정 후 그대로 삽입.
    func input(_ character: Character) { composer.input(character) }

    /// 백스페이스 - 조합 중이면 한 단계 되돌리고, 아니면 마지막 글자 삭제.
    func backspace() { composer.backspace() }

    /// 진행 중인 조합만 확정(버퍼는 유지) - 입력 언어 전환 시 반쪽 음절이 이어지지 않게 한다.
    func commitComposition() { composer.commit() }

    /// 검색 초기화 - 조합 상태와 버퍼를 모두 비운다.
    func reset() {
        composer.commit()
        buffer = ""
    }

    // MARK: HangulInputProxy
    func insertText(_ text: String) { buffer.append(text) }
    func deleteBackward() { if !buffer.isEmpty { buffer.removeLast() } }
}

// MARK: - 순서 바꾸기: 키마다의 자리

/// 격자 안 키들의 자리를 한 표로 모은다.
/// 손가락 밑에 어느 키가 있는지는 좌표 계산이 아니라 이 표를 두드려 안다 -
/// 열 개수·키 높이·여백이 설정마다 달라서, 계산으로는 어느 하나만 바뀌어도 어긋난다.
private struct ReorderCellFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

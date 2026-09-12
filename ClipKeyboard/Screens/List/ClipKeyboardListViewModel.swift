//
//  ClipKeyboardListViewModel.swift
//  ClipKeyboard
//

import SwiftUI
import LocalAuthentication
import TipKit
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
import LeeoKit
#endif

// MARK: - BuiltInCategory

/// 앱이 미리 만들어 제공하는 "기본 제공 카테고리". 사용자가 카테고리 관리에서 켜면 탭으로 노출된다.
/// 일반(문자열) 카테고리와 달리 `memo.category` 문자열이 아니라 **메모의 타입**으로 멤버십을 판정한다.
/// (요청: 필터가 아니라 카테고리로 - 사용자에겐 카테고리와 동일하게 보이되 멤버십만 타입 기준)
enum BuiltInCategory: String, CaseIterable, Hashable {
    case templates   // 템플릿만
    case textMemos   // 메모+템플릿 (이미지·콤보 제외)
    case images      // 이미지 메모만
    case combos      // 콤보만

    var displayName: String {
        switch self {
        case .templates: return NSLocalizedString("템플릿", comment: "Built-in category: templates only")
        case .textMemos: return NSLocalizedString("단축어+템플릿", comment: "Built-in category: text memos and templates")
        case .images:    return NSLocalizedString("이미지 단축어", comment: "Built-in category: image memos only")
        case .combos:    return NSLocalizedString("콤보", comment: "Built-in category: combos only")
        }
    }

    var icon: String {
        switch self {
        case .templates: return "wand.and.stars"
        case .textMemos: return "doc.text.fill"
        case .images:    return "photo.fill"
        case .combos:    return "square.stack.3d.up.fill"
        }
    }

    /// 탭 배경·인디케이터 색 (선택 칩은 공통 파랑, 이 색은 은은한 배경 틴트로만 사용).
    var tint: Color {
        switch self {
        case .templates: return .purple
        case .textMemos: return .indigo
        case .images:    return .green
        case .combos:    return .orange
        }
    }

    /// 이 카테고리에 메모가 속하는지 - 타입 기준 판정.
    func matches(_ memo: Memo) -> Bool {
        switch self {
        case .templates: return memo.isTemplate
        case .textMemos: return !memo.isStack
                              && memo.contentType != .image
                              && memo.contentType != .mixed
        case .images:    return memo.contentType == .image || memo.contentType == .mixed
        case .combos:    return memo.isStack
        }
    }
}

// MARK: - CategoryTab

enum CategoryTab: Hashable, Equatable {
    /// "전체" 탭 제거 후 기본 홈 탭 - 어떤 사용자 카테고리에도 속하지 않은(기본/미분류) 메모 모음.
    case basic
    /// 카테고리 기능이 꺼져 있을 때의 단일 "모든 메모" 페이지 전용. 탭 바에는 노출되지 않음.
    case all
    case favorites
    case builtIn(BuiltInCategory)
    case custom(String)

    var displayName: String {
        switch self {
        case .basic:     return NSLocalizedString("기본", comment: "Category tab: default/basic")
        case .all:       return NSLocalizedString("전체", comment: "Category tab: all")
        case .favorites: return NSLocalizedString("즐겨찾기", comment: "Category tab: favorites")
        case .builtIn(let b): return b.displayName
        case .custom(let name): return name
        }
    }

    /// UserDefaults 저장용 안정 키 (마지막 본 탭 복원).
    var storageKey: String {
        switch self {
        case .basic:            return "__basic__"
        case .all:              return "__all__"
        case .favorites:        return "__favorites__"
        case .builtIn(let b):   return "builtin:" + b.rawValue
        case .custom(let name): return "custom:" + name
        }
    }

    init?(storageKey: String) {
        switch storageKey {
        case "__basic__":     self = .basic
        case "__all__":       self = .all
        case "__favorites__": self = .favorites
        default:
            let builtInPrefix = "builtin:"
            if storageKey.hasPrefix(builtInPrefix),
               let b = BuiltInCategory(rawValue: String(storageKey.dropFirst(builtInPrefix.count))) {
                self = .builtIn(b)
                return
            }
            let prefix = "custom:"
            guard storageKey.hasPrefix(prefix) else { return nil }
            let name = String(storageKey.dropFirst(prefix.count))
            guard !name.isEmpty else { return nil }
            self = .custom(name)
        }
    }

    var icon: String {
        switch self {
        case .basic:     return "tray.full.fill"
        case .all:       return "square.grid.2x2"
        case .favorites: return "heart.fill"
        case .builtIn(let b): return b.icon
        case .custom:    return "folder.fill"
        }
    }

    /// 칩에 삭제(x) 버튼을 숨길지 - 사용자 정의(custom)만 칩에서 삭제 가능.
    /// 기본 제공 카테고리는 카테고리 관리 화면의 토글로 끈다.
    var isBuiltIn: Bool {
        if case .custom = self { return false }
        return true
    }
}

// MARK: - ClipKeyboardListViewModel

@MainActor
final class ClipKeyboardListViewModel: ObservableObject {

    // MARK: - Data State

    @Published var memos: [Memo] = []
    /// 디스크에서 한 번이라도 읽어 왔는가.
    ///
    /// ⚠️ `memos.isEmpty` 를 "단축어가 없는 사람"으로 읽으면 안 된다. 화면이 뜨고
    ///    읽어 오기 전까지는 누구나 비어 있어서, 그 창에 뜨는 안내는 **모든 사람에게**
    ///    한 번씩 번쩍였다 사라진다(그러면서 아래 목록을 밀어 내린다).
    @Published private(set) var hasLoadedMemos = false
    @Published var loadedData: [Memo] = []

    /// ⚠️ **첫 화면이 그려지기 전에** 단축어를 읽어 둔다.
    ///
    /// 예전에는 목록의 `.task` 에서 처음 읽었다. 그러면 첫 몇 프레임은 빈 페이지(스크롤뷰 없음)가
    /// 그려지고, 읽고 나서야 격자(스크롤뷰)로 갈렸다. 네비게이션 바가 **새로 생긴 스크롤뷰**를
    /// 잡으면서 큰 제목이 접혔다 펼쳐졌고, 그 사이 카드가 통째로 위로 튀었다가 아래로
    /// 미끄러져 내려왔다. 앱을 켤 때마다 보이던 "단축어가 위에서 내려오는" 움직임이 이것이다(실측).
    ///
    /// 필터를 먼저 읽는 순서는 화면의 onAppear(필터) → task(단축어) 와 같게 맞춘 것이다.
    /// `.task` 의 다시 읽기는 그대로 둔다 - 탭을 오갈 때 새로 읽는 길이다.
    init() {
        loadSavedFilter()
        loadMemos()
    }

    // MARK: - Search & Filter

    @Published var searchQueryString = ""
    @Published var selectedTypeFilter: ClipboardItemType?
    @Published var selectedCategoryFilter: String?
    @Published var showFavoritesFilter: Bool = false

    // MARK: - Reorder (수동 순서 바꾸기)

    /// 그리드 흔들기/드래그 재정렬 모드 여부.
    @Published var isReorderMode: Bool = false
    /// 재정렬 모드에서 드래그로 실시간 바뀌는 작업용 목록.
    /// 카테고리 기능이 켜져 있으면 현재 탭의 메모만, 아니면 전체 한 벌.
    @Published var reorderList: [Memo] = []

    private let manualOrderKey = DefaultsKey.memoManualOrderV1
    private let manualOrderActiveKey = DefaultsKey.memoManualOrderActiveV1

    /// 사용자가 수동 순서를 한 번이라도 지정했는지. true면 sortMemos가 수동 순서를 따른다
    /// (즐겨찾기 맨 위 고정 해제 - 사용자가 둔 순서 그대로).
    private var manualOrderActive: Bool {
        AppGroup.defaults?.bool(forKey: manualOrderActiveKey) ?? false
    }

    /// 저장된 수동 순서(메모 id 배열).
    private var manualOrder: [UUID] {
        let raw = AppGroup.defaults?.stringArray(forKey: manualOrderKey) ?? []
        return raw.compactMap { UUID(uuidString: $0) }
    }

    /// 재정렬 모드 진입 - 카테고리 기능이 켜져 있으면 현재 탭의 메모만,
    /// 아니면 전체 목록을 작업용 목록으로 복제. (메모가 많아도 지금 보는 카테고리만 재정렬)
    func enterReorderMode() {
        reorderList = scopedMemosForCurrentTab()
        withAnimation(.easeInOut(duration: 0.25)) { isReorderMode = true }
    }

    /// 지금 탭이 품은 메모. 카테고리 기능이 꺼져 있으면 탭 개념 자체가 없으므로 전체.
    ///
    /// 순서 바꾸기와 여러 개 고르기가 **같은 범위**를 쓴다. 두 모드가 다른 기준으로 모으면
    /// "여기서는 보이는데 저기서는 없는" 메모가 생긴다.
    func scopedMemosForCurrentTab() -> [Memo] {
        CategoryStore.shared.isFeatureEnabled
            ? reorderScopeMemos(for: selectedCategoryTab)
            : loadedData
    }

    /// 탭 하나가 품은 메모 - 탭 기준으로만 모은다(검색·타입 필터는 무시해 탭의 모든 메모를 포함).
    /// loadedData가 이미 표시 순서(sortMemos)라 부분집합도 화면과 같은 순서로 나온다.
    func reorderScopeMemos(for tab: CategoryTab) -> [Memo] {
        switch tab {
        case .all:
            return loadedData
        case .basic:
            // 기준은 `basicBucketMemos` 와 같아야 한다 - 화면에는 있는데 재정렬 목록에는 없으면
            // 그 메모는 순서를 바꿀 방법이 없다.
            let visible = visibleCustomCategories
            return loadedData.filter {
                CategoryBucketRule.belongsToBasicBucket(category: $0.category,
                                                        isFavorite: $0.isFavorite,
                                                        visibleCustomCategories: visible,
                                                        favoritesTabVisible: favoritesTabVisible)
            }
        case .favorites:
            return loadedData.filter { $0.isFavorite }
        case .builtIn(let b):
            return loadedData.filter { b.matches($0) }
        case .custom(let name):
            return loadedData.filter { $0.category == name }
        }
    }

    /// 재정렬 화면 안내용 현재 카테고리 탭 이름. 카테고리 기능이 꺼져 있으면 nil(전체 재정렬).
    var reorderScopeName: String? {
        CategoryStore.shared.isFeatureEnabled ? selectedCategoryTab.displayName : nil
    }

    /// 재정렬 모드 종료 - 현재 순서를 영구 저장하고 닫는다.
    func exitReorderMode() {
        commitReorder()
        withAnimation(.easeInOut(duration: 0.25)) { isReorderMode = false }
    }

    /// reorderList 순서를 디스크/UserDefaults에 영구 저장. 이후 sortMemos가 이 순서를 따른다.
    /// 현재 탭의 메모만 재정렬한 경우, 전체 순서에서 그 메모들이 차지하던 슬롯만 새 순서로
    /// 치환한다 - 다른 카테고리 메모의 상대 순서는 그대로 유지.
    func commitReorder() {
        guard !reorderList.isEmpty else { return }
        let subsetIds = Set(reorderList.map(\.id))
        var newOrder = reorderList.makeIterator()
        var merged: [Memo] = []
        merged.reserveCapacity(loadedData.count)
        for memo in loadedData {
            if subsetIds.contains(memo.id) {
                if let next = newOrder.next() { merged.append(next) }
            } else {
                merged.append(memo)
            }
        }
        // 방어: loadedData에 없던 재정렬 항목이 남으면 뒤에 덧붙인다(유실 방지).
        while let leftover = newOrder.next() { merged.append(leftover) }

        let ud = AppGroup.defaults
        ud?.set(merged.map { $0.id.uuidString }, forKey: manualOrderKey)
        ud?.set(true, forKey: manualOrderActiveKey)
        loadedData = merged
        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            print("✅ [commitReorder] 수동 순서 저장, 재정렬 \(reorderList.count)개 / 전체 \(loadedData.count)개")
        } catch {
            print("❌ [commitReorder] 저장 실패: \(error)")
        }
        applyFilters()
    }

    // MARK: - Bulk Selection (여러 개 고르기)

    /// 여러 개 고르기 모드 여부.
    ///
    /// 왜 생겼나: 사용자 피드백.
    ///
    ///   a capacity to select multiple snippets (really cool would be to be able to
    ///   switch to select mode by means of 2 finger tap or something like that),
    ///   so that we can send multiple to a folder/category or delete them.
    ///
    /// 하나씩 꾹 눌러 지우는 길밖에 없었다. 열 개를 지우려면 같은 동작을 열 번 한다.
    @Published var isSelectionMode: Bool = false

    /// 지금 고른 것들. 화면이 아니라 **id** 를 쥔다 - 옮기거나 지운 뒤 메모 값이 바뀌어도
    /// 고른 표시가 흐트러지지 않는다.
    @Published var selectedMemoIDs: Set<UUID> = []

    /// 고를 수 있는 범위(현재 탭). 지우는 동안 목록이 발밑에서 바뀌지 않도록 찍어 둔 판이다.
    @Published var selectionList: [Memo] = []

    /// 여러 개 고르기 시작. 두 손가락 탭이나 꾹 누르기 판에서 들어온다.
    /// - Parameter preselect: 꾹 눌러 들어왔을 때 그 카드를 미리 골라 둔다
    ///   (누른 것이 안 골라진 채로 열리면 왜 눌렀는지가 사라진다).
    func enterSelectionMode(preselect: UUID? = nil) {
        selectionList = scopedMemosForCurrentTab()
        selectedMemoIDs = []
        if let preselect, selectionList.contains(where: { $0.id == preselect }) {
            selectedMemoIDs.insert(preselect)
        }
        withAnimation(.easeInOut(duration: 0.25)) { isSelectionMode = true }
    }

    func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.25)) { isSelectionMode = false }
        selectedMemoIDs = []
        selectionList = []
    }

    func toggleSelection(_ id: UUID) {
        if selectedMemoIDs.contains(id) {
            selectedMemoIDs.remove(id)
        } else {
            selectedMemoIDs.insert(id)
        }
    }

    var selectedCount: Int { selectedMemoIDs.count }

    /// 범위에 있는 것을 **모두** 골랐는가. 빈 범위는 "모두 고름"이 아니다
    /// (빈 화면에서 전체 해제 버튼이 서 있으면 누를 것이 없다).
    var isAllSelectedInScope: Bool {
        !selectionList.isEmpty && selectedMemoIDs.count >= selectionList.count
    }

    func selectAllInScope() {
        selectedMemoIDs = Set(selectionList.map(\.id))
    }

    func deselectAll() {
        selectedMemoIDs = []
    }

    /// 고른 것들 - 화면에 보이던 순서 그대로.
    var selectedMemos: [Memo] {
        selectionList.filter { selectedMemoIDs.contains($0.id) }
    }

    /// 고른 것을 한꺼번에 지운다.
    ///
    /// ⚠️ 저장이 실패하면 **메모리를 되돌린다.** 한 개 지우기(`deleteMemo`)와 같은 약속인데,
    ///    여기서는 걸린 것이 여러 개라 되돌리지 않으면 화면에서만 사라진 메모가 무더기로 남는다.
    /// - Returns: 실제로 지운 개수. 실패하면 0.
    @discardableResult
    func deleteSelectedMemos() -> Int {
        let ids = selectedMemoIDs
        guard !ids.isEmpty else { return 0 }
        let backup = loadedData
        loadedData.removeAll { ids.contains($0.id) }
        let removed = backup.count - loadedData.count

        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            applyFilters()
            selectedMemoIDs = []
            selectionList.removeAll { ids.contains($0.id) }
            print("✅ [deleteSelectedMemos] \(removed)개 삭제")
            return removed
        } catch {
            print("❌ [ClipKeyboardListViewModel.deleteSelectedMemos] 삭제 저장 실패: \(error)")
            loadedData = backup
            applyFilters()
            showPlainToast(NSLocalizedString("삭제하지 못했습니다", comment: "Delete failed toast"))
            return 0
        }
    }

    /// 고른 것을 한꺼번에 다른 카테고리로 보낸다.
    ///
    /// 이미 그 카테고리에 있는 것은 세지 않는다 - "3개를 옮겼어요"라고 해 놓고 실제로는
    /// 하나도 안 움직였으면 그 말이 거짓이 된다.
    /// - Returns: 실제로 옮긴 개수. 실패하면 0.
    @discardableResult
    func moveSelectedMemos(toCategory category: String) -> Int {
        let ids = selectedMemoIDs
        guard !ids.isEmpty else { return 0 }
        let backup = loadedData
        var moved = 0
        for index in loadedData.indices where ids.contains(loadedData[index].id) {
            guard loadedData[index].category != category else { continue }
            loadedData[index].category = category
            moved += 1
        }
        guard moved > 0 else { return 0 }

        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            applyFilters()
            // 찍어 둔 판도 같이 갱신 - 옮긴 뒤에도 이 화면에 남아 이어서 고를 수 있다.
            for index in selectionList.indices where ids.contains(selectionList[index].id) {
                selectionList[index].category = category
            }
            print("✅ [moveSelectedMemos] \(moved)개를 '\(category)'로 이동")
            return moved
        } catch {
            print("❌ [ClipKeyboardListViewModel.moveSelectedMemos] 이동 저장 실패: \(error)")
            loadedData = backup
            applyFilters()
            showPlainToast(NSLocalizedString("변경 사항을 저장하지 못했습니다", comment: "Save failed toast"))
            return 0
        }
    }

    // MARK: - Category Tabs

    @Published var selectedCategoryTab: CategoryTab = .basic
    @Published var customCategories: [String] = []
    /// 탭 바에서 숨길 카테고리 이름 집합. 즐겨찾기는 "__favorites__" 키 사용.
    @Published var hiddenCategoryTabs: Set<String> = []
    /// 사용자가 카테고리 관리에서 켠 기본 제공 카테고리(타입별 모아보기). allCases 순서 유지.
    @Published var enabledBuiltInCategories: [BuiltInCategory] = []

    var allCategoryTabs: [CategoryTab] {
        var tabs: [CategoryTab] = [.basic]
        // 즐겨찾기는 기본 제공 카테고리 - 메모 유무와 무관하게 항상 노출 (사용자가 숨기지 않는 한)
        if !hiddenCategoryTabs.contains("__favorites__") {
            tabs.append(.favorites)
        }
        // 기본 제공 카테고리(켠 것만). 타입 기준이므로 사용자가 켜면 메모 유무와 무관하게 노출.
        for b in enabledBuiltInCategories {
            tabs.append(.builtIn(b))
        }
        // 사용자 카테고리는 카테고리 관리에서 토글을 켠(= 숨기지 않은) 것이면 노출.
        // 메모가 없어(빈 화면) 도 탭으로 보여 스와이프로 이동할 수 있게 한다.
        for cat in customCategories where !hiddenCategoryTabs.contains(cat) {
            tabs.append(.custom(cat))
        }
        return tabs
    }

    var selectedCategoryIndex: Int {
        allCategoryTabs.firstIndex(of: selectedCategoryTab) ?? 0
    }

    /// 갈래를 고른다.
    ///
    /// - Parameter animated: 화면을 애니메이션으로 옮길지. **손으로 넘긴 경우에는 끈다.**
    ///
    /// ⚠️ 페이저가 스스로 넘긴 것을 여기서 또 애니메이션하면 안 된다.
    ///    손가락이 이미 페이지를 끌어다 놓았는데, 그 뒤 `withAnimation` 으로 상태를 바꾸면
    ///    SwiftUI 가 **한 번 더** 전이를 건다. 그 전이가 카드들을 배경 쪽으로 흐렸다가
    ///    돌려놓아서, 카테고리를 바꿀 때마다 화면이 번쩍이는 것으로 보였다.
    ///
    ///    녹화(60fps)로 잰 값: 페이지가 멎은 뒤 프레임 105~117, 즉 **13프레임 = 0.217초**
    ///    동안 카드가 옅어졌다 돌아왔다. 아래 `0.22` 와 같은 길이다.
    ///    그 사이 배경색은 전혀 변하지 않았다(카드만 흐려졌다는 뜻이다).
    ///
    ///    탭 바에서 눌러 건너뛸 때는 옮기는 연출이 필요하므로 그때만 켠다.
    func selectCategoryTab(_ tab: CategoryTab, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.22)) { selectedCategoryTab = tab }
        } else {
            selectedCategoryTab = tab
        }
        // 마지막 본 탭 기억 - 다음 실행 시 이 화면에서 시작.
        UserDefaults.standard.set(tab.storageKey, forKey: Self.selectedCategoryTabKey)
    }

    /// 방금 저장한 단축어가 **보이는 자리로** 옮겨 간다.
    ///
    /// 왜 필요한가: 사용자 피드백.
    ///
    /// > 한 개 저장하면 저장한 위치의 카테고리, 저장된 거 바로 보이는 위치로 도달하게
    /// > 해주세요. 순간 길 헤매요.
    ///
    /// 기본 탭에서 '업무'를 골라 저장하면, 저장은 됐는데 화면은 기본에 남아 있어서
    /// **만든 것이 어디로 갔는지 안 보인다.** 사라진 것처럼 보이는 것이 제일 나쁘다.
    ///
    /// ⚠️ 지금 탭에서 이미 보이면 **아무것도 하지 않는다.** 카테고리 탭에서 + 로
    ///    만든 흔한 경우가 여기다. 잘 보이는데 화면을 또 옮기면 그게 길을 헤매게 한다.
    func revealSavedMemo(id: UUID) {
        guard let saved = memos.first(where: { $0.id == id }) else { return }
        if memos(for: selectedCategoryTab).contains(where: { $0.id == id }) { return }

        func contains(_ tab: CategoryTab) -> Bool {
            memos(for: tab).contains { $0.id == id }
        }

        // ⚠️ **고른 카테고리를 먼저 본다.** `allCategoryTabs` 순서대로 찾으면 즐겨찾기·
        //    템플릿 탭이 앞에 있어서, '업무'를 골라 저장한 즐겨찾기가 즐겨찾기 탭으로
        //    끌려간다. 보이기는 하지만 **사람이 고른 자리가 아니다.**
        let chosen = CategoryTab.custom(saved.category)
        if allCategoryTabs.contains(chosen), contains(chosen) {
            selectCategoryTab(chosen)
            return
        }
        guard let destination = allCategoryTabs.first(where: contains) else { return }
        selectCategoryTab(destination)
    }

    private static let selectedCategoryTabKey = "selectedCategoryTab_v1"
    private var didRestoreCategoryTab = false

    /// 앱 시작 시 1회 - 마지막에 보던 카테고리 탭을 복원한다.
    /// 카테고리 기능이 켜져 있고, 저장된 탭이 지금도 노출 가능한 경우에만 적용
    /// (삭제·숨김된 카테고리거나 기능이 꺼져 있으면 전체에서 시작).
    func restoreSelectedCategoryTabIfNeeded() {
        guard !didRestoreCategoryTab else { return }
        didRestoreCategoryTab = true

        guard CategoryStore.shared.isFeatureEnabled,
              let raw = UserDefaults.standard.string(forKey: Self.selectedCategoryTabKey),
              let saved = CategoryTab(storageKey: raw),
              saved != .basic else { return }

        loadCustomCategories()
        if allCategoryTabs.contains(saved) {
            selectedCategoryTab = saved
            print("↩️ [restoreSelectedCategoryTab] 마지막 탭 복원: \(saved.storageKey)")
        }
    }

    func navigateToNextCategory() {
        let tabs = allCategoryTabs
        selectCategoryTab(tabs[(selectedCategoryIndex + 1) % tabs.count])
    }

    func navigateToPreviousCategory() {
        let tabs = allCategoryTabs
        let count = tabs.count
        selectCategoryTab(tabs[(selectedCategoryIndex - 1 + count) % count])
    }

    func memosForCurrentTab() -> [Memo] {
        memos(for: selectedCategoryTab)
    }

    /// 지금 탭 바에 **실제로 서 있는** 사용자 카테고리.
    ///
    /// ⚠️ `customCategories` 와 다르다. 저쪽은 만들어 둔 것 전부고, 이쪽은 갈 수 있는 것만이다.
    ///    기본 버킷의 기준은 반드시 이쪽이어야 한다(`CategoryBucketRule` 참고).
    /// 즐겨찾기 탭이 지금 서 있는가 - 숨겼으면 즐겨찾기 단축어도 기본 칸이 받아야 한다.
    var favoritesTabVisible: Bool {
        !hiddenCategoryTabs.contains(CategoryBucketRule.favoritesTabKey)
    }

    var visibleCustomCategories: Set<String> {
        CategoryBucketRule.visibleCategories(all: customCategories, hidden: hiddenCategoryTabs)
    }

    /// "기본" 탭에 모이는 메모 - **갈 수 있는 어떤 카테고리 탭에도 속하지 않은** 모든 메모.
    /// (category == "기본", 빈값, 삭제된 카테고리의 고아 메모, 그리고 탭을 숨긴 카테고리의
    /// 메모까지 catch-all로 포함해 "전체" 탭이 사라져도 어떤 메모도 화면에서 누락되지 않게 한다.)
    /// 검색·타입 필터가 반영된 `memos` 기준이라 다른 탭과 동작이 일관된다.
    ///
    /// ⚠️ 판정은 `CategoryBucketRule` 한 곳에서만 한다 - 키보드도 같은 함수를 부른다.
    ///    이 규칙이 두 벌로 갈라져 있던 동안 양쪽 다 같은 구멍을 갖고 있었다.
    var basicBucketMemos: [Memo] {
        let visible = visibleCustomCategories
        return memos.filter {
            CategoryBucketRule.belongsToBasicBucket(category: $0.category,
                                                    isFavorite: $0.isFavorite,
                                                    visibleCustomCategories: visible,
                                                    favoritesTabVisible: favoritesTabVisible)
        }
    }

    func memos(for tab: CategoryTab) -> [Memo] {
        switch tab {
        case .basic:
            return basicBucketMemos
        case .all:
            return memos
        case .favorites:
            // 타입 필터와 무관하게 전체 데이터에서 즐겨찾기 추출.
            // 타입 필터가 켜져 있어도 즐겨찾기한 메모는 항상 표시.
            let base = searchQueryString.isEmpty ? loadedData : loadedData.filter {
                $0.title.localizedStandardContains(searchQueryString)
            }
            return base.filter { $0.isFavorite }
        case .builtIn(let b):
            // 기본 제공 카테고리 - 메모 타입 기준으로 필터. 검색은 그대로 적용.
            let base = searchQueryString.isEmpty ? loadedData : loadedData.filter {
                $0.title.localizedStandardContains(searchQueryString)
            }
            return base.filter { b.matches($0) }
        case .custom(let name):
            // 마찬가지로 타입 필터 무관하게 카테고리 기반으로만 필터.
            let base = searchQueryString.isEmpty ? loadedData : loadedData.filter {
                $0.title.localizedStandardContains(searchQueryString)
            }
            return base.filter { $0.category == name }
        }
    }

    func addCustomCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customCategories.contains(trimmed) else { return }
        customCategories.append(trimmed)
        saveCustomCategories()
    }

    func deleteCustomCategory(_ name: String) {
        customCategories.removeAll { $0 == name }
        if case .custom(let cur) = selectedCategoryTab, cur == name {
            selectedCategoryTab = .basic
        }
        saveCustomCategories()
    }

    // MARK: - Smart Category Suggestion

    /// 제안을 띄울 최소 메모 수.
    static let categorySuggestionThreshold = 3

    /// 메모를 보고 만들 만한 카테고리를 제안한다.
    /// 자동 분류로 `category` 값은 이미 붙어 있으나 아직 사용자 카테고리 목록엔 없는 그룹 중
    /// 가장 큰 것을 고른다(임계치 이상). 메모는 이미 그 값을 가지므로 카테고리를 추가하기만
    /// 하면 곧바로 해당 탭에 모인다. (저장값은 rawValue, 표시는 호출부에서 현지화)
    var suggestedCategory: (name: String, count: Int)? {
        let excluded: Set<String> = ["기본", "텍스트", "이미지", ""]
        var counts: [String: Int] = [:]
        for memo in loadedData {
            let c = memo.category
            guard !excluded.contains(c), !customCategories.contains(c) else { continue }
            counts[c, default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value }),
              best.value >= Self.categorySuggestionThreshold else { return nil }
        return (best.key, best.value)
    }

    /// 제안 수락 - 카테고리를 추가하고 해당 탭으로 이동.
    /// 메모는 이미 분류돼 있어 추가 즉시 그 탭에 모인다.
    func acceptSuggestedCategory(_ name: String) {
        addCustomCategory(name)
        selectCategoryTab(.custom(name))
    }

    func moveMemo(_ memo: Memo, toCategory category: String) {
        guard let idx = loadedData.firstIndex(where: { $0.id == memo.id }) else { return }
        loadedData[idx].category = category
        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            applyFilters()
        } catch {
            print("❌ [moveMemo] 저장 실패: \(error)")
        }
    }

    func loadCustomCategories() {
        let ud = AppGroup.defaults
        // 카테고리는 기본 제공하지 않음 - 사용자가 직접 만든 목록만 로드.
        customCategories = ud?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1) ?? []
        let hidden = ud?.stringArray(forKey: DefaultsKey.hiddenCategoryTabsV1) ?? []
        hiddenCategoryTabs = Set(hidden)
        // 기본 제공 카테고리 - allCases 순서를 유지해 탭 순서가 항상 일정하게.
        let enabledRaw = Set(ud?.stringArray(forKey: DefaultsKey.enabledBuiltInCategoriesV1) ?? [])
        enabledBuiltInCategories = BuiltInCategory.allCases.filter { enabledRaw.contains($0.rawValue) }
        // 관리 화면에서 끈 카테고리가 현재 선택 탭이면 전체로 되돌린다(빈 탭에 머무는 것 방지).
        if !allCategoryTabs.contains(selectedCategoryTab) {
            selectedCategoryTab = .basic
        }
    }

    func saveCustomCategories() {
        AppGroup.defaults?
            .set(customCategories, forKey: DefaultsKey.userDefinedCategoriesV1)
    }

    func setCategoryVisible(_ key: String, visible: Bool) {
        if visible {
            hiddenCategoryTabs.remove(key)
        } else {
            hiddenCategoryTabs.insert(key)
            if key == "__favorites__", case .favorites = selectedCategoryTab {
                selectedCategoryTab = .basic
            } else if case .custom(let cur) = selectedCategoryTab, cur == key {
                selectedCategoryTab = .basic
            }
        }
        AppGroup.defaults?
            .set(Array(hiddenCategoryTabs), forKey: DefaultsKey.hiddenCategoryTabsV1)
    }

    func isCategoryVisible(_ key: String) -> Bool {
        !hiddenCategoryTabs.contains(key)
    }

    func reorderCustomCategories(from: IndexSet, to: Int) {
        customCategories.move(fromOffsets: from, toOffset: to)
        saveCustomCategories()
    }

    // MARK: - Clipboard Capture State

    @Published var keyword: String = ""
    @Published var value: String = ""
    @Published var clipboardDetectedType: ClipboardItemType = .text
    @Published var clipboardConfidence: Double = 0.0

    /// 상단 인라인 캡처 카드 노출 여부. onAppear에서 새 클립보드 감지 시 true.
    @Published var hasFreshClipboard: Bool = false

    /// 마지막으로 사용자가 "숨기기"한 클립보드 값. 같은 값이 다시 나타나면 재노출하지 않는다.
    private let lastDismissedClipboardKey = "lastDismissedClipboard"

    // MARK: - Sheet Presentation State

    @Published var showTemplateInputSheet: Bool = false
    @Published var showPlaceholderManagementSheet: Bool = false
    @Published var selectedTemplateIdForSheet: UUID?
    @Published var selectedStackIdForSheet: UUID?
    @Published var showAuthAlert: Bool = false

    // MARK: - Template Input

    @Published var templatePlaceholders: [String] = []
    @Published var templateInputs: [String: String] = [:]
    @Published var currentTemplateMemo: Memo?
    /// v4.0.8: attachedTemplate 흐름에서 본 메모 (계좌번호 등). nil이면 일반 템플릿 흐름.
    /// 본 메모 + 입력값 치환된 템플릿을 줄바꿈으로 결합해 출력.
    @Published var attachedTemplateBaseMemo: Memo?

    // MARK: - Toast

    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    // MARK: - UI

    @Published var showFavoriteNudge: Bool = false

    // MARK: - Activation Card (첫 붙여넣기 유도)

    @Published var showActivationCard: Bool = false
    @Published var showTemplateHint: Bool = false
    private var lastKnownPasteCount: Int = 0
    private let practicePromptShownKey = "keyboard_practice_prompt_shown_v1"
    private let activationCardSnoozedKey = "activation_card_snoozed_until"
    private let templateHintShownKey = "template_hint_shown_v1"

    // MARK: - Private

    private let selectedFilterKey = "selectedTypeFilter"

    // MARK: - onAppear

    func onAppear() {
        print("🎬 [ClipKeyboardListViewModel] onAppear 시작")
        loadSavedFilter()
        loadCustomCategories()
        migrateExistingMemosClassification()

        checkFreshClipboard()
        checkActivationCard()

        FavoriteNudgeManager.shared.resetIfNeeded()
        if FavoriteNudgeManager.shared.shouldShowNudge {
            print("💝 [ClipKeyboardListViewModel] 즐겨찾기 넛지 표시")
            showFavoriteNudge = true
            FavoriteNudgeManager.shared.recordNudgeShown()
        }

        print("✅ [ClipKeyboardListViewModel] onAppear 완료")
    }

    // MARK: - Scene Resume (앱 포그라운드 복귀 시 호출)

    func onSceneResume() {
        reloadIfChangedOutsideApp()
        checkFreshClipboard()
        let newCount = AppGroup.defaults?.integer(forKey: DefaultsKey.keyboardPasteCount) ?? 0
        if lastKnownPasteCount == 0 && newCount > 0 {
            showActivationCard = false
            showCelebrationToast()
            print("🎉 [ViewModel] 첫 붙여넣기 감지, 축하 토스트 표시")
        }
        lastKnownPasteCount = newCount
        checkActivationCard()
    }

    /// 앱 **밖에서**(공유 익스텐션) `memos.data` 가 바뀌었으면 다시 읽는다.
    ///
    /// ⚠️ 이걸 안 하면 밖에서 넣은 단축어가 **조용히 사라진다.** `memos.data` 는 앱이
    ///    통째로 덮어쓰는 파일이라, 낡은 목록을 들고 있다가 아무 편집이나 저장하는 순간
    ///    밖에서 덧붙인 것이 지워진다. 사용자에겐 "공유했는데 없어졌다"로만 보인다.
    ///
    /// 매번 읽지 않고 표식이 바뀐 때만 읽는다 - 앞으로 올 때마다 파일을 훑을 이유는 없다.
    private func reloadIfChangedOutsideApp() {
        let changedAt = AppGroup.defaults?
            .double(forKey: DefaultsKey.memosExternalChangeAt) ?? 0
        guard changedAt > 0 else { return }

        let seenAt = UserDefaults.standard.double(forKey: DefaultsKey.memosExternalChangeSeenAt)
        guard changedAt > seenAt else { return }

        UserDefaults.standard.set(changedAt, forKey: DefaultsKey.memosExternalChangeSeenAt)
        print("🔄 [ViewModel] 앱 밖에서 단축어가 바뀌었다. 다시 읽는다")
        loadMemos()
        loadCustomCategories()
    }

    private func showCelebrationToast() {
        toastMessage = NSLocalizedString("🎉 첫 붙여넣기 완료! 이제 진짜 ClipKeyboard 사용자예요", comment: "First paste celebration toast")
        showToast = true
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: toastMessage)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Activation Card

    private func checkActivationCard() {
        let pasted = AppGroup.defaults?.integer(forKey: DefaultsKey.keyboardPasteCount) ?? 0
        lastKnownPasteCount = pasted
        guard pasted == 0 else {
            showActivationCard = false
            return
        }
        guard UserDefaults.standard.bool(forKey: practicePromptShownKey) else { return }
        if let snoozedUntil = UserDefaults.standard.object(forKey: activationCardSnoozedKey) as? Date,
           snoozedUntil > Date() {
            showActivationCard = false
            return
        }
        showActivationCard = true
    }

    func snoozeActivationCard() {
        UserDefaults.standard.set(Date().addingTimeInterval(24 * 60 * 60), forKey: activationCardSnoozedKey)
        showActivationCard = false
    }

    // MARK: - Template Hint

    func checkTemplateHintIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: templateHintShownKey) else { return }
        guard loadedData.count >= 3 else { return }
        showTemplateHint = true
    }

    func dismissTemplateHint() {
        UserDefaults.standard.set(true, forKey: templateHintShownKey)
        showTemplateHint = false
    }

    // MARK: - Section Helpers (ADHD 친화 섹션 분리)

    /// 고정(즐겨찾기)된 메모
    var pinnedMemos: [Memo] {
        memos.filter { $0.isFavorite }
    }

    /// 최근 사용한 메모 (비고정, lastUsedAt 있는 것 중 상위 3개)
    var recentlyUsedMemos: [Memo] {
        let pinnedIds = Set(pinnedMemos.map { $0.id })
        return memos
            .filter { !$0.isFavorite && !pinnedIds.contains($0.id) && $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(3)
            .map { $0 }
    }

    /// 고정·최근 사용 제외한 나머지 전체 메모
    var remainingMemos: [Memo] {
        let excludeIds = Set((pinnedMemos + recentlyUsedMemos).map { $0.id })
        return memos.filter { !excludeIds.contains($0.id) }
    }

    // MARK: - Data Loading

    func loadMemos() {
        do {
            print("📂 [loadMemos] 메모 로드 시작...")
            diagnoseMemoStorage()
            let loadedMemos = try MemoStore.shared.load(type: .memo)
            print("📊 [loadMemos] 로드된 메모 개수: \(loadedMemos.count)")
            let noImageCount = loadedMemos.filter { ($0.imageFileNames.first ?? $0.imageFileName ?? "").isEmpty }.count
            print("🖼️ [loadMemos] 이미지 있는 메모: \(loadedMemos.count - noImageCount)개 / 전체: \(loadedMemos.count)개")
            // "전체" 탭 제거에 따른 정리 - category가 비어 있는(미분류) 메모를 "기본"으로 정규화.
            // 멱등(idempotent)하므로 매 로드마다 수행해도 안전하고, 변경이 있을 때만 저장한다.
            let normalizedMemos = normalizeEmptyCategories(loadedMemos)
            memos = sortMemos(normalizedMemos)
            loadedData = memos
            hasLoadedMemos = true
            print("✅ [loadMemos] 메모 로드 완료")
            applyFilters()
            checkTemplateHintIfNeeded()
            // 데이터·카테고리가 로드된 뒤 1회 - 마지막 본 탭으로 복원.
            restoreSelectedCategoryTabIfNeeded()
        } catch {
            print("❌ [loadMemos] 메모 로드 실패: \(error.localizedDescription)")
        }
    }

    /// category가 비어 있거나(공백 포함) 없는 메모를 "기본"으로 채운다.
    /// 변경이 발생한 경우에만 디스크에 저장하고, 정규화된 목록을 반환한다.
    private func normalizeEmptyCategories(_ source: [Memo]) -> [Memo] {
        var result = source
        var changedCount = 0
        for i in result.indices
        where result[i].category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result[i].category = "기본"
            changedCount += 1
        }
        if changedCount > 0 {
            do {
                try MemoStore.shared.save(memos: result, type: .memo)
                print("🔄 [normalizeEmptyCategories] 빈 카테고리 메모 \(changedCount)개를 '기본'으로 정규화")
            } catch {
                print("❌ [normalizeEmptyCategories] 저장 실패: \(error.localizedDescription)")
            }
        }
        return result
    }


    // MARK: - Storage Diagnosis

    /// 저장소 상태를 콘솔에 찍어 보는 **개발용** 점검.
    ///
    /// ⚠️ 릴리즈에서는 통째로 사라진다. 예전에는 조건 없이 살아 있었고
    ///    `loadMemos()` 첫 줄이라 **메모를 저장할 때마다** 메인 스레드에서
    ///    Images 폴더를 전부 열거하고 `memos.data` 를 통째로 읽어 문자열로 바꾼 뒤
    ///    전수 스캔을 두 번 했다. 바로 다음 줄의 `MemoStore.load` 가 같은 파일을
    ///    또 읽으므로 한 번의 로드에 파일을 세 번 읽던 셈이다.
    ///    (측정: Instruments, iPhone15,3 / 5.0.6 / Release)
    private func diagnoseMemoStorage() {
        #if DEBUG
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            print("🔴 [diagnosis] App Group 컨테이너를 찾을 수 없음")
            return
        }

        // 1. Images 폴더에 실제 파일이 있는지 확인
        let imagesDir = containerURL.appendingPathComponent("Images")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) {
            print("🖼️ [diagnosis] Images 폴더 파일 수: \(files.count)")
            for f in files.prefix(10) { print("  └ \(f)") }
        } else {
            print("🖼️ [diagnosis] Images 폴더 없음 또는 비어있음")
        }

        // 2. memos.data JSON에 imageFileName 키가 존재하는지 raw 검색
        let memoFile = containerURL.appendingPathComponent(StorageFile.memos)
        if let data = try? Data(contentsOf: memoFile),
           let json = String(data: data, encoding: .utf8) {
            let hasImageField = json.contains("imageFileName")
            let hasImageNamesField = json.contains("imageFileNames")
            print("🖼️ [diagnosis] memos.data 크기: \(data.count) bytes")
            print("🖼️ [diagnosis] JSON에 'imageFileName' 포함: \(hasImageField)")
            print("🖼️ [diagnosis] JSON에 'imageFileNames' 포함: \(hasImageNamesField)")
        } else {
            print("🔴 [diagnosis] memos.data 파일을 읽을 수 없음")
        }
        #endif
    }

    // MARK: - Filter

    func loadSavedFilter() {
        if let savedFilterRawValue = UserDefaults.standard.string(forKey: selectedFilterKey),
           let savedFilter = ClipboardItemType(rawValue: savedFilterRawValue) {
            selectedTypeFilter = savedFilter
            print("📌 [loadSavedFilter] 저장된 필터 로드: \(savedFilter.rawValue)")
        } else {
            selectedTypeFilter = nil
            print("📌 [loadSavedFilter] 저장된 필터 없음 - 전체 표시")
        }
    }

    func saveSelectedFilter() {
        if let filter = selectedTypeFilter {
            UserDefaults.standard.set(filter.rawValue, forKey: selectedFilterKey)
            print("💾 [saveSelectedFilter] 필터 저장: \(filter.rawValue)")
        } else {
            UserDefaults.standard.removeObject(forKey: selectedFilterKey)
            print("💾 [saveSelectedFilter] 필터 초기화 (전체)")
        }
    }

    func applyFilters() {
        print("🔍 [applyFilters] 시작 - loadedData: \(loadedData.count)개")

        var filtered = loadedData

        if !searchQueryString.isEmpty {
            filtered = filtered.filter { $0.title.localizedStandardContains(searchQueryString) }
            print("🔍 [applyFilters] 검색 후: \(filtered.count)개")
        }

        if showFavoritesFilter {
            filtered = filtered.filter { $0.isFavorite }
            print("🔍 [applyFilters] 즐겨찾기 필터 적용 - \(filtered.count)개")
        } else if let typeFilter = selectedTypeFilter {
            let beforeCount = filtered.count
            // resolvedType 기반 필터링: 이미지/자동분류된 타입까지 정확히 반영
            filtered = filtered.filter {
                ClipboardClassificationService.shared.resolvedType(for: $0) == typeFilter
            }
            print("🔍 [applyFilters] 타입 필터 '\(typeFilter.rawValue)' 적용 - \(beforeCount)개 → \(filtered.count)개")

            if filtered.isEmpty && !loadedData.isEmpty && searchQueryString.isEmpty {
                print("⚠️ [applyFilters] 필터 결과 0개 - 필터 자동 해제")
                selectedTypeFilter = nil
                filtered = loadedData
                saveSelectedFilter()
            }
        }

        memos = filtered
        print("✅ [applyFilters] 완료 - memos: \(memos.count)개")
    }

    // MARK: - Memo Actions

    func toggleFavorite(memoId: UUID) {
        guard let index = loadedData.firstIndex(where: { $0.id == memoId }) else { return }

        withAnimation(.easeInOut) {
            loadedData[index].isFavorite.toggle()

            if loadedData[index].isFavorite {
                showFavoriteNudge = false
            }

            loadedData = sortMemos(loadedData)

            do {
                try MemoStore.shared.save(memos: loadedData, type: .memo)
                applyFilters()
            } catch {
                // 저장 실패로 앱을 크래시시키지 않는다 - 디스크 상태로 되돌려 UI 일관성을 유지하고 사용자에게 알린다.
                print("❌ [ClipKeyboardListViewModel.toggleFavorite] 즐겨찾기 저장 실패: \(error)")
                loadMemos()
                showPlainToast(NSLocalizedString("변경 사항을 저장하지 못했습니다", comment: "Save failed toast"))
            }
        }
    }

    func deleteMemo(at offsets: IndexSet) {
        let deletedIds = offsets.map { memos[$0].id }
        let backup = loadedData
        loadedData.removeAll { memo in deletedIds.contains(memo.id) }

        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            applyFilters()
        } catch {
            // 삭제 저장 실패 시 크래시 대신 메모리 상태를 롤백하고 사용자에게 알린다.
            print("❌ [ClipKeyboardListViewModel.deleteMemo] 메모 삭제 저장 실패: \(error)")
            loadedData = backup
            applyFilters()
            showPlainToast(NSLocalizedString("삭제하지 못했습니다", comment: "Delete failed toast"))
        }
    }

    /// 롱프레스에서 보안 설정/해제. ON=평문을 암호화. OFF=평문이 드러나므로 생체 인증 후 복호화.
    func toggleSecure(memoId: UUID) {
        guard let memo = loadedData.first(where: { $0.id == memoId }) else { return }
        if memo.isSecure {
            // 보안 해제 - 평문 노출이므로 인증을 먼저 요구.
            authenticateForSecureChange { [weak self] in
                self?.applySecure(memoId: memoId, makeSecure: false)
            }
        } else {
            applySecure(memoId: memoId, makeSecure: true)
        }
    }

    private func authenticateForSecureChange(onSuccess: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            showAuthAlert = true
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: NSLocalizedString("보안을 해제하려면 인증이 필요합니다", comment: "Biometric auth reason for unlocking a secure memo")
        ) { success, _ in
            DispatchQueue.main.async {
                if success { onSuccess() } else { self.showAuthAlert = true }
            }
        }
    }

    /// 보안 상태를 적용해 저장. makeSecure=true면 평문을 암호화, false면 암호문을 복호화.
    /// (암복호화는 idempotent - 어떤 상태의 value가 와도 안전.)
    private func applySecure(memoId: UUID, makeSecure: Bool) {
        guard let idx = loadedData.firstIndex(where: { $0.id == memoId }) else { return }
        let backup = loadedData
        var memo = loadedData[idx]
        if makeSecure {
            let plain = SecureMemoCrypto.isEncrypted(memo.value)
                ? (SecureMemoCrypto.decrypt(memo.value) ?? memo.value)
                : memo.value
            guard let enc = SecureMemoCrypto.encrypt(plain) else {
                showPlainToast(NSLocalizedString("보안 설정에 실패했습니다", comment: "Make-secure failed toast"))
                return
            }
            // 콤보면 단계 값도 함께 암호화 - 하나라도 실패하면 전체 롤백(부분 암호화 방지).
            let encSteps = SecureMemoCrypto.encryptSteps(SecureMemoCrypto.decryptSteps(memo.stackValues))
            guard encSteps.allSatisfy({ SecureMemoCrypto.isEncrypted($0) }) || memo.stackValues.isEmpty else {
                showPlainToast(NSLocalizedString("보안 설정에 실패했습니다", comment: "Make-secure failed toast"))
                return
            }
            memo.value = enc
            memo.setStackValues(encSteps)
            memo.isSecure = true
        } else {
            if SecureMemoCrypto.isEncrypted(memo.value) {
                memo.value = SecureMemoCrypto.decrypt(memo.value) ?? memo.value
            }
            memo.setStackValues(SecureMemoCrypto.decryptSteps(memo.stackValues))
            memo.isSecure = false
        }
        loadedData[idx] = memo
        do {
            try MemoStore.shared.save(memos: loadedData, type: .memo)
            loadedData = sortMemos(loadedData)
            applyFilters()
            // 봉함/개봉 - 잠금이 체크박스가 아니라 만지는 동작으로 느껴지도록.
            if makeSecure { Delight.sealed() } else { Delight.unsealed() }
            showPlainToast(makeSecure
                ? NSLocalizedString("봉인했어요", comment: "Memo locked toast")
                : NSLocalizedString("봉인을 열었어요", comment: "Memo unlocked toast"))
        } catch {
            print("❌ [applySecure] 저장 실패: \(error)")
            loadedData = backup
            applyFilters()
            showPlainToast(NSLocalizedString("변경 사항을 저장하지 못했습니다", comment: "Save failed toast"))
        }
    }

    func copyMemo(memo: Memo) {
        print("📝 [copyMemo] 메모 선택됨: \(memo.title), 템플릿: \(memo.isTemplate), 보안: \(memo.isSecure)")

        if memo.isSecure {
            print("🔐 [copyMemo] 보안 메모 - Face ID 인증 요청")
            authenticateWithBiometrics(memo: memo)
            return
        }

        processMemoAfterAuth(memo)
    }

    /// 보안 메모면 복호화한 값을 반환. 평문/비보안은 그대로. 복호화 불가(키 미동기화)면 nil.
    private func usableValue(of memo: Memo) -> String? {
        guard SecureMemoCrypto.isEncrypted(memo.value) else { return memo.value }
        return SecureMemoCrypto.decrypt(memo.value)
    }

    func confirmTemplateInput() {
        guard let memo = currentTemplateMemo else { return }
        guard let memoValue = usableValue(of: memo) else { showAuthAlert = true; return }
        let processedTemplate = processTemplateWithInputs(in: memoValue, inputs: templateInputs)

        if let base = attachedTemplateBaseMemo {
            guard let baseValue = usableValue(of: base) else { showAuthAlert = true; return }
            // v4.0.8 attachedTemplate 흐름: 본 메모 + \n + 치환된 템플릿
            let combined = TemplateVariableProcessor.compose(
                memoValue: baseValue,
                templateBody: processedTemplate,
                templateInputs: [:] // 이미 substituted
            )
            finalizeCopy(memo: base, processedValue: combined)
            attachedTemplateBaseMemo = nil
        } else {
            finalizeCopy(memo: memo, processedValue: processedTemplate)
        }
        showTemplateInputSheet = false
    }

    /// v4.0.8: attachedTemplate 입력 스킵 - 본 메모 단독 출력 (사용자가 시트에서 "템플릿 없이").
    func skipAttachedTemplate() {
        guard let base = attachedTemplateBaseMemo else { return }
        guard let baseValue = usableValue(of: base) else { showAuthAlert = true; return }
        finalizeCopy(memo: base, processedValue: baseValue)
        attachedTemplateBaseMemo = nil
        currentTemplateMemo = nil
        templateInputs = [:]
        showTemplateInputSheet = false
    }

    func finalizeCopy(memo: Memo, processedValue: String, showToastAfter: Bool = true) {
        #if os(iOS)
        let imageFileName: String? = (memo.contentType == .image || memo.contentType == .mixed)
            ? (memo.imageFileNames.first ?? memo.imageFileName)
            : nil
        if let imageFileName {
            if let data = MemoStore.shared.imageData(fileName: imageFileName) {
                // ⚠️ 사진과 글을 **한 항목에 함께** 얹는다. 예전에는 `.image` 를 넣고 나서
                //    `.string` 을 넣었는데, 클립보드는 새로 얹을 때마다 앞의 것을 버린다.
                //    그래서 글+사진 단축어는 **글을 넣는 순간 사진이 사라졌다.**
                //    한 항목에 두 표현을 담으면 받는 앱이 자기가 받을 수 있는 쪽을 가져간다.
                var item: [String: Any] = [
                    MemoStore.shared.imagePasteboardType(fileName: imageFileName): data
                ]
                if memo.contentType == .mixed, !processedValue.isEmpty {
                    item[UTType.utf8PlainText.identifier] = processedValue
                }
                UIPasteboard.general.items = [item]
                print("✅ [finalizeCopy] 이미지를 클립보드에 복사: \(imageFileName) (\(data.count) bytes)")
                // 이미지 메모 탭 시 복사됨 안내 토스트.
                showPlainToast(NSLocalizedString("이미지가 복사되었습니다", comment: "Image copied toast"))
            } else {
                // 파일이 사라졌거나 아직 안 내려왔다. 예전에는 여기서 **아무 말도 없이**
                // 아무 일도 안 했다 - 눌렀는데 조용하면 앱이 고장 난 것으로 읽힌다.
                if !processedValue.isEmpty { UIPasteboard.general.string = processedValue }
                print("⚠️ [finalizeCopy] 이미지 파일을 읽지 못함: \(imageFileName)")
                showPlainToast(NSLocalizedString("사진을 찾지 못했어요", comment: "Toast: image file missing"))
            }
        } else {
            UIPasteboard.general.string = processedValue
        }
        #else
        UIPasteboard.general.string = processedValue
        #endif

        do {
            try MemoStore.shared.incrementClipCount(for: memo.id)

            if memo.contentType != .image {
                try MemoStore.shared.addToSmartClipboardHistory(content: processedValue)
            }

            let allMemos = try MemoStore.shared.load(type: .memo)
            loadedData = sortMemos(allMemos)
            applyFilters()
        } catch {
            print("❌ [finalizeCopy] 오류: \(error)")
        }

        // 첫 복사 시 KeyboardTip 표시 조건 충족
        KeyboardTip.hasCopiedMemo = true

        // 청각 장애 접근성: 시각적 토스트를 놓쳐도 복사 완료를 인지할 수 있도록 success 햅틱
        #if os(iOS)
        HapticManager.shared.success()
        #endif

        // 콤보처럼 자체 미리보기 시트를 띄우는 경우엔 중복 토스트를 생략한다.
        guard showToastAfter else { return }
        let message = memo.contentType == .image
            ? NSLocalizedString("이미지", comment: "Image")
            : processedValue
        showToastMessage(message)
    }

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        showPlainToast(String(format: NSLocalizedString("[%@] 이 복사되었습니다.", comment: "Copied toast message"), message))
    }

    /// 포맷 없이 메시지를 그대로 토스트로 표시(예: 이미지 복사 안내).
    func showPlainToast(_ message: String) {
        toastMessage = message
        showToast = true
        // 시각 장애 접근성: VoiceOver 사용 시 토스트를 볼 수 없으므로 announcement로 알림
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: toastMessage)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Template Processing

    func processTemplateWithInputs(in text: String, inputs: [String: String]) -> String {
        var result = text
        for (placeholder, value) in inputs {
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return processTemplateVariables(in: result)
    }

    // MARK: - Clipboard Capture Card

    /// 앱 진입 시 클립보드 내용을 분류하고, 이전에 "숨기기"한 값과 다르면 상단 카드를 표시한다.
    ///
    /// ⚠️ 클립보드는 **메인 밖에서** 읽는다(`PasteboardReader`). 이 함수는 화면이 뜰 때와
    ///    앱이 앞으로 올 때마다 불리는데, 유니버설 클립보드가 켜져 있으면 값 하나 읽는 데
    ///    옆 기기를 기다리느라 초 단위로 걸린다. 그걸 메인에서 하면 앱이 그 자리에서 굳는다.
    ///    기록: docs/postmortem/HANG_PASTEBOARD_5_0_1.md
    func checkFreshClipboard() {
        #if os(iOS)
        PasteboardReader.string { [weak self] clipboardString in
            guard let self else { return }
            guard let clipboardString, !clipboardString.isEmpty else {
                self.hasFreshClipboard = false
                return
            }

            let lastDismissed = UserDefaults.standard.string(forKey: self.lastDismissedClipboardKey) ?? ""
            if clipboardString == lastDismissed {
                self.hasFreshClipboard = false
                return
            }

            self.value = clipboardString
            let classification = ClipboardClassificationService.shared.classify(content: clipboardString)
            self.clipboardDetectedType = classification.type
            self.clipboardConfidence = classification.confidence
            self.hasFreshClipboard = true
            print("📋 [checkFreshClipboard] 새 클립보드 감지: \(classification.type.rawValue)")
        }
        #endif
    }

    /// 사용자가 "숨기기"한 경우: 같은 값이 다시 나타나지 않도록 저장하고 카드 닫기.
    func dismissClipboardCapture() {
        UserDefaults.standard.set(value, forKey: lastDismissedClipboardKey)
        hasFreshClipboard = false
    }

    /// 저장 플로우로 진입한 경우: 카드만 닫고 dismissed 기록은 남기지 않는다
    /// (저장 이후 사용자가 다시 보고 싶을 수도 있으므로).
    func markClipboardSaved() {
        hasFreshClipboard = false
    }

    /// 감지 타입 기반 자동 제목(키) 제안. 분류 안 된 텍스트는 본문 첫 줄에서 추출.
    var suggestedClipboardTitle: String {
        if clipboardDetectedType == .text {
            let firstLine = value
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespaces) ?? value
            let snippet = String(firstLine.prefix(20))
            return snippet.isEmpty
                ? NSLocalizedString("단축어", comment: "Default snippet title")
                : snippet
        }
        return clipboardDetectedType.suggestedMemoTitle
    }

    /// 원탭 저장: 방금 복사한 클립보드를 제안된 제목으로 즉시 메모로 저장한다.
    /// 제목 입력 없이 키보드에서 바로 꺼내 쓸 수 있게 - 이 앱의 핵심 마찰을 제거.
    func saveClipboardAsMemo() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hasFreshClipboard = false
            return
        }

        let title = suggestedClipboardTitle
        let memo = Memo(
            title: title,
            value: value,
            autoDetectedType: clipboardDetectedType
        )

        do {
            var memos = try MemoStore.shared.load(type: .memo)
            memos.insert(memo, at: 0)
            try MemoStore.shared.save(memos: memos, type: .memo)
            loadedData = sortMemos(memos)
            applyFilters()
            hasFreshClipboard = false
            // 같은 값이 다시 카드로 뜨지 않도록 기록 (저장했으니 재노출 불필요).
            UserDefaults.standard.set(value, forKey: lastDismissedClipboardKey)
            #if os(iOS)
            HapticManager.shared.success()
            #endif
            showPlainToast(String(format: NSLocalizedString("'%@' 단축어로 저장했어요", comment: "Saved clipboard as memo toast"), title))
            print("✅ [saveClipboardAsMemo] '\(title)' 저장 완료")
        } catch {
            print("❌ [saveClipboardAsMemo] 저장 실패: \(error)")
        }
    }

    // MARK: - Sorting

    func sortMemos(_ memos: [Memo]) -> [Memo] {
        // 사용자가 직접 순서를 바꾼 적이 있으면 그 순서를 그대로 따른다(즐겨찾기 고정 해제).
        // 수동 순서에 없는 새 메모는 맨 위(최신순)에 둔다.
        if manualOrderActive {
            let order = manualOrder
            let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            return memos.sorted { a, b in
                switch (rank[a.id], rank[b.id]) {
                case let (ra?, rb?): return ra < rb
                case (nil, _?):      return true   // 순서 미등록(새 메모)은 위로
                case (_?, nil):      return false
                case (nil, nil):     return a.lastEdited > b.lastEdited
                }
            }
        }
        // 기본: 즐겨찾기 먼저 → 최근 수정순
        return memos.sorted { memo1, memo2 in
            if memo1.isFavorite != memo2.isFavorite {
                return memo1.isFavorite && !memo2.isFavorite
            }
            return memo1.lastEdited > memo2.lastEdited
        }
    }

    // MARK: - Migration

    func migrateExistingMemosClassification() {
        let migrationKey = "autoClassificationMigrationCompleted_v1"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("ℹ️ [Migration] 이미 마이그레이션 완료됨")
            return
        }

        print("🔄 [Migration] 기존 메모 자동 분류 시작...")

        do {
            var memos = try MemoStore.shared.load(type: .memo)
            var updated = false

            for index in memos.indices {
                if memos[index].autoDetectedType == nil {
                    let classification = ClipboardClassificationService.shared.classify(content: memos[index].value)
                    memos[index].autoDetectedType = classification.type
                    // ⚠️ category는 절대 자동 변경하지 않는다 - 사용자가 지정한 카테고리는 물론
                    // "기본" 버킷도 그대로 보존. autoDetectedType만 채워 타입 필터/빌트인 탭에 사용.
                    updated = true
                }
            }

            if updated {
                try MemoStore.shared.save(memos: memos, type: .memo)
                loadedData = sortMemos(memos)
                applyFilters()
                print("✅ [Migration] 마이그레이션 완료 및 저장됨")
            } else {
                print("ℹ️ [Migration] 업데이트할 메모 없음")
            }

            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            print("❌ [Migration] 마이그레이션 실패: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func authenticateWithBiometrics(memo: Memo) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ [authenticateWithBiometrics] 생체 인증 불가: \(error?.localizedDescription ?? "Unknown error")")
            showAuthAlert = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: NSLocalizedString("보안 단축어에 접근하려면 인증이 필요합니다", comment: "Biometric auth reason")
        ) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    print("✅ [authenticateWithBiometrics] Face ID 인증 성공")
                    self?.processMemoAfterAuth(memo)
                } else {
                    print("❌ [authenticateWithBiometrics] Face ID 인증 실패: \(authError?.localizedDescription ?? "Unknown error")")
                    self?.showAuthAlert = true
                }
            }
        }
    }

    private func processMemoAfterAuth(_ memo: Memo) {
        if memo.isStack {
            // 콤보(여러 값) 탭 → 값 목록 시트를 띄워 원하는 값 하나를 골라 복사하게 한다.
            // (예전엔 전체를 합쳐 자동 복사했지만, 이제 값 선택 UI로 대체.)
            print("🔁 [processMemoAfterAuth] Combo 메모 - 값 선택 시트 표시")
            selectedStackIdForSheet = memo.id
            return
        }

        if memo.isTemplate {
            // 채울 사용자 변수가 없으면(자동 변수 {날짜} 등만) 하프모달 없이 바로 복사.
            let customTokens = TemplateVariableProcessor.extractCustomTokens(in: memo.value)
            if customTokens.isEmpty {
                print("📄 [processMemoAfterAuth] 템플릿(자동 변수만) - 바로 복사")
                finalizeCopy(memo: memo, processedValue: TemplateVariableProcessor.substitute(memo.value, with: [:]))
                return
            }
            print("📄 [processMemoAfterAuth] 템플릿 메모 - 값 입력 하프모달 표시")
            selectedTemplateIdForSheet = memo.id
            return
        }

        print("📋 [processMemoAfterAuth] 일반 메모 - 바로 복사")
        guard let value = usableValue(of: memo) else { showAuthAlert = true; return }
        // 자동 변수({날짜}/{시간}/{연도} 등)는 템플릿 여부와 무관하게 항상 확장한다.
        // ⚠️ 회귀 복구: 4.3.0은 isTemplate을 저장형 불린으로 뒀고 자동 변수만 쓰는
        // 템플릿(예: "오늘 {날짜}")도 isTemplate=true로 동작했다. 4.3.1에서 isTemplate이
        // 계산형(!templateVariables.isEmpty)으로 바뀌며 자동 변수만 있는 메모는
        // templateVariables=[] → isTemplate=false → 이 일반 경로로 떨어져 {날짜}가 raw로
        // 복사됐다. process()는 자동 변수만 치환하고 커스텀 토큰/일반 텍스트는 그대로 둔다.
        finalizeCopy(memo: memo, processedValue: processTemplateVariables(in: value))
    }

    private func processTemplateVariables(in text: String) -> String {
        // {clipboard}가 있을 때만 클립보드를 읽는다.
        // iOS 16+는 읽을 때마다 붙여넣기 허용 프롬프트를 띄우므로, 토큰이 없는 대다수 메모에서
        // 미리 읽어 두면 아무 이유 없이 프롬프트가 뜬다.
        let clipboard = TemplateVariableProcessor.containsClipboardToken(text)
            // pasteboard-ok: {클립보드} 가 든 단축어를 눌렀을 때만 읽는다
            ? UIPasteboard.general.string
            : nil
        // keepCursorToken은 기본값(false) - 여기는 클립보드로 복사하는 경로라
        // 캐럿을 옮길 수 없다. 토큰이 남으면 "{커서}"가 그대로 붙여넣어진다.
        return TemplateVariableProcessor.process(text, clipboard: clipboard)
    }
}

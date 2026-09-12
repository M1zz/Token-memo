//
//  MemoListSortingAndCategoryTabTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  메인 리스트 정렬(즐겨찾기/수동 순서) + 기본 제공 카테고리 탭 판정 테스트.
//
//  사용자 시나리오: 즐겨찾기는 맨 위, 수동 순서를 한 번 쓰면 내 순서 그대로,
//  새 메모는 맨 위. 기본 제공 카테고리(템플릿/이미지/콤보 탭)는 메모 타입으로 분류.
//

import XCTest
@testable import ClipKeyboard

// MARK: - 정렬 (sortMemos / 수동 순서)

@MainActor
final class MemoListSortingTests: XCTestCase {

    var viewModel: ClipKeyboardListViewModel!

    private let manualOrderKey = "memoManualOrder_v1"
    private let manualOrderActiveKey = "memoManualOrderActive_v1"
    private var groupDefaults: UserDefaults? {
        AppGroup.defaults
    }

    override func setUp() {
        super.setUp()
        viewModel = ClipKeyboardListViewModel()
        clearManualOrder()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
    }

    override func tearDown() {
        clearManualOrder()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        viewModel = nil
        super.tearDown()
    }

    private func clearManualOrder() {
        groupDefaults?.removeObject(forKey: manualOrderKey)
        groupDefaults?.removeObject(forKey: manualOrderActiveKey)
    }

    private func memo(_ title: String, favorite: Bool = false, editedDaysAgo: Int) -> Memo {
        let date = Calendar.current.date(byAdding: .day, value: -editedDaysAgo, to: Date())!
        return Memo(title: title, value: "값", lastEdited: date, isFavorite: favorite)
    }

    // MARK: 기본 정렬

    func testDefaultSort_FavoritesFirst_ThenMostRecent() {
        // Given - 즐겨찾기는 오래됐고, 일반 메모가 더 최신
        let favOld = memo("즐겨찾기(오래됨)", favorite: true, editedDaysAgo: 10)
        let newest = memo("최신", editedDaysAgo: 0)
        let older = memo("그 다음", editedDaysAgo: 3)

        // When
        let sorted = viewModel.sortMemos([older, newest, favOld])

        // Then - 즐겨찾기 먼저, 나머지는 최근 수정순
        XCTAssertEqual(sorted.map(\.title), ["즐겨찾기(오래됨)", "최신", "그 다음"])
    }

    // MARK: 수동 순서

    func testManualOrder_FollowsSavedOrder_AndUnpinsFavorites() {
        // Given - 수동 순서: [일반, 즐겨찾기] (즐겨찾기 고정 해제 확인용)
        let fav = memo("즐겨찾기", favorite: true, editedDaysAgo: 0)
        let plain = memo("일반", editedDaysAgo: 5)
        groupDefaults?.set([plain.id.uuidString, fav.id.uuidString], forKey: manualOrderKey)
        groupDefaults?.set(true, forKey: manualOrderActiveKey)

        // When
        let sorted = viewModel.sortMemos([fav, plain])

        // Then - 즐겨찾기여도 내가 둔 순서 그대로
        XCTAssertEqual(sorted.map(\.title), ["일반", "즐겨찾기"])
    }

    func testManualOrder_NewMemoNotInOrder_GoesToTop() {
        // Given - 저장된 순서엔 A, B만 있음
        let a = memo("A", editedDaysAgo: 5)
        let b = memo("B", editedDaysAgo: 4)
        let newMemo = memo("새 메모", editedDaysAgo: 0)
        groupDefaults?.set([a.id.uuidString, b.id.uuidString], forKey: manualOrderKey)
        groupDefaults?.set(true, forKey: manualOrderActiveKey)

        // When
        let sorted = viewModel.sortMemos([a, b, newMemo])

        // Then - 순서 미등록 새 메모는 맨 위
        XCTAssertEqual(sorted.map(\.title), ["새 메모", "A", "B"])
    }

    func testCommitReorder_PersistsOrderAcrossReload() throws {
        // Given - 재정렬 모드에서 순서를 바꾼 상태
        let a = memo("A", editedDaysAgo: 2)
        let b = memo("B", editedDaysAgo: 1)
        let c = memo("C", editedDaysAgo: 0)
        try MemoStore.shared.save(memos: [a, b, c], type: .memo)
        viewModel.reorderList = [c, a, b]

        // When - 완료(영구 저장)
        viewModel.commitReorder()

        // Then - UserDefaults에 순서+활성 플래그 저장, 이후 정렬이 이 순서를 따름
        XCTAssertEqual(groupDefaults?.bool(forKey: manualOrderActiveKey), true)
        XCTAssertEqual(groupDefaults?.stringArray(forKey: manualOrderKey),
                       [c.id.uuidString, a.id.uuidString, b.id.uuidString])

        // 앱 재시작 시뮬레이션: 새 ViewModel로도 같은 순서
        let freshViewModel = ClipKeyboardListViewModel()
        let resorted = freshViewModel.sortMemos([a, b, c])
        XCTAssertEqual(resorted.map(\.title), ["C", "A", "B"])
    }

    // MARK: 카테고리 범위 재정렬 (현재 탭 메모만 재정렬 → 전체 순서에 병합)

    func testCommitReorder_SubsetOnly_MergesIntoGlobalOrder_KeepingOthersInPlace() {
        // Given - 전체 표시 순서 [A(여행), B(기본), C(여행), D(기본)]에서 여행 탭만 [C, A]로 재정렬
        var a = memo("A", editedDaysAgo: 4); a.category = "여행"
        let b = memo("B", editedDaysAgo: 3)
        var c = memo("C", editedDaysAgo: 2); c.category = "여행"
        let d = memo("D", editedDaysAgo: 1)
        viewModel.loadedData = [a, b, c, d]
        viewModel.reorderList = [c, a]

        // When
        viewModel.commitReorder()

        // Then - 여행 메모가 있던 슬롯(0, 2번째)만 [C, A]로 치환, B·D 위치는 그대로
        XCTAssertEqual(viewModel.loadedData.map(\.title), ["C", "B", "A", "D"])
        XCTAssertEqual(groupDefaults?.stringArray(forKey: manualOrderKey),
                       [c, b, a, d].map { $0.id.uuidString })
        XCTAssertEqual(groupDefaults?.bool(forKey: manualOrderActiveKey), true)
    }

    func testReorderScope_CustomTab_ContainsOnlyThatCategory_InDisplayOrder() {
        // Given - 표시 순서 [C(여행), B(기본), A(여행)]
        var a = memo("A", editedDaysAgo: 2); a.category = "여행"
        let b = memo("B", editedDaysAgo: 1)
        var c = memo("C", editedDaysAgo: 0); c.category = "여행"
        viewModel.loadedData = [c, b, a]
        viewModel.customCategories = ["여행"]

        // Then - 여행 탭 재정렬 대상은 여행 메모만, 화면과 같은 순서
        let scoped = viewModel.reorderScopeMemos(for: .custom("여행"))
        XCTAssertEqual(scoped.map(\.title), ["C", "A"])
    }

    func testReorderScope_BasicTab_ExcludesCustomCategoryAndFavorites() {
        // Given - 여행 카테고리 메모 + 즐겨찾기 + 일반
        var trip = memo("여행메모", editedDaysAgo: 0); trip.category = "여행"
        let fav = memo("즐겨찾기", favorite: true, editedDaysAgo: 1)
        let plain = memo("일반", editedDaysAgo: 2)
        viewModel.loadedData = [trip, fav, plain]
        viewModel.customCategories = ["여행"]

        // Then - 기본 탭 재정렬 대상은 일반 메모뿐 (여행·즐겨찾기는 각자 탭에서)
        let scoped = viewModel.reorderScopeMemos(for: .basic)
        XCTAssertEqual(scoped.map(\.title), ["일반"])
    }
}

// MARK: - 기본 제공 카테고리 (타입별 모아보기)

final class BuiltInCategoryTests: XCTestCase {

    private let template = Memo(title: "템플릿", value: "{이름}님", templateVariables: ["이름"])
    private let plain = Memo(title: "일반", value: "텍스트")
    private let stack = Memo(title: "콤보", value: "1단계", stackValues: ["1단계", "2단계"])
    private let image = Memo(title: "이미지", value: "", imageFileNames: ["a.jpg"], contentType: .image)

    func testTemplatesCategory_MatchesOnlyTemplates() {
        XCTAssertTrue(BuiltInCategory.templates.matches(template))
        XCTAssertFalse(BuiltInCategory.templates.matches(plain))
        XCTAssertFalse(BuiltInCategory.templates.matches(stack))
        XCTAssertFalse(BuiltInCategory.templates.matches(image))
    }

    func testTextMemosCategory_IncludesTemplatesExcludesImageAndStack() {
        // "메모+템플릿" 탭 - 텍스트 기반이면 템플릿도 포함, 이미지·콤보는 제외
        XCTAssertTrue(BuiltInCategory.textMemos.matches(plain))
        XCTAssertTrue(BuiltInCategory.textMemos.matches(template))
        XCTAssertFalse(BuiltInCategory.textMemos.matches(stack))
        XCTAssertFalse(BuiltInCategory.textMemos.matches(image))
    }

    func testImagesCategory_MatchesImageAndMixedContent() {
        XCTAssertTrue(BuiltInCategory.images.matches(image))
        var mixed = plain
        mixed.contentType = .mixed
        XCTAssertTrue(BuiltInCategory.images.matches(mixed))
        XCTAssertFalse(BuiltInCategory.images.matches(plain))
    }

    func testStacksCategory_MatchesOnlyStacks() {
        XCTAssertTrue(BuiltInCategory.combos.matches(stack))
        XCTAssertFalse(BuiltInCategory.combos.matches(plain))
        XCTAssertFalse(BuiltInCategory.combos.matches(template))
    }
}

// MARK: - 카테고리 탭 저장 키 (마지막 본 탭 복원)

final class CategoryTabStorageTests: XCTestCase {

    func testStorageKeyRoundTrip_AllTabKinds() {
        // 마지막 본 탭을 UserDefaults 키로 저장→복원하는 왕복이 모든 탭 종류에서 안전해야 함
        let tabs: [CategoryTab] = [
            .basic, .all, .favorites,
            .builtIn(.templates), .builtIn(.images),
            .custom("여행"), .custom("한글 카테고리 🎒")
        ]
        for tab in tabs {
            XCTAssertEqual(CategoryTab(storageKey: tab.storageKey), tab,
                           "\(tab.storageKey) 왕복 실패")
        }
    }

    func testStorageKey_UnknownKey_ReturnsNil() {
        XCTAssertNil(CategoryTab(storageKey: "__없는키__"))
    }
}

// MARK: - 템플릿 변수 표시 (중괄호 없는 칩 라벨)

final class TemplateBraceDisplayTests: XCTestCase {

    func testStrippingTemplateBraces_RemovesBracesForDisplay() {
        // 칩 라벨엔 변수명만, 실제 텍스트엔 {…}가 남아 파싱은 그대로
        XCTAssertEqual("{이름}".strippingTemplateBraces, "이름")
        XCTAssertEqual("{날짜+3}".strippingTemplateBraces, "날짜+3")
        XCTAssertEqual("중괄호 없음".strippingTemplateBraces, "중괄호 없음")
    }
}

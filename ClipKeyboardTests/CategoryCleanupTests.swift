//
//  CategoryCleanupTests.swift
//  ClipKeyboardTests
//
//  카테고리는 **사용자가 만들 때만** 늘어나고, 줄이는 것도 사용자가 한다.
//  그 두 가지를 지킨다.
//
//   ① 올릴 때 원격을 깎지 않는다. 다만 **새로 만들지도 않는다**
//   ② 너무 늘었을 때 한 번 물어보되, 되풀이해 조르지 않는다
//

import XCTest
@testable import ClipKeyboard

final class CategoryCleanupTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.categoryCleanupAskedAtCount)
        super.tearDown()
    }

    private func memo(_ title: String, category: String) -> Memo {
        var m = Memo(title: title, value: title)
        m.category = category
        return m
    }

    // MARK: - ① 올릴 때 합치기

    func test_원격에만_있던_카테고리를_지우지_않는다() {
        let local = CategorySnapshot(categories: ["업무"])
        let remote = CategorySnapshot(categories: ["업무", "여행", "계좌"])

        let merged = CategorySnapshotStore.union(local: local, remote: remote)

        XCTAssertEqual(merged.categories, ["업무", "여행", "계좌"],
                       "이 기기 것이 먼저, 원격에만 있던 것은 뒤에 붙는다")
    }

    func test_합치기가_없던_카테고리를_만들어내지_않는다() {
        let local = CategorySnapshot(categories: ["업무"])
        let remote = CategorySnapshot(categories: ["업무"])

        let merged = CategorySnapshotStore.union(local: local, remote: remote)

        XCTAssertEqual(merged.categories, ["업무"],
                       "합치기는 지우지 않을 뿐, 늘리는 자리가 아니다")
    }

    func test_아이콘은_이_기기_것이_이긴다() {
        let local = CategorySnapshot(categories: ["업무"], icons: ["업무": "star"])
        let remote = CategorySnapshot(categories: ["업무", "여행"],
                                      icons: ["업무": "folder", "여행": "airplane"])

        let merged = CategorySnapshotStore.union(local: local, remote: remote)

        XCTAssertEqual(merged.icons["업무"], "star", "내가 방금 고른 아이콘이 밀리면 안 된다")
        XCTAssertEqual(merged.icons["여행"], "airplane", "원격에만 있던 것은 데려온다")
    }

    /// 숨김은 "사용자가 치운 것" 목록이다. 합치면 한 기기에서 숨긴 탭을
    /// 다른 기기에서 영영 못 되살린다.
    func test_숨긴_탭은_합치지_않는다() {
        let local = CategorySnapshot(categories: ["업무"], hiddenTabs: [])
        let remote = CategorySnapshot(categories: ["업무"], hiddenTabs: ["여행"])

        let merged = CategorySnapshotStore.union(local: local, remote: remote)

        XCTAssertTrue(merged.hiddenTabs.isEmpty,
                      "숨김을 더하기만 하면 한 방향으로 굳는다")
    }

    /// 기본 제공 탭도 숨김과 같은 성격이다 - 켠 것만 넘어가면 끈 것이 영영 안 넘어간다.
    func test_기본제공_탭은_합치지_않는다() {
        let local = CategorySnapshot(categories: ["업무"], enabledBuiltIns: ["templates"])
        let remote = CategorySnapshot(categories: ["업무"], enabledBuiltIns: ["templates", "combos"])

        let merged = CategorySnapshotStore.union(local: local, remote: remote)

        XCTAssertEqual(merged.enabledBuiltIns, ["templates"],
                       "이 기기에서 끈 탭이 원격 값 때문에 되살아나면 안 된다")
    }

    // MARK: - ② 정리 안내

    func test_빈_카테고리를_고른다() {
        let categories = ["업무", "여행", "계좌"]
        let memos = [memo("a", category: "업무"), memo("b", category: "업무")]

        XCTAssertEqual(CategoryCleanupNudge.emptyCategories(categories, memos: memos),
                       ["여행", "계좌"])
    }

    func test_적당히_많은_정도로는_묻지_않는다() {
        XCTAssertFalse(CategoryCleanupNudge.shouldAsk(categoryCount: 8, emptyCount: 6),
                       "카테고리가 여덟이면 그냥 열심히 쓰는 사람이다")
        XCTAssertFalse(CategoryCleanupNudge.shouldAsk(categoryCount: 20, emptyCount: 2),
                       "빈 칸이 둘뿐이면 곧 쓸 자리를 미리 만들어 둔 것일 수 있다")
    }

    func test_많고_비어_있으면_묻는다() {
        XCTAssertTrue(CategoryCleanupNudge.shouldAsk(categoryCount: 14, emptyCount: 9))
    }

    func test_한_번_괜찮다고_하면_다시_조르지_않는다() {
        CategoryCleanupNudge.markAsked(categoryCount: 14)

        XCTAssertFalse(CategoryCleanupNudge.shouldAsk(categoryCount: 14, emptyCount: 9))
        XCTAssertFalse(CategoryCleanupNudge.shouldAsk(categoryCount: 18, emptyCount: 12),
                       "조금 는 정도로 같은 말을 되풀이하지 않는다")
    }

    func test_그_뒤로_크게_늘면_한_번_더_묻는다() {
        CategoryCleanupNudge.markAsked(categoryCount: 14)

        XCTAssertTrue(CategoryCleanupNudge.shouldAsk(categoryCount: 24, emptyCount: 12),
                      "열 개나 더 늘었으면 사정이 달라진 것이다")
    }
}

//
//  CategorySnapshotTests.swift
//  ClipKeyboardTests
//
//  카테고리가 백업·동기화를 타고 새 기기로 넘어가는 경로를 고정한다.
//
//  원래 사고: 카테고리 목록은 App Group UserDefaults 에만 있어서 백업·동기화 어디에도
//  실리지 않았다. 새 기기에서 복원하면 메모는 다 살아나는데 카테고리 탭이 전부 사라졌다.
//  여기서 지켜야 하는 성질은 두 가지다:
//   ① 있는 걸 옮긴다 - 목록·아이콘·순서·숨김이 스냅샷에 담기고 그대로 복원된다
//   ② **없는 걸로 있는 걸 지우지 않는다** - 빈 스냅샷이 기존 설정을 날리면 더 큰 사고다
//

import XCTest
@testable import ClipKeyboard

final class CategorySnapshotTests: XCTestCase {

    private var defaults: UserDefaults!

    private var allKeys: [String] {
        [CategorySnapshotStore.categoriesKey, CategorySnapshotStore.iconsKey,
         CategorySnapshotStore.colorsKey,
         CategorySnapshotStore.hiddenTabsKey, CategorySnapshotStore.enabledBuiltInsKey,
         CategorySnapshotStore.featureEnabledKey]
    }

    override func setUp() {
        super.setUp()
        defaults = AppGroup.defaults
        allKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    override func tearDown() {
        allKeys.forEach { defaults.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - 직렬화

    /// 스냅샷이 왕복해도 순서·아이콘·숨김이 그대로여야 한다.
    /// 순서가 곧 탭 순서라 배열 순서를 잃으면 사용자 눈에는 "뒤죽박죽 복원"이다.
    func testSnapshotRoundTripsPreservingOrder() throws {
        let original = CategorySnapshot(
            categories: ["업무", "개인", "쇼핑"],
            icons: ["업무": "briefcase", "개인": "person"],
            hiddenTabs: ["쇼핑"],
            enabledBuiltIns: ["email"],
            featureEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(CategorySnapshot.self, from: data)

        XCTAssertEqual(restored.categories, ["업무", "개인", "쇼핑"], "순서가 유지돼야 한다")
        XCTAssertEqual(restored.icons["업무"], "briefcase")
        XCTAssertEqual(restored.hiddenTabs, ["쇼핑"])
        XCTAssertEqual(restored.enabledBuiltIns, ["email"])
        XCTAssertTrue(restored.featureEnabled)
    }

    /// 구버전이 만든(필드가 빠진) JSON도 읽혀야 한다 - 다운그레이드·상위호환 대비.
    func testDecodesSnapshotWithMissingFields() throws {
        let json = #"{"categories":["업무"]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let snapshot = try JSONDecoder().decode(CategorySnapshot.self, from: data)

        XCTAssertEqual(snapshot.categories, ["업무"])
        XCTAssertTrue(snapshot.icons.isEmpty)
        XCTAssertFalse(snapshot.featureEnabled)
    }

    // MARK: - 적용

    func testCurrentReadsFromDefaults() {
        defaults.set(["업무", "개인"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["업무": "briefcase"], forKey: CategorySnapshotStore.iconsKey)

        let snapshot = CategorySnapshotStore.current()

        XCTAssertEqual(snapshot.categories, ["업무", "개인"])
        XCTAssertEqual(snapshot.icons["업무"], "briefcase")
    }

    /// 복원(.replace)은 순서까지 스냅샷 기준으로 맞춘다.
    func testApplyReplaceOverwritesOrder() {
        defaults.set(["쇼핑"], forKey: CategorySnapshotStore.categoriesKey)
        let snapshot = CategorySnapshot(categories: ["업무", "개인"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .replace)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무", "개인"])
    }

    /// 동기화(.merge)는 이 기기에만 있는 카테고리를 지우지 않는다.
    func testApplyMergeKeepsLocalOnlyCategories() {
        defaults.set(["로컬전용"], forKey: CategorySnapshotStore.categoriesKey)
        let snapshot = CategorySnapshot(categories: ["업무"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .merge)

        let result = defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey) ?? []
        XCTAssertTrue(result.contains("로컬전용"), "원격에 없다고 로컬 카테고리를 지우면 안 된다")
        XCTAssertTrue(result.contains("업무"))
    }

    /// 병합 시 중복이 쌓이지 않아야 한다(동기화가 반복돼도 목록이 늘어나면 안 됨).
    func testApplyMergeIsIdempotent() {
        let snapshot = CategorySnapshot(categories: ["업무", "개인"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .merge)
        CategorySnapshotStore.apply(snapshot, strategy: .merge)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무", "개인"])
    }

    // MARK: - 동기화(.sync)는 숨김·기본 제공을 그대로 비춘다

    /// 아이폰에서 탭을 **되살리면** 맥에서도 되살아나야 한다.
    /// 합집합이던 시절엔 켠 것·숨긴 것만 넘어가고 끈 것·되살린 것은 영영 안 넘어가서,
    /// 기기를 오갈수록 설정이 쌓이기만 하는 래칫이 됐다.
    func testSyncMirrorsHiddenTabs() {
        defaults.set(["여행", "__favorites__"], forKey: CategorySnapshotStore.hiddenTabsKey)
        let snapshot = CategorySnapshot(categories: ["업무"], hiddenTabs: ["여행"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .sync)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.hiddenTabsKey), ["여행"],
                       "다른 기기에서 즐겨찾기 숨김을 풀었으면 여기서도 풀려야 한다")
    }

    /// 기본 제공 카테고리를 **끄면** 다른 기기에서도 꺼져야 한다.
    func testSyncMirrorsEnabledBuiltIns() {
        defaults.set(["templates", "combos"], forKey: CategorySnapshotStore.enabledBuiltInsKey)
        let snapshot = CategorySnapshot(categories: ["업무"], enabledBuiltIns: ["templates"],
                                        featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .sync)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.enabledBuiltInsKey), ["templates"],
                       "콤보 탭을 껐으면 여기서도 꺼져야 한다")
    }

    /// 거울은 **숨김·기본 제공에만** 적용된다 - 카테고리 목록은 여전히 더하기만 한다.
    func testSyncStillKeepsLocalOnlyCategories() {
        defaults.set(["로컬전용"], forKey: CategorySnapshotStore.categoriesKey)
        let snapshot = CategorySnapshot(categories: ["업무"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .sync)

        let result = defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey) ?? []
        XCTAssertTrue(result.contains("로컬전용"), "동기화가 이 기기 카테고리를 지우면 안 된다")
        XCTAssertTrue(result.contains("업무"))
    }

    /// 가져오기(.merge)는 그대로 합집합이어야 한다 - 파일이 이 기기 설정을 지우면 안 된다.
    func testMergeStillUnionsHiddenTabs() {
        defaults.set(["여행"], forKey: CategorySnapshotStore.hiddenTabsKey)
        let snapshot = CategorySnapshot(categories: ["업무"], hiddenTabs: ["쇼핑"], featureEnabled: true)

        CategorySnapshotStore.apply(snapshot, strategy: .merge)

        let hidden = Set(defaults.stringArray(forKey: CategorySnapshotStore.hiddenTabsKey) ?? [])
        XCTAssertEqual(hidden, ["여행", "쇼핑"], "가져오기는 합친다 - 기존 숨김이 사라지면 안 된다")
    }

    /// ⚠️ 핵심 안전장치: **빈 스냅샷은 아무것도 지우지 않는다.**
    func testEmptySnapshotDoesNotWipeExisting() {
        defaults.set(["소중한카테고리"], forKey: CategorySnapshotStore.categoriesKey)

        CategorySnapshotStore.apply(CategorySnapshot(), strategy: .replace)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["소중한카테고리"])
    }

    /// 카테고리가 복원되면 기능도 켜 준다 - 꺼져 있으면 탭이 안 보여 "복원 실패"로 보인다.
    func testApplyEnablesFeatureWhenCategoriesExist() {
        CategorySnapshotStore.apply(CategorySnapshot(categories: ["업무"]), strategy: .replace)

        XCTAssertTrue(defaults.bool(forKey: CategorySnapshotStore.featureEnabledKey))
    }

    // MARK: - 색 (5.0.6 에 뒤늦게 합류)

    /// 색은 `userCategoryColors_v1` 에만 살아서 백업 어디에도 안 실렸다.
    /// 복원하면 이름은 돌아오는데 색이 전부 팔레트 기본값으로 리셋됐다.
    func test_색도_스냅샷에_담기고_왕복한다() throws {
        let original = CategorySnapshot(categories: ["업무"], colors: ["업무": "FF0000"])

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(CategorySnapshot.self, from: data)

        XCTAssertEqual(restored.colors["업무"], "FF0000")
    }

    func test_색이_없던_옛_스냅샷도_읽힌다() throws {
        let json = #"{"categories":["업무"],"icons":{"업무":"briefcase"}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let snapshot = try JSONDecoder().decode(CategorySnapshot.self, from: data)

        XCTAssertEqual(snapshot.categories, ["업무"])
        XCTAssertTrue(snapshot.colors.isEmpty)
    }

    func test_현재_설정을_읽을_때_색도_담는다() {
        defaults.set(["업무"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["업무": "00FF00"], forKey: CategorySnapshotStore.colorsKey)

        XCTAssertEqual(CategorySnapshotStore.current().colors["업무"], "00FF00")
    }

    func test_복원은_색까지_되돌린다() {
        CategorySnapshotStore.apply(
            CategorySnapshot(categories: ["업무"], colors: ["업무": "0000FF"]), strategy: .replace)

        let stored = defaults.dictionary(forKey: CategorySnapshotStore.colorsKey) as? [String: String]
        XCTAssertEqual(stored?["업무"], "0000FF")
    }

    // MARK: - .replace 는 그 시점 상태로 되돌린다

    /// 복원인데 아이콘·숨김이 합집합으로 남으면 "되돌렸는데 지운 게 살아 있다"가 된다.
    func test_복원은_이_기기에만_있던_설정을_남기지_않는다() {
        defaults.set(["옛것"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["옛것": "trash"], forKey: CategorySnapshotStore.iconsKey)
        defaults.set(["옛것"], forKey: CategorySnapshotStore.hiddenTabsKey)

        CategorySnapshotStore.apply(
            CategorySnapshot(categories: ["업무"], icons: ["업무": "briefcase"], featureEnabled: true),
            strategy: .replace)

        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무"])
        let icons = defaults.dictionary(forKey: CategorySnapshotStore.iconsKey) as? [String: String]
        XCTAssertNil(icons?["옛것"], "복원은 그 시점 상태다. 지웠던 카테고리의 아이콘이 남으면 안 된다")
        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.hiddenTabsKey), [],
                       "백업 시점에 숨긴 탭이 없었으면 복원 뒤에도 없어야 한다")
    }

    /// 반대로 동기화(.merge)는 이 기기 설정을 지우지 않는다.
    func test_동기화는_이_기기_색과_아이콘을_지우지_않는다() {
        defaults.set(["로컬": "star"], forKey: CategorySnapshotStore.iconsKey)
        defaults.set(["로컬": "ABCDEF"], forKey: CategorySnapshotStore.colorsKey)

        CategorySnapshotStore.apply(
            CategorySnapshot(categories: ["업무"], icons: ["업무": "briefcase"],
                             colors: ["업무": "123456"]),
            strategy: .merge)

        let icons = defaults.dictionary(forKey: CategorySnapshotStore.iconsKey) as? [String: String]
        let colors = defaults.dictionary(forKey: CategorySnapshotStore.colorsKey) as? [String: String]
        XCTAssertEqual(icons?["로컬"], "star")
        XCTAssertEqual(icons?["업무"], "briefcase")
        XCTAssertEqual(colors?["로컬"], "ABCDEF")
        XCTAssertEqual(colors?["업무"], "123456")
    }

    /// 동기화용 스냅샷은 안 쓰는 카테고리를 거르는데, 색도 같이 걸러야 짝이 맞는다.
    func test_동기화_스냅샷은_안_쓰는_카테고리의_색을_싣지_않는다() {
        defaults.set(["쓰는것", "안쓰는것"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["쓰는것": "AAAAAA", "안쓰는것": "BBBBBB"], forKey: CategorySnapshotStore.colorsKey)

        let snapshot = CategorySnapshotStore.syncable(memos: [memo("a", category: "쓰는것")],
                                                     sampleIDs: [])

        XCTAssertEqual(snapshot.colors["쓰는것"], "AAAAAA")
        XCTAssertNil(snapshot.colors["안쓰는것"])
    }

    // MARK: - 옛 백업 구제 (메모에서 역산)

    private func memo(_ title: String, category: String) -> Memo {
        var m = Memo(title: title, value: "v")
        m.category = category
        return m
    }

    /// 카테고리 정보가 없는 옛 백업 → 메모의 category 값에서 이름을 되살린다.
    func testRebuildFromMemosRecoversNames() {
        let memos = [memo("a", category: "업무"), memo("b", category: "개인"), memo("c", category: "업무")]

        let added = CategorySnapshotStore.rebuildFromMemos(memos)

        XCTAssertEqual(added, ["업무", "개인"], "등장 순서를 유지하고 중복은 제거한다")
        XCTAssertTrue(defaults.bool(forKey: CategorySnapshotStore.featureEnabledKey))
    }

    /// "기본"은 시스템 기본값이라 사용자 정의 목록에 넣지 않는다.
    func testRebuildSkipsDefaultCategory() {
        let added = CategorySnapshotStore.rebuildFromMemos([memo("a", category: "기본")])

        XCTAssertTrue(added.isEmpty)
    }

    /// 이미 있는 카테고리는 다시 추가하지 않는다.
    func testRebuildDoesNotDuplicateExisting() {
        defaults.set(["업무"], forKey: CategorySnapshotStore.categoriesKey)

        let added = CategorySnapshotStore.rebuildFromMemos([memo("a", category: "업무"), memo("b", category: "개인")])

        XCTAssertEqual(added, ["개인"])
        XCTAssertEqual(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey), ["업무", "개인"])
    }

    /// 복구할 게 없으면 아무것도 건드리지 않는다.
    func testRebuildWithNoCategoriesChangesNothing() {
        let added = CategorySnapshotStore.rebuildFromMemos([memo("a", category: "")])

        XCTAssertTrue(added.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: CategorySnapshotStore.categoriesKey))
    }

    // MARK: - 동기화 대상 추리기 (폰 2대·다국어 오염 방지)

    /// 온보딩 페르소나가 심은 카테고리는 **기기 언어별로 이름이 다르다**
    /// (회사 이메일 / Work Email). 안 쓰는 것까지 동기화하면 폰 2대에서 중복이 쌓인다.
    /// → 비샘플 메모가 붙은 카테고리만 동기화한다.
    func testSyncableKeepsOnlyCategoriesInUse() {
        defaults.set(["업무", "안쓰는시드"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set(["업무": "briefcase", "안쓰는시드": "star"], forKey: CategorySnapshotStore.iconsKey)

        let snapshot = CategorySnapshotStore.syncable(memos: [memo("a", category: "업무")], sampleIDs: [])

        XCTAssertEqual(snapshot.categories, ["업무"])
        XCTAssertNil(snapshot.icons["안쓰는시드"], "안 쓰는 카테고리의 아이콘도 함께 빠져야 한다")
    }

    /// 샘플 메모에만 붙은 카테고리는 동기화하지 않는다.
    /// 샘플은 기기 언어를 따라 심기므로 그대로 올리면 언어별 중복이 생긴다.
    func testSyncableExcludesCategoriesUsedOnlyBySamples() {
        defaults.set(["샘플전용"], forKey: CategorySnapshotStore.categoriesKey)
        let sample = memo("s", category: "샘플전용")

        let snapshot = CategorySnapshotStore.syncable(memos: [sample], sampleIDs: [sample.id])

        XCTAssertTrue(snapshot.categories.isEmpty)
    }

    /// 백업(`current`)은 전부 담는다 - "이 기기 상태를 그대로 되살리기"라
    /// 아직 안 쓴 카테고리도 남아야 한다. 동기화와 기준이 다르다.
    func testCurrentKeepsUnusedCategoriesForBackup() {
        defaults.set(["업무", "아직안씀"], forKey: CategorySnapshotStore.categoriesKey)

        XCTAssertEqual(CategorySnapshotStore.current().categories, ["업무", "아직안씀"])
    }

    // MARK: - 카테고리는 사용자가 만들 때만 늘어난다

    /// ⛔️ 한때 `syncable` 이 `memo.category` 문자열을 목록에 주워 담았다.
    ///    "목록에는 없는데 단축어는 이미 그 카테고리에 들어 있는" 경우를 받아 주려던
    ///    것이었는데, 카테고리가 걷잡을 수 없이 불어났다.
    ///
    ///    고리: 올릴 때는 payload 를 **교체**하고 받을 때는 `.merge` 로 **더하기만** 한다.
    ///    한 번 들어간 이름은 다시 빠지지 않으니 오갈수록 쌓이는 래칫이 된다.
    ///    게다가 주워 온 이름이 사용자가 만든 카테고리라는 보장이 없다. 지운 카테고리를
    ///    아직 달고 있는 단축어, 다른 언어로 심긴 페르소나 이름, 가져오기로 들어온 임의의
    ///    문자열이 전부 "사용자가 만든 카테고리"로 승격됐다.
    ///
    ///    **앱은 카테고리를 스스로 늘리지 않는다.** 늘리는 것은 사용자뿐이다.
    func test_단축어에_붙은_이름을_목록으로_승격시키지_않는다() {
        defaults.set(["내앱"], forKey: CategorySnapshotStore.categoriesKey)

        let snapshot = CategorySnapshotStore.syncable(
            memos: [memo("a", category: "내앱"),
                    memo("b", category: "계좌번호"),
                    memo("c", category: "여행")],
            sampleIDs: [])

        XCTAssertEqual(snapshot.categories, ["내앱"],
                       "목록에 있던 것만 실린다. 단축어가 달고 있는 이름은 카테고리가 아니다")
    }

    /// 목록에 있고 실제로 쓰이는 것만 싣는다는 원래 기준은 그대로다.
    func test_목록에_있어도_안_쓰이면_싣지_않는다() {
        defaults.set(["업무", "아직안씀"], forKey: CategorySnapshotStore.categoriesKey)

        let snapshot = CategorySnapshotStore.syncable(
            memos: [memo("a", category: "업무")], sampleIDs: [])

        XCTAssertEqual(snapshot.categories, ["업무"])
    }

    /// 샘플 단축어만 붙은 카테고리는 싣지 않는다.
    /// 페르소나 시드가 기기 언어별로 중복돼 올라가던 원래 문제를 막는 기준이다.
    func test_샘플만_붙은_카테고리는_싣지_않는다() {
        defaults.set(["샘플전용", "진짜"], forKey: CategorySnapshotStore.categoriesKey)
        let sample = memo("s", category: "샘플전용")
        let real = memo("r", category: "진짜")

        let snapshot = CategorySnapshotStore.syncable(memos: [sample, real], sampleIDs: [sample.id])

        XCTAssertEqual(snapshot.categories, ["진짜"])
    }

    /// `"기본"` 은 저장 센티널이지 사용자 카테고리가 아니다.
    /// 목록에 들어가면 기본 탭과 같은 이름의 탭이 하나 더 서서 단축어가 두 곳에 보인다.
    func test_기본_센티널은_목록에_들어가지_않는다() {
        defaults.set(["업무"], forKey: CategorySnapshotStore.categoriesKey)

        let snapshot = CategorySnapshotStore.syncable(
            memos: [memo("a", category: "기본"), memo("b", category: "업무")],
            sampleIDs: [])

        XCTAssertEqual(snapshot.categories, ["업무"])
        XCTAssertFalse(snapshot.categories.contains(CategorySnapshotStore.basicCategoryName))
    }

    /// 즐겨찾기 숨김은 카테고리 이름이 아니라 센티널(`__favorites__`)이라
    /// "쓰이는 카테고리만" 필터에 걸려 매번 탈락했다 - 즐겨찾기 탭을 숨겨도
    /// 그 설정이 다른 기기로 영영 넘어가지 않았다.
    func testSyncableKeepsHiddenFavoritesSentinel() {
        defaults.set(["업무"], forKey: CategorySnapshotStore.categoriesKey)
        defaults.set([CategoryBucketRule.favoritesTabKey, "안쓰는카테고리"],
                     forKey: CategorySnapshotStore.hiddenTabsKey)

        let snapshot = CategorySnapshotStore.syncable(memos: [memo("a", category: "업무")], sampleIDs: [])

        XCTAssertTrue(snapshot.hiddenTabs.contains(CategoryBucketRule.favoritesTabKey),
                      "즐겨찾기 숨김은 카테고리가 아니라 센티널이라 걸러지면 안 된다")
        XCTAssertFalse(snapshot.hiddenTabs.contains("안쓰는카테고리"),
                       "안 쓰는 카테고리의 숨김은 그대로 빠진다")
    }
}

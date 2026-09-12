//
//  SaveIntoCategoryTests.swift
//  ClipKeyboardTests
//
//  저장할 때 고른 카테고리가 지켜지는지, 그리고 저장한 것이 **보이는 자리로** 데려가는지.
//
//  왜 생겼나: 사용자 피드백 둘.
//
//    저장할 때 카테고리 지정할 수 있게 해주세영
//    기본 가서 다시 카테고리로 보내는 거 불편해요
//
//    한 개 저장하면 저장한 위치의 카테고리 : 저장된거 바로 보이는 위치로 도달하게
//    해즈세요. 순간 길 헤매요.
//
//  여기서 지키는 약속.
//   ① 고른 카테고리가 자동 분류를 이긴다 (골랐는데 딴 데 가 있으면 안 된다)
//   ② 카테고리 탭에서 + 로 들어오면 그 칸이 미리 골라져 있다
//   ③ 저장한 것이 지금 탭에서 안 보이면 **보이는 탭으로** 옮겨 간다
//   ④ 이미 보이면 화면을 옮기지 않는다 (잘 보이는데 옮기면 그게 길을 헤매게 한다)
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class SaveIntoCategoryTests: XCTestCase {

    private var viewModel: ClipKeyboardListViewModel!
    private var groupDefaults: UserDefaults? { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        viewModel = ClipKeyboardListViewModel()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
    }

    override func tearDown() {
        groupDefaults?.removeObject(forKey: DefaultsKey.userDefinedCategoriesV1)
        CategoryStore.shared.reload()
        groupDefaults?.removeObject(forKey: DefaultsKey.hiddenCategoryTabsV1)
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        viewModel = nil
        super.tearDown()
    }

    private func seed(categories: [String], memos: [Memo]) {
        groupDefaults?.set(categories, forKey: DefaultsKey.userDefinedCategoriesV1)
        groupDefaults?.set([String](), forKey: DefaultsKey.hiddenCategoryTabsV1)
        try? MemoStore.shared.save(memos: memos, type: .memo, recordHistory: false)
        viewModel.loadCustomCategories()
        viewModel.loadMemos()
    }

    // MARK: - ①② 고른 카테고리가 지켜진다

    /// ⚠️ `CategoryStore` 는 싱글톤이라 목록을 **메모리에** 들고 있다. 시험이 defaults 만
    ///    갈아끼우면 저장소는 예전 목록을 그대로 보고 있어서, 방금 심은 카테고리를 모른다.
    private func seedCategories(_ names: [String]) {
        groupDefaults?.set(names, forKey: DefaultsKey.userDefinedCategoriesV1)
        CategoryStore.shared.reload()
    }

    private func makeAddViewModel(insertedCategory: String = "텍스트") -> MemoAddViewModel {
        let vm = MemoAddViewModel(saveMemoUseCase: SaveMemoUseCase(), memoRepository: MemoRepository())
        vm.onAppear(memoId: nil,
                    insertedKeyword: "",
                    insertedValue: "",
                    insertedCategory: insertedCategory,
                    insertedIsTemplate: false,
                    insertedIsSecure: false,
                    insertedIsStack: false,
                    insertedStackValues: [],
                    insertedHint: "",
                    insertedIsFavorite: false)
        return vm
    }

    private func savedMemo(titled title: String) -> Memo? {
        (try? MemoStore.shared.load(type: .memo))?.first { $0.title == title }
    }

    /// 저장 화면에서 고른 카테고리가 자동 분류를 이겨야 한다.
    /// (이메일 주소를 넣으면 자동 분류가 '이메일'로 잡는다. 사람이 '업무'를 골랐으면 '업무'다)
    func test_고른_카테고리가_자동_분류를_이긴다() {
        seedCategories(["업무"])
        let vm = makeAddViewModel()
        vm.keyword = "회사메일"
        vm.value = "leeo@kakao.com"
        vm.selectUserCategory("업무")

        vm.saveMemo(dismiss: {})

        XCTAssertEqual(savedMemo(titled: "회사메일")?.category, "업무",
                       "골랐는데 딴 데 가 있으면 고른 의미가 없다")
    }

    /// 카테고리 탭에서 + 로 들어오면 그 칸이 미리 골라져 있어야 한다.
    func test_카테고리_탭에서_들어오면_그_칸이_골라져_있다() {
        seedCategories(["여행"])

        let vm = makeAddViewModel(insertedCategory: "여행")

        XCTAssertEqual(vm.userCategory, "여행")
        XCTAssertEqual(vm.selectedCategory, "텍스트",
                       "갈 칸 이야기가 내용의 갈래를 덮으면 안 된다(이미지 모드가 튕긴다)")
    }

    func test_카테고리를_안_고르면_예전처럼_자동_분류한다() {
        let vm = makeAddViewModel()
        vm.keyword = "메일주소"
        vm.value = "leeo@kakao.com"

        vm.saveMemo(dismiss: {})

        XCTAssertEqual(savedMemo(titled: "메일주소")?.category, "이메일",
                       "고른 게 없으면 예전 그대로 자동 분류가 정한다")
    }

    /// 초기화는 **내용만** 지운다. 들어온 칸까지 지우면 저장한 것이 기본으로 가 버린다.
    func test_초기화는_들어온_카테고리를_지우지_않는다() {
        seedCategories(["업무"])
        let vm = makeAddViewModel(insertedCategory: "업무")
        vm.value = "쓰다 만 것"

        vm.reset()

        XCTAssertEqual(vm.userCategory, "업무")
        XCTAssertTrue(vm.value.isEmpty)
    }

    func test_기본으로_들어왔으면_초기화_뒤에도_기본이다() {
        seedCategories(["업무"])
        let vm = makeAddViewModel()
        vm.selectUserCategory("업무")

        vm.reset()

        XCTAssertTrue(vm.userCategory.isEmpty, "여기서 고른 것은 내용과 함께 지워지는 게 맞다")
    }

    // MARK: - ③④ 저장한 것이 보이는 자리로 데려간다

    func test_기본_탭에서_업무로_저장하면_업무_탭으로_옮겨_간다() {
        let saved = Memo(title: "회의록", value: "값", category: "업무")
        seed(categories: ["업무"], memos: [saved])
        viewModel.selectCategoryTab(.basic, animated: false)

        viewModel.revealSavedMemo(id: saved.id)

        XCTAssertEqual(viewModel.selectedCategoryTab, .custom("업무"),
                       "저장은 됐는데 화면이 기본에 남아 있으면 만든 것이 사라진 것처럼 보인다")
    }

    func test_이미_보이는_자리면_화면을_옮기지_않는다() {
        let saved = Memo(title: "회의록", value: "값", category: "업무")
        seed(categories: ["업무"], memos: [saved])
        viewModel.selectCategoryTab(.custom("업무"), animated: false)

        viewModel.revealSavedMemo(id: saved.id)

        XCTAssertEqual(viewModel.selectedCategoryTab, .custom("업무"),
                       "카테고리 탭에서 + 로 만든 흔한 경우다. 잘 보이는데 또 옮기면 그게 길을 헤매게 한다")
    }

    /// 즐겨찾기·템플릿 탭이 탭 목록에서 앞에 있어도, **사람이 고른 칸**이 이긴다.
    func test_즐겨찾기여도_고른_카테고리로_데려간다() {
        var saved = Memo(title: "회의록", value: "값", category: "업무")
        saved.isFavorite = true
        seed(categories: ["업무"], memos: [saved])
        viewModel.selectCategoryTab(.basic, animated: false)

        viewModel.revealSavedMemo(id: saved.id)

        XCTAssertEqual(viewModel.selectedCategoryTab, .custom("업무"),
                       "보이기만 하면 되는 게 아니라 고른 자리로 가야 한다")
    }

    func test_카테고리를_안_고르면_기본_탭으로_데려간다() {
        let saved = Memo(title: "그냥 메모", value: "값", category: "텍스트")
        seed(categories: ["업무"], memos: [saved])
        viewModel.selectCategoryTab(.custom("업무"), animated: false)

        viewModel.revealSavedMemo(id: saved.id)

        XCTAssertEqual(viewModel.selectedCategoryTab, .basic)
    }

    func test_없는_단축어를_가리키면_아무것도_하지_않는다() {
        seed(categories: ["업무"], memos: [])
        viewModel.selectCategoryTab(.basic, animated: false)

        viewModel.revealSavedMemo(id: UUID())

        XCTAssertEqual(viewModel.selectedCategoryTab, .basic)
    }

    /// 탭을 숨긴 카테고리에 저장하면 그 단축어는 기본 칸에 모인다(`CategoryBucketRule`).
    /// 그러면 화면도 기본으로 가야 한다. 갈 수 없는 탭으로 보내면 빈 화면만 보인다.
    func test_숨긴_카테고리에_저장하면_기본_탭으로_데려간다() {
        let saved = Memo(title: "회의록", value: "값", category: "업무")
        groupDefaults?.set(["업무"], forKey: DefaultsKey.userDefinedCategoriesV1)
        groupDefaults?.set(["업무"], forKey: DefaultsKey.hiddenCategoryTabsV1)
        try? MemoStore.shared.save(memos: [saved], type: .memo, recordHistory: false)
        viewModel.loadCustomCategories()
        viewModel.loadMemos()
        viewModel.selectCategoryTab(.favorites, animated: false)

        viewModel.revealSavedMemo(id: saved.id)

        XCTAssertEqual(viewModel.selectedCategoryTab, .basic)
    }
}

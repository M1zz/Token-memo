//
//  DataPortabilityCategoryTests.swift
//  ClipKeyboardTests
//
//  파일 내보내기/가져오기 번들이 **카테고리 설정까지** 싣는지 고정한다.
//
//  원래 사고: 번들에는 단축어·콤보·클립보드·이미지만 들어갔다. 단축어마다 `category`
//  문자열은 붙어 있었지만 **목록 자체가 없어서**, 파일로 백업했다 가져오면 단축어는 전부
//  돌아오는데 카테고리 탭이 하나도 없었다. 사용자 눈에는 "카테고리가 다 날아갔다"다.
//
//  여기서 지켜야 하는 성질:
//   ① 내보낸 번들에 카테고리 스냅샷이 들어 있다
//   ② 이 필드가 생기기 **전에** 만든 파일도 그대로 읽힌다(옵셔널)
//

import XCTest
@testable import ClipKeyboard

final class DataPortabilityCategoryTests: XCTestCase {

    private func makeBundle(categories: CategorySnapshot?) -> ExportBundle {
        ExportBundle(
            formatVersion: DataPortability.currentFormatVersion,
            exportedAt: Date(),
            appVersion: "test",
            memos: [], smartClipboard: [], combos: [], images: [:],
            categories: categories
        )
    }

    /// 번들이 카테고리를 싣고 그대로 되읽힌다 - 순서·아이콘·색까지.
    func test_번들이_카테고리를_싣고_되읽는다() throws {
        let snapshot = CategorySnapshot(
            categories: ["업무", "개인"],
            icons: ["업무": "briefcase"],
            colors: ["업무": "FF0000"],
            hiddenTabs: ["개인"],
            enabledBuiltIns: ["email"],
            featureEnabled: true
        )

        let data = try JSONEncoder().encode(makeBundle(categories: snapshot))
        let decoded = try JSONDecoder().decode(ExportBundle.self, from: data)

        let restored = try XCTUnwrap(decoded.categories, "번들에 카테고리가 실려야 한다")
        XCTAssertEqual(restored.categories, ["업무", "개인"], "순서가 곧 탭 순서다")
        XCTAssertEqual(restored.icons["업무"], "briefcase")
        XCTAssertEqual(restored.colors["업무"], "FF0000")
        XCTAssertEqual(restored.hiddenTabs, ["개인"])
        XCTAssertEqual(restored.enabledBuiltIns, ["email"])
        XCTAssertTrue(restored.featureEnabled)
    }

    /// 이 필드가 없던 시절에 내보낸 파일도 읽혀야 한다. 못 읽으면 가져오기가 통째로 실패한다.
    func test_카테고리가_없던_옛_파일도_읽힌다() throws {
        let json = """
        {"formatVersion":1,"exportedAt":0,"appVersion":"4.4.8",
         "memos":[],"smartClipboard":[],"combos":[],"images":{}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(ExportBundle.self, from: data)

        XCTAssertNil(decoded.categories, "옛 파일에는 카테고리가 없다 - 그래도 읽혀야 한다")
        XCTAssertEqual(decoded.memos.count, 0)
    }

    /// 가져오기 요약이 되살린 카테고리 수를 말한다 - 조용히 넘어가면 확인할 길이 없다.
    func test_가져오기_요약이_카테고리_수를_말한다() {
        let summary = ImportSummary(addedMemos: 3, updatedMemos: 0, totalMemos: 3,
                                    addedStacks: 0, addedClips: 0, images: 0, categories: 2)

        XCTAssertTrue(summary.localizedDescription.contains("2"),
                      "요약에 카테고리 수가 들어가야 한다")
    }
}

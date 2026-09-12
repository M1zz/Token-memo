//
//  BulkImportBundlingTests.swift
//  ClipKeyboardTests
//
//  일괄 가져오기의 **콤보로 묶기** 규칙 - 컬렉션에서 체크한 것들을 키 하나로 합칠 때.
//   · 떨어져 있는 항목끼리도 묶인다 (예전엔 바로 위 항목과만 가능했다)
//   · 합친 자리와 단계 차례는 **화면에 놓인 순서**를 따른다 (고른 순서가 아니다)
//   · 하나라도 보안이면 결과도 보안 - 지키던 것을 합치다가 풀어버리면 안 된다
//   · 넣기로 한 것이 하나라도 있으면 결과도 넣는다
//

import XCTest
@testable import ClipKeyboard

final class BulkImportBundlingTests: XCTestCase {

    private typealias Draft = BulkImportView.Draft

    private func sample() -> [Draft] {
        [
            Draft(title: "아이디", values: ["a@b.com"]),
            Draft(title: "메모", values: ["그냥 메모"]),
            Draft(title: "비밀번호", values: ["pw"], isSecure: true),
            Draft(title: "OTP", values: ["123456"])
        ]
    }

    // MARK: - 떨어져 있어도 묶인다

    func testMergesNonAdjacentDrafts() {
        let drafts = sample()
        // 0번(아이디)과 2번(비밀번호) - 사이에 '메모'가 끼어 있다.
        let selection: Set<UUID> = [drafts[0].id, drafts[2].id]

        let result = BulkImportView.merging(drafts, selection: selection).drafts

        XCTAssertEqual(result.count, 3, "둘이 하나로 합쳐져 하나 줄어야 한다")
        XCTAssertEqual(result[0].values, ["a@b.com", "pw"])
        XCTAssertTrue(result[0].isStack)
        XCTAssertEqual(result[1].title, "메모", "사이에 끼어 있던 항목은 그대로 남는다")
        XCTAssertEqual(result[2].title, "OTP")
    }

    // MARK: - 차례는 화면 순서를 따른다

    func testStepOrderFollowsListOrderNotSelectionOrder() {
        let drafts = sample()
        // 뒤엣것을 먼저 고르더라도 단계는 화면 순서(아이디 → 비밀번호 → OTP)여야 한다.
        let selection: Set<UUID> = [drafts[3].id, drafts[2].id, drafts[0].id]

        let result = BulkImportView.merging(drafts, selection: selection).drafts

        XCTAssertEqual(result[0].values, ["a@b.com", "pw", "123456"])
    }

    func testMergedItemKeepsPositionOfFirstSelected() {
        let drafts = sample()
        let selection: Set<UUID> = [drafts[2].id, drafts[3].id]   // 비밀번호 + OTP

        let result = BulkImportView.merging(drafts, selection: selection).drafts

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].title, "아이디", "앞의 항목들은 자리를 지킨다")
        XCTAssertEqual(result[1].title, "메모")
        XCTAssertEqual(result[2].values, ["pw", "123456"], "합친 것은 가장 앞선 항목의 자리에 놓인다")
    }

    // MARK: - 보안·넣기 승계

    func testSecureIsInheritedWhenAnySelectedIsSecure() {
        let drafts = sample()
        let selection: Set<UUID> = [drafts[0].id, drafts[2].id]   // 일반 + 보안

        let result = BulkImportView.merging(drafts, selection: selection).drafts

        XCTAssertTrue(result[0].isSecure, "하나라도 보안이면 합친 콤보도 보안이어야 한다")
    }

    func testMergedStaysExcludedOnlyWhenEveryPartWasExcluded() {
        var drafts = sample()
        drafts[0].include = false
        drafts[2].include = false
        let bothExcluded: Set<UUID> = [drafts[0].id, drafts[2].id]

        XCTAssertFalse(BulkImportView.merging(drafts, selection: bothExcluded).drafts[0].include,
                       "둘 다 빼기였으면 합쳐도 빼기다")

        drafts[2].include = true
        XCTAssertTrue(BulkImportView.merging(drafts, selection: bothExcluded).drafts[0].include,
                      "하나라도 넣기였으면 합친 것도 넣기다")
    }

    // MARK: - 아무 일도 하지 않아야 할 때

    func testMergingFewerThanTwoDoesNothing() {
        let drafts = sample()

        let none = BulkImportView.merging(drafts, selection: [])
        XCTAssertEqual(none.drafts.count, drafts.count)
        XCTAssertNil(none.mergedID)

        let one = BulkImportView.merging(drafts, selection: [drafts[1].id])
        XCTAssertEqual(one.drafts.count, drafts.count, "하나만 골라서는 묶을 것이 없다")
        XCTAssertNil(one.mergedID)
    }

    func testMergedIDPointsAtTheSurvivingDraft() {
        let drafts = sample()
        let selection: Set<UUID> = [drafts[0].id, drafts[2].id]

        let result = BulkImportView.merging(drafts, selection: selection)

        XCTAssertEqual(result.mergedID, result.drafts[0].id,
                       "합친 뒤 선택을 이어가려면 살아남은 항목을 가리켜야 한다")
    }

    // MARK: - 이미 콤보인 것을 다시 묶기

    func testMergingACombineWithAnotherFlattensAllSteps() {
        let stack = Draft(title: "로그인", values: ["id", "pw"])
        let extra = Draft(title: "OTP", values: ["123456"])
        let drafts = [stack, extra]

        let result = BulkImportView.merging(drafts, selection: [stack.id, extra.id]).drafts

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].values, ["id", "pw", "123456"], "콤보의 단계가 중첩되지 않고 이어져야 한다")
    }
}

//
//  AttachedTemplateTests.swift
//  ClipKeyboardTests
//
//  v4.0.8: 메모 + 옵션 템플릿 결합 + 숫자 토큰 자동 감지 동작 검증.
//

import XCTest
@testable import ClipKeyboard

final class AttachedTemplateTests: XCTestCase {

    // MARK: - Numeric token detection

    func testIsNumericToken_KoreanKeywords() {
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{금액}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{수량}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{가격}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{개수}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{번호}"))
    }

    func testIsNumericToken_EnglishKeywords() {
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{amount}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{Price}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{TotalCount}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{quantity}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{qty}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{number}"))
    }

    func testIsNumericToken_NonNumeric() {
        XCTAssertFalse(TemplateVariableProcessor.isNumericToken("{이름}"))
        XCTAssertFalse(TemplateVariableProcessor.isNumericToken("{name}"))
        XCTAssertFalse(TemplateVariableProcessor.isNumericToken("{주소}"))
        XCTAssertFalse(TemplateVariableProcessor.isNumericToken("{client}"))
    }

    func testIsNumericToken_PartialMatch() {
        // 토큰명 어딘가에 키워드가 있으면 매칭
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{입금금액}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{order_amount}"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("{customer_count}"))
    }

    func testIsNumericToken_StripsBraces() {
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("금액"))
        XCTAssertTrue(TemplateVariableProcessor.isNumericToken("amount"))
    }

    // MARK: - Custom token extraction

    func testExtractCustomTokens_BasicExtraction() {
        let text = "안녕하세요 {이름}님, {금액}원을 입금했습니다."
        let tokens = TemplateVariableProcessor.extractCustomTokens(in: text)
        XCTAssertEqual(tokens, ["{이름}", "{금액}"])
    }

    func testExtractCustomTokens_DeduplicatesPreservingOrder() {
        let text = "{이름}님 {금액}원, {이름}님께 송금"
        let tokens = TemplateVariableProcessor.extractCustomTokens(in: text)
        XCTAssertEqual(tokens, ["{이름}", "{금액}"])
    }

    func testExtractCustomTokens_ExcludesAutoVariables() {
        let text = "오늘은 {날짜}, {이름}님께 {금액}원 입금"
        let tokens = TemplateVariableProcessor.extractCustomTokens(in: text)
        XCTAssertEqual(tokens, ["{이름}", "{금액}"])
        XCTAssertFalse(tokens.contains("{날짜}"))
    }

    func testExtractCustomTokens_NoTokens_ReturnsEmpty() {
        let text = "토큰이 없는 평범한 텍스트입니다"
        XCTAssertTrue(TemplateVariableProcessor.extractCustomTokens(in: text).isEmpty)
    }

    // MARK: - Substitute

    func testSubstitute_ReplacesTokens() {
        let text = "안녕하세요 {이름}님, {금액}원 송금합니다."
        let result = TemplateVariableProcessor.substitute(text, with: ["{이름}": "홍길동", "{금액}": "50000"])
        XCTAssertEqual(result, "안녕하세요 홍길동님, 50000원 송금합니다.")
    }

    func testSubstitute_MissingValueLeavesToken() {
        let text = "{이름}님 {금액}원"
        let result = TemplateVariableProcessor.substitute(text, with: ["{이름}": "홍길동"])
        XCTAssertEqual(result, "홍길동님 {금액}원")
    }

    // MARK: - Compose (option X - 이어 붙이기)

    func testCompose_NoTemplate_ReturnsMemoOnly() {
        let result = TemplateVariableProcessor.compose(
            memoValue: "1234-5678-9012",
            templateBody: nil,
            templateInputs: [:]
        )
        XCTAssertEqual(result, "1234-5678-9012")
    }

    func testCompose_EmptyTemplate_ReturnsMemoOnly() {
        let result = TemplateVariableProcessor.compose(
            memoValue: "1234-5678-9012",
            templateBody: "",
            templateInputs: [:]
        )
        XCTAssertEqual(result, "1234-5678-9012")
    }

    func testCompose_WithTemplate_JoinsWithNewline() {
        let result = TemplateVariableProcessor.compose(
            memoValue: "1234-5678-9012",
            templateBody: "이 계좌로 {금액}원 보내주세요",
            templateInputs: ["{금액}": "50000"]
        )
        XCTAssertEqual(result, "1234-5678-9012\n이 계좌로 50000원 보내주세요")
    }

    func testCompose_EmptyMemoValue_OnlyTemplate() {
        let result = TemplateVariableProcessor.compose(
            memoValue: "",
            templateBody: "이 계좌로 {금액}원 보내주세요",
            templateInputs: ["{금액}": "50000"]
        )
        XCTAssertEqual(result, "이 계좌로 50000원 보내주세요")
    }

    // MARK: - Memo model (콤보 신 모델)

    func testMemo_ChildMemoIds_DefaultsToEmpty() {
        let memo = Memo(title: "테스트", value: "값")
        XCTAssertTrue(memo.childMemoIds.isEmpty)
        XCTAssertFalse(memo.isStack)
    }

    func testMemo_Stack_PersistsViaCodable() throws {
        // 통합 모델: 콤보 판정은 stackValues 기반(childMemoIds 아님).
        var memo = Memo(title: "콤보", value: "1단계", stackValues: ["1단계", "2단계"])
        memo.stackInterval = 3.0

        let decoded = try JSONDecoder().decode(Memo.self, from: JSONEncoder().encode(memo))
        XCTAssertEqual(decoded.stackValues, ["1단계", "2단계"])
        XCTAssertEqual(decoded.stackInterval, 3.0)
        XCTAssertTrue(decoded.isStack)
    }

    func testMemo_LegacyJSONWithRemovedKeys_DecodesAndIgnores() throws {
        // 구버전 JSON(isStack/stackValues/attachedTemplateId 키 포함)도 신 모델로 디코딩되며
        // 해당 키들은 무시되고 childMemoIds는 기본 빈 배열.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","title":"기존","value":"값","isChecked":false,"lastEdited":"2026-05-06T00:00:00Z","isFavorite":false,"clipCount":0,"category":"기본","isSecure":false,"isTemplate":false,"templateVariables":[],"placeholderValues":{},"isCombo":false,"comboValues":[],"currentComboIndex":0,"attachedTemplateId":"\(UUID().uuidString)","imageFileNames":[],"contentType":"text"}
        """.data(using: .utf8)!

        let formatter = ISO8601DateFormatter()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            return formatter.date(from: str) ?? Date()
        }

        let memo = try decoder.decode(Memo.self, from: legacyJSON)
        XCTAssertTrue(memo.childMemoIds.isEmpty)
        XCTAssertFalse(memo.isStack)
    }
}

//
//  MemoModelSwiftTests.swift
//  ClipKeyboardTests
//
//  Swift Testing 스위트 - Memo 모델의 계산형 성질(isTemplate/isStack),
//  Codable 라운드트립, 그리고 리팩터로 제거된 키(attachedTemplateId/
//  currentComboIndex/저장형 isTemplate)에 대한 하위 호환 디코딩을 검증한다.
//
//  명세: docs/product/FEATURE_SPEC.md §1
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("Memo 모델, 계산형 성질 & 마이그레이션")
struct MemoModelSwiftTests {

    // MARK: - 기본값 / 계산형 판정

    @Test("기본 메모는 템플릿도 콤보도 아니다")
    func plainMemoIsNeitherTemplateNorStack() {
        let memo = Memo(title: "제목", value: "그냥 텍스트")
        #expect(memo.isTemplate == false)
        #expect(memo.isStack == false)
        #expect(memo.category == "기본")
        #expect(memo.contentType == .text)
    }

    @Test("변수가 있으면 템플릿으로 판정된다")
    func memoWithVariablesIsTemplate() {
        let memo = Memo(title: "인사", value: "안녕하세요 {이름}님",
                        templateVariables: ["{이름}"])
        #expect(memo.isTemplate == true)
        #expect(memo.isStack == false)
    }

    @Test("comboValues가 있으면 콤보로 판정된다")
    func memoWithStackValuesIsStack() {
        let memo = Memo(title: "콤보", value: "1단계",
                        stackValues: ["1단계", "2단계", "3단계"])
        #expect(memo.isStack == true)
        #expect(memo.stackValues.count == 3)
    }

    @Test("변수와 단계를 모두 가지면 템플릿이면서 콤보다")
    func memoCanBeBothTemplateAndStack() {
        let memo = Memo(title: "둘다", value: "{이름}님 안녕",
                        templateVariables: ["{이름}"],
                        stackValues: ["{이름}님 안녕", "또 만나요"])
        #expect(memo.isTemplate == true)
        #expect(memo.isStack == true)
    }

    // MARK: - Codable 라운드트립

    @Test("Codable 인코딩→디코딩 후 핵심 필드가 보존된다")
    func codableRoundTripPreservesFields() throws {
        var original = Memo(title: "인코딩", value: "값 {금액}",
                            isFavorite: true, category: "업무",
                            templateVariables: ["{금액}"],
                            stackInterval: 1.5)
        original.placeholderValues["{금액}"] = ["1000", "2000"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Memo.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.value == original.value)
        #expect(decoded.isFavorite == original.isFavorite)
        #expect(decoded.category == original.category)
        #expect(decoded.templateVariables == original.templateVariables)
        #expect(decoded.isTemplate == true)
        #expect(decoded.placeholderValues["{금액}"] == ["1000", "2000"])
        #expect(decoded.stackInterval == 1.5)
    }

    @Test("힌트·키보드 동기화 토글 Codable 라운드트립 + 구버전 기본값 ON")
    func hintAndKeyboardSyncRoundTrip() throws {
        var original = Memo(title: "힌트", value: "값",
                            hint: "회사 소개 첫 줄", hintShownOnKeyboard: false)
        let decoded = try JSONDecoder().decode(Memo.self, from: JSONEncoder().encode(original))
        #expect(decoded.hint == "회사 소개 첫 줄")
        #expect(decoded.hintShownOnKeyboard == false)

        // 구버전 데이터(hintShownOnKeyboard 키 없음)는 기본 ON으로 읽힌다.
        original.hintShownOnKeyboard = true
        var json = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "hintShownOnKeyboard")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let legacy = try JSONDecoder().decode(Memo.self, from: legacyData)
        #expect(legacy.hintShownOnKeyboard == true)
    }

    @Test("콤보 메모 Codable 라운드트립: stackValues 보존")
    func stackCodableRoundTrip() throws {
        let original = Memo(title: "콤보", value: "A",
                            stackValues: ["A", "B", "C"], stackInterval: 0.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Memo.self, from: data)
        #expect(decoded.stackValues == ["A", "B", "C"])
        #expect(decoded.isStack == true)
        #expect(decoded.stackInterval == 0.5)
    }

    // MARK: - 하위 호환 디코딩 (제거된 키 무시)

    @Test("구버전 JSON의 제거된 키는 무시되고 계산형이 우선한다")
    func legacyRemovedKeysAreIgnored() throws {
        // 실제 Memo를 인코딩한 뒤 제거된 레거시 키를 주입해 디코딩 가능성을 보장한다.
        let base = Memo(title: "레거시", value: "변수 없음")  // templateVariables 비어 있음
        let data = try JSONEncoder().encode(base)
        var dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        // 구버전에 존재하던, 이제는 제거된 키들을 주입.
        dict["attachedTemplateId"] = UUID().uuidString
        dict["currentComboIndex"] = 3
        dict["isTemplate"] = true   // 저장형 isTemplate(true) - 계산형이 무시해야 함

        let legacyData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(Memo.self, from: legacyData)

        // 저장형 isTemplate=true 였지만 templateVariables가 비었으므로 계산형은 false.
        #expect(decoded.isTemplate == false)
        #expect(decoded.isStack == false)
        #expect(decoded.title == "레거시")
        #expect(decoded.value == "변수 없음")
    }

    @Test("childMemoIds가 있어도 comboValues가 없으면 콤보가 아니다")
    func childMemoIdsAloneDoesNotMakeStack() throws {
        let base = Memo(title: "legacy child", value: "x")
        let data = try JSONEncoder().encode(base)
        var dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        dict["childMemoIds"] = [UUID().uuidString, UUID().uuidString]
        let legacyData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(Memo.self, from: legacyData)
        // 콤보 판정은 stackValues 기반 - childMemoIds만으론 콤보가 아님.
        #expect(decoded.isStack == false)
    }

    @Test("구버전 memos.data(신규 키 누락)도 디코딩 실패 없이 안전하게 읽힌다")
    func legacyJSONMissingNewKeysDecodesSafely() throws {
        // ⚠️ 회귀 가드: childMemoIds/stackValues/stackInterval 등은 비교적 최근 추가됐다.
        // 이 키들이 없는 구버전 JSON이 keyNotFound로 디코딩 실패하면 [Memo] 배열 전체가
        // 무너져 카테고리·즐겨찾기 등이 사라진다. 관용 디코더가 이를 막아야 한다.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","title":"옛 메모","value":"중요한 값",
         "isChecked":false,"isFavorite":true,"category":"업무","isSecure":false}
        """.data(using: .utf8)!

        let memo = try JSONDecoder().decode(Memo.self, from: legacyJSON)
        #expect(memo.title == "옛 메모")
        #expect(memo.value == "중요한 값")
        #expect(memo.isFavorite == true)
        #expect(memo.category == "업무")          // 카테고리 보존
        #expect(memo.childMemoIds.isEmpty)         // 누락 → 기본값
        #expect(memo.stackValues.isEmpty)
        #expect(memo.stackInterval == 2.0)          // 누락 → 기본값
        #expect(memo.contentType == .text)
        #expect(memo.isStack == false)
        #expect(memo.isTemplate == false)
    }

    @Test("구버전 데이터 배열도 한 항목씩 모두 안전하게 디코딩된다")
    func legacyArrayDecodesAllItems() throws {
        let json = """
        [
         {"id":"\(UUID().uuidString)","title":"A","value":"1","category":"개인"},
         {"id":"\(UUID().uuidString)","title":"B","value":"2","category":"금융","isFavorite":true}
        ]
        """.data(using: .utf8)!
        let memos = try JSONDecoder().decode([Memo].self, from: json)
        #expect(memos.count == 2)
        #expect(memos[0].category == "개인")
        #expect(memos[1].isFavorite == true)
    }

    // MARK: - OldMemo 변환

    @Test("OldMemo → Memo 변환 시 title/value가 보존된다")
    func oldMemoConversion() {
        let old = OldMemo(title: "옛 제목", value: "옛 값")
        let memo = Memo(from: old)
        #expect(memo.title == "옛 제목")
        #expect(memo.value == "옛 값")
        #expect(memo.isTemplate == false)
        #expect(memo.isStack == false)
    }

    // MARK: - PlaceholderValue

    @Test("PlaceholderValue Codable 라운드트립")
    func placeholderValueCodable() throws {
        let sourceId = UUID()
        let pv = PlaceholderValue(value: "홍길동", sourceMemoId: sourceId,
                                  sourceMemoTitle: "주소록")
        let data = try JSONEncoder().encode(pv)
        let decoded = try JSONDecoder().decode(PlaceholderValue.self, from: data)
        #expect(decoded.value == "홍길동")
        #expect(decoded.sourceMemoId == sourceId)
        #expect(decoded.sourceMemoTitle == "주소록")
    }
}

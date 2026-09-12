//
//  MigrationCompatibilityTests.swift
//  ClipKeyboardTests
//
//  구버전이 저장한 데이터를 신버전이 손실 없이 읽는지 고정한다.
//
//  왜 필요한가: 마이그레이션 코드는 6곳(MemoStore·CategoryStore·ProStatusManager·
//  SmartClipboard 등)에 있는데 전용 테스트가 없었다. 이 경로는 **개발 중에는 절대
//  안 밟히고**(항상 최신 포맷으로 저장하니까) 실사용자 업데이트에서만 밟힌다.
//  즉 깨져도 릴리즈 전에는 아무도 모른다 - 데이터 유실이 여기서 나온다.
//
//  픽스처는 실제 저장 포맷인 **JSON 문자열 리터럴**로 둔다. 모델 코드로 만들면
//  모델이 바뀔 때 픽스처도 같이 바뀌어 "구버전 데이터"를 검증하지 못한다.
//

import XCTest
@testable import ClipKeyboard

final class MigrationCompatibilityTests: XCTestCase {

    private func decodeMemos(_ json: String, file: StaticString = #filePath, line: UInt = #line) throws -> [Memo] {
        let data = try XCTUnwrap(json.data(using: .utf8), file: file, line: line)
        return try JSONDecoder().decode([Memo].self, from: data)
    }

    // MARK: - Memo - 구버전 JSON 호환

    /// 가장 오래된 형식(OldMemo: title/value/isChecked만). 앱 1.x 시절 저장분.
    func testDecodesOldestMemoFormat() throws {
        let json = """
        [{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","title":"계좌","value":"우리 1002-123","isChecked":false}]
        """
        let memos = try decodeMemos(json)

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].title, "계좌")
        XCTAssertEqual(memos[0].value, "우리 1002-123")
        // 없던 필드는 기본값으로 채워져야 한다 - nil/크래시가 아니라.
        XCTAssertEqual(memos[0].category, "기본")
        XCTAssertFalse(memos[0].isFavorite)
        XCTAssertFalse(memos[0].isTemplate)   // templateVariables 가 비었으므로 false
        XCTAssertEqual(memos[0].clipCount, 0)
        XCTAssertEqual(memos[0].childMemoIds, [])
        XCTAssertEqual(memos[0].stackValues, [])
        XCTAssertEqual(memos[0].imageFileNames, [])
        XCTAssertEqual(memos[0].contentType, .text)
        XCTAssertTrue(memos[0].hintShownOnKeyboard)   // 없던 필드의 기본값은 true
    }

    /// id가 아예 없던 저장분 - 새 UUID를 부여하고 살려야 한다(통째로 버리면 안 됨).
    func testDecodesMemoWithoutID() throws {
        let memos = try decodeMemos(#"[{"title":"인사","value":"안녕하세요"}]"#)

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].title, "인사")
    }

    /// 콤보 필드(childMemoIds/stackInterval)가 없던 버전.
    /// stackInterval 기본값 2.0이 유지돼야 콤보 실행이 0초 간격으로 폭주하지 않는다.
    func testDecodesMemoWithoutStackFields() throws {
        let memos = try decodeMemos(#"[{"title":"a","value":"b","isTemplate":false}]"#)

        XCTAssertEqual(memos[0].stackInterval, 2.0)
        XCTAssertTrue(memos[0].childMemoIds.isEmpty)
    }

    /// ⚠️ 회귀 방지 핵심: 배열 안에 구버전 항목이 섞여 있어도
    /// **전체가 무너지지 않아야** 한다. 합성 Codable이었다면 keyNotFound로
    /// [Memo] 디코딩 전체가 실패해 메모가 통째로 사라진다.
    func testOneLegacyItemDoesNotBreakWholeArray() throws {
        let json = """
        [
          {"title":"구버전","value":"v1"},
          {"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3302","title":"신버전","value":"v2",
           "category":"업무","isFavorite":true,"clipCount":7,"contentType":"text"}
        ]
        """
        let memos = try decodeMemos(json)

        XCTAssertEqual(memos.count, 2, "구버전 항목 하나 때문에 배열 전체가 사라지면 안 된다")
        XCTAssertEqual(memos[0].category, "기본")
        XCTAssertEqual(memos[1].category, "업무")
        XCTAssertEqual(memos[1].clipCount, 7)
    }

    /// 미래 버전이 추가한 모르는 키가 있어도 디코딩은 성공해야 한다(전방 호환).
    /// 사용자가 신버전 → 구버전으로 다운그레이드했을 때의 상황.
    func testUnknownFutureKeysAreIgnored() throws {
        let json = """
        [{"title":"a","value":"b","someFutureField":123,"anotherNew":{"x":1}}]
        """
        let memos = try decodeMemos(json)

        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].title, "a")
    }

    /// 카테고리 유실 시나리오: category 키가 통째로 빠진 데이터.
    /// 사이드카 복원의 전제 조건이라 기본값이 "기본"으로 고정돼야 한다.
    func testMissingCategoryFallsBackToDefault() throws {
        let memos = try decodeMemos(#"[{"title":"a","value":"b"}]"#)

        XCTAssertEqual(memos[0].category, "기본")
    }

    // MARK: - 라운드트립

    /// 지금 포맷으로 저장 → 다시 읽기가 손실 없이 되는지.
    /// 위 호환 테스트들이 통과해도 이게 깨지면 저장 자체가 망가진 것이다.
    func testCurrentFormatRoundTrips() throws {
        // ⚠️ isTemplate 은 저장 프로퍼티가 아니라 `!templateVariables.isEmpty` 계산값이다.
        //    init 인자로 넘길 수 없고, 변수를 주면 자동으로 템플릿이 된다.
        var original = Memo(
            title: "제목", value: "내용",
            isFavorite: true,
            category: "업무",
            templateVariables: ["금액"]
        )
        original.clipCount = 3   // init 파라미터에 없어 생성 후 대입한다

        let data = try JSONEncoder().encode([original])
        let restored = try JSONDecoder().decode([Memo].self, from: data)

        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].id, original.id)
        XCTAssertEqual(restored[0].title, original.title)
        XCTAssertEqual(restored[0].value, original.value)
        XCTAssertEqual(restored[0].category, original.category)
        XCTAssertTrue(restored[0].isFavorite)
        XCTAssertEqual(restored[0].templateVariables, ["금액"])
        XCTAssertTrue(restored[0].isTemplate, "templateVariables 가 살아있으면 isTemplate 도 따라온다")
        XCTAssertEqual(restored[0].clipCount, 3)
    }

    // MARK: - 레거시 클립보드 → 스마트 클립보드

    /// 구버전 clipboard.history.data 형식이 그대로 디코딩되는지.
    /// MemoStore.migrateFromLegacyClipboard()가 이 디코딩에 의존한다.
    func testDecodesLegacyClipboardHistory() throws {
        let json = """
        [{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3303","content":"test@example.com",
          "copiedAt":752000000,"isTemporary":true}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let items = try JSONDecoder().decode([ClipboardHistory].self, from: data)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].content, "test@example.com")
        XCTAssertTrue(items[0].isTemporary)
    }

    /// 마이그레이션은 내용을 분류해 detectedType을 채운다.
    /// 분류기가 바뀌어 이메일을 못 잡게 되면 마이그레이션 결과가 조용히 나빠지므로 고정한다.
    func testLegacyContentGetsClassifiedOnMigration() {
        let (type, confidence) = ClipboardClassificationService.shared.classify(content: "test@example.com")

        XCTAssertEqual(type, .email)
        XCTAssertGreaterThan(confidence, 0.5)
    }
}

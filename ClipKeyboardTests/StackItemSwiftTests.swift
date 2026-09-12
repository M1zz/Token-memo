//
//  StackItemSwiftTests.swift
//  ClipKeyboardTests
//
//  **단축어 스택**의 저장 계약을 지킨다.
//
//  이 파일이 지키는 것은 전부 **남의 데이터**다. 여기가 깨지면 크래시가 아니라
//  "쓰던 스택이 사라졌다" 로 나타나고, 그때는 이미 배포된 뒤다.
//
//   ① 옛 콤보(`stackValues`, 값만)는 읽는 순간 칸으로 옮겨진다
//   ② 새로 쓸 때 **옛 키도 함께** 쓴다 (되돌아간 앱·위젯이 그것을 읽는다)
//   ③ 이름 없는 칸은 화면에서만 자리로 불린다 (데이터에는 지어낸 이름을 안 적는다)
//   ④ 가리키는 칸도 마지막으로 본 값을 들고 있다 (원본이 지워져도 안 빈다)
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("단축어 스택, 저장과 하위 호환")
struct StackItemSwiftTests {

    // MARK: - ① 옛 콤보에서 옮겨 오기

    @Test("값만 있던 옛 콤보는 읽는 순간 칸이 된다")
    func legacyStackBecomesStackItems() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","title":"인사","value":"안녕",
          "comboValues":["안녕","반가워","또 봐"]}]
        """.data(using: .utf8)!

        let memos = try JSONDecoder().decode([Memo].self, from: json)
        let memo = try #require(memos.first)

        #expect(memo.isStack)
        #expect(memo.stackItems.count == 3)
        #expect(memo.stackValues == ["안녕", "반가워", "또 봐"])
        #expect(memo.stackItems.allSatisfy { $0.key.isEmpty }, "지어낸 이름을 적어 두지 않는다")
        #expect(memo.stackItems.allSatisfy { $0.reference == nil })
    }

    @Test("새 키가 있으면 그것이 진짜다")
    func newKeyWins() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","title":"로그인","value":"",
          "comboValues":["옛값1","옛값2"],
          "stackItems":[{"id":"\(UUID().uuidString)","key":"아이디","value":"me@example.com"}]}]
        """.data(using: .utf8)!

        let memo = try #require(try JSONDecoder().decode([Memo].self, from: json).first)
        #expect(memo.stackItems.count == 1)
        #expect(memo.stackItems[0].key == "아이디")
        #expect(memo.stackItems[0].value == "me@example.com")
    }

    // MARK: - ② 되돌아간 앱도 읽을 수 있어야 한다

    @Test("쓸 때 옛 키에도 값을 남긴다")
    func encodesLegacyKeyToo() throws {
        var memo = Memo(title: "로그인", value: "")
        memo.stackItems = [StackItem(key: "아이디", value: "me@example.com"),
                           StackItem(key: "비밀번호", value: "hunter2")]

        let data = try JSONEncoder().encode([memo])
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let first = try #require(raw.first)

        let legacy = try #require(first["comboValues"] as? [String])
        #expect(legacy == ["me@example.com", "hunter2"],
                "옛 키를 빼면 되돌아간 앱과 위젯에서 스택이 사라진다")
        #expect(first["stackItems"] != nil)
    }

    @Test("쓰고 다시 읽으면 이름까지 그대로다")
    func roundTripKeepsKeys() throws {
        var memo = Memo(title: "로그인", value: "")
        memo.stackItems = [StackItem(key: "아이디", value: "me@example.com"),
                           StackItem(key: "비밀번호", value: "hunter2")]
        memo.stackInterval = 0.5

        let back = try #require(
            try JSONDecoder().decode([Memo].self, from: JSONEncoder().encode([memo])).first)
        #expect(back.stackItems.map(\.key) == ["아이디", "비밀번호"])
        #expect(back.stackValues == ["me@example.com", "hunter2"])
        #expect(back.stackInterval == 0.5)
    }

    // MARK: - ③ 이름 없는 칸

    @Test("이름을 안 지은 칸은 자리로 불린다")
    func unnamedItemFallsBackToPosition() {
        var memo = Memo(title: "인사", value: "")
        memo.stackItems = [StackItem(value: "안녕"),
                           StackItem(key: "두번째", value: "반가워"),
                           StackItem(key: "   ", value: "또 봐")]

        #expect(memo.displayKey(at: 0).contains("1"))
        #expect(memo.displayKey(at: 1) == "두번째")
        #expect(memo.displayKey(at: 2).contains("3"), "공백뿐인 이름도 없는 것으로 친다")
        #expect(memo.displayKey(at: 9) == "", "없는 자리를 물으면 빈 값이다")
        #expect(memo.stackItems[0].key.isEmpty, "부르는 이름을 데이터에 적어 두지 않는다")
    }

    // MARK: - ④ 가리키는 칸

    @Test("가리키는 칸도 마지막으로 본 값을 들고 있다")
    func referencingItemKeepsItsOwnValue() throws {
        let target = UUID()
        var memo = Memo(title: "출근 보고", value: "")
        memo.stackItems = [StackItem(key: "이름", value: "홍길동", reference: target)]

        let back = try #require(
            try JSONDecoder().decode([Memo].self, from: JSONEncoder().encode([memo])).first)
        #expect(back.stackItems[0].reference == target)
        #expect(back.stackItems[0].value == "홍길동",
                "원본이 지워져도 칸은 제 몫을 해야 한다. 참조 모델을 두 번 접은 이유가 이것이다")
    }

    // MARK: - ⑤ 값만 갈아 끼울 때

    /// 잠글 때 암호화하고 열 때 복호화하는 자리가 값을 통째로 새로 넣는다.
    /// **그때 이름이 날아가면 안 된다.**
    @Test("값만 갈아 끼워도 이름은 자리대로 남는다")
    func setStackValuesKeepsKeys() {
        var memo = Memo(title: "로그인", value: "")
        memo.stackItems = [StackItem(key: "아이디", value: "me@example.com"),
                           StackItem(key: "비밀번호", value: "hunter2")]

        memo.setStackValues(["암호문1", "암호문2"])

        #expect(memo.stackItems.map(\.key) == ["아이디", "비밀번호"])
        #expect(memo.stackValues == ["암호문1", "암호문2"])
    }

    @Test("칸이 늘면 늘어난 자리만 이름 없이 시작한다")
    func setStackValuesGrows() {
        var memo = Memo(title: "로그인", value: "")
        memo.stackItems = [StackItem(key: "아이디", value: "a")]

        memo.setStackValues(["a", "b"])

        #expect(memo.stackItems.count == 2)
        #expect(memo.stackItems[0].key == "아이디")
        #expect(memo.stackItems[1].key.isEmpty)
    }
}

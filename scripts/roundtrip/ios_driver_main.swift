// iOS 측 드라이버 - 실제 ClipKeyboard/Model/Memo.swift와 함께 컴파일된다.
// encode 모드: iCloud 백업과 동일한 포맷(JSONEncoder().encode([Memo]) 등)으로 픽스처 기록
// verify 모드: 맥앱이 재인코딩한 JSON을 iOS 디코더로 읽어 모든 필드 보존을 검증
import Foundation

let fixedDate = Date(timeIntervalSince1970: 1_750_000_000)
let usedDate = Date(timeIntervalSince1970: 1_750_100_000)
let id1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let id2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
let id3 = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
let childA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
let childB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

func makeFixtureMemos() -> [Memo] {
    var m1 = Memo(id: id1, title: "집 주소", value: "서울시 어딘가 123",
                  isChecked: true, lastEdited: fixedDate, isFavorite: true,
                  category: "개인정보", isSecure: true,
                  imageFileName: "img-legacy.png", imageFileNames: ["a.png", "b.png"],
                  contentType: .mixed, lastUsedAt: usedDate,
                  hint: "쿠팡 배송지 입력할 때")
    m1.clipCount = 7
    m1.autoDetectedType = .address
    m1.childMemoIds = [childA, childB]

    var m2 = Memo(id: id2, title: "인사 템플릿", value: "안녕하세요 {이름}님",
                  lastEdited: fixedDate,
                  templateVariables: ["이름"],
                  placeholderValues: ["이름": ["유미", "주디", "리이오"]],
                  hint: "신규 고객 응대 메일")
    var m3 = Memo(id: id3, title: "로그인 콤보", value: "",
                  lastEdited: fixedDate,
                  stackValues: ["myid@example.com", "password123"],
                  stackInterval: 3.5)
    _ = m2; _ = m3
    return [m1, m2, m3]
}

func makeFixtureStacks() -> [Combo] {
    let item = ComboItem(id: childA, type: .memo, referenceId: id1, order: 0,
                         displayTitle: "집 주소", displayValue: "서울시 어딘가 123")
    return [Combo(id: childB, title: "주문 콤보", items: [item], interval: 1.5,
                  createdAt: fixedDate, lastUsed: usedDate, category: "텍스트",
                  useCount: 4, isFavorite: true)]
}

func makeFixtureClipboard() -> [SmartClipboardHistory] {
    var c = SmartClipboardHistory(id: id1, content: "leeo@kakao.com", copiedAt: fixedDate,
                                  isTemporary: false, contentType: .text,
                                  detectedType: .email, confidence: 0.95)
    c.userCorrectedType = .email
    c.tags = ["업무"]
    c.sourceApp = "Mail"
    return [c]
}

func fail(_ msg: String) -> Never {
    print("❌ VERIFY FAIL: \(msg)")
    exit(1)
}

func check(_ cond: Bool, _ msg: String) {
    if !cond { fail(msg) }
}

let args = CommandLine.arguments
let mode = args[1]
let dir = args[2]

switch mode {
case "encode":
    let enc = JSONEncoder()
    try enc.encode(makeFixtureMemos()).write(to: URL(fileURLWithPath: dir + "/memos.json"))
    try enc.encode(makeFixtureStacks()).write(to: URL(fileURLWithPath: dir + "/combos.json"))
    try enc.encode(makeFixtureClipboard()).write(to: URL(fileURLWithPath: dir + "/clipboard.json"))
    print("✅ iOS encode 완료 (memos/combos/clipboard)")

case "verify":
    let dec = JSONDecoder()
    let memos = try dec.decode([Memo].self, from: Data(contentsOf: URL(fileURLWithPath: dir + "/memos.json")))
    check(memos.count == 3, "메모 개수 \(memos.count) != 3")
    let m1 = memos[0], m2 = memos[1], m3 = memos[2]
    check(m1.id == id1 && m1.title == "집 주소" && m1.value == "서울시 어딘가 123", "m1 기본 필드 불일치")
    check(m1.hint == "쿠팡 배송지 입력할 때", "m1.hint 손실! got=\(String(describing: m1.hint))")
    check(m1.isSecure && m1.isFavorite && m1.isChecked, "m1 불리언 필드 손실")
    check(m1.clipCount == 7, "m1.clipCount 손실")
    check(m1.category == "개인정보", "m1.category 손실")
    check(m1.lastUsedAt == usedDate, "m1.lastUsedAt 손실")
    check(m1.lastEdited == fixedDate, "m1.lastEdited 손실")
    check(m1.autoDetectedType == .address, "m1.autoDetectedType 손실")
    check(m1.imageFileName == "img-legacy.png" && m1.imageFileNames == ["a.png", "b.png"], "m1 이미지 필드 손실")
    check(m1.contentType == .mixed, "m1.contentType 손실")
    check(m1.childMemoIds == [childA, childB], "m1.childMemoIds 손실")
    check(m2.templateVariables == ["이름"], "m2.templateVariables 손실")
    check(m2.isTemplate, "m2.isTemplate 계산값 불일치")
    check(m2.placeholderValues["이름"] == ["유미", "주디", "리이오"], "m2.placeholderValues 손실")
    check(m2.hint == "신규 고객 응대 메일", "m2.hint 손실")
    check(m3.stackValues == ["myid@example.com", "password123"], "m3.stackValues 손실")
    check(m3.stackInterval == 3.5, "m3.stackInterval 손실")
    check(m3.isStack, "m3.isStack 계산값 불일치")
    check(m3.hint == nil, "m3.hint nil이어야 함")

    let combos = try dec.decode([Combo].self, from: Data(contentsOf: URL(fileURLWithPath: dir + "/combos.json")))
    check(combos.count == 1 && combos[0].title == "주문 콤보" && combos[0].interval == 1.5
          && combos[0].useCount == 4 && combos[0].isFavorite
          && combos[0].items.first?.referenceId == id1, "Combo round-trip 손실")

    let clips = try dec.decode([SmartClipboardHistory].self, from: Data(contentsOf: URL(fileURLWithPath: dir + "/clipboard.json")))
    check(clips.count == 1 && clips[0].content == "leeo@kakao.com"
          && clips[0].detectedType == .email && clips[0].confidence == 0.95
          && clips[0].userCorrectedType == .email && clips[0].tags == ["업무"]
          && clips[0].sourceApp == "Mail" && clips[0].isTemporary == false, "SmartClipboardHistory round-trip 손실")

    // 구버전(4.3.0 이하) 합성 디코더가 필수로 요구하는 레거시 키가 JSON에 있는지 확인
    let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: dir + "/memos.json"))) as! [[String: Any]]
    for (i, obj) in raw.enumerated() {
        for key in ["isTemplate", "isCombo", "currentComboIndex"] {
            check(obj[key] != nil, "memo[\(i)]에 레거시 키 '\(key)' 없음. 구버전 다운그레이드 시 데이터 전멸")
        }
    }
    print("✅ iOS verify 통과: 메모 3건 전 필드 + Combo + SmartClipboard + 레거시 키 보존 확인")

case "verify-old":
    // OldMemo(1.x) 포맷 폴백 검증용 픽스처 생성
    let old = "[{\"id\":\"\(id1.uuidString)\",\"title\":\"옛날 메모\",\"value\":\"old value\",\"isChecked\":true}]"
    try old.data(using: .utf8)!.write(to: URL(fileURLWithPath: dir + "/old_memos.json"))
    print("✅ OldMemo 픽스처 생성")

default:
    fail("unknown mode \(mode)")
}

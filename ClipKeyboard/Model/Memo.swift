//
//  Memo.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/15.
//

import Foundation

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

// MARK: - Clipboard Item Type (자동 분류)
enum ClipboardItemType: String, Codable, CaseIterable {
    case email = "이메일"
    case phone = "전화번호"
    case address = "주소"
    case url = "URL"
    case creditCard = "카드번호"
    case bankAccount = "계좌번호"
    case passportNumber = "여권번호"
    case declarationNumber = "통관번호"
    case postalCode = "우편번호"
    case name = "이름"
    case birthDate = "생년월일"
    case taxID = "세금번호"
    case insuranceNumber = "보험번호"
    case vehiclePlate = "차량번호"
    case ipAddress = "IP주소"
    case membershipNumber = "회원번호"
    case trackingNumber = "송장번호"
    case confirmationCode = "예약번호"
    case medicalRecord = "진료기록번호"
    case employeeID = "사번/학번"
    case image = "이미지"
    case text = "텍스트"
    // v4.0 글로벌 피봇 추가 - 영어 rawValue (신규 국제 결제/세무/크립토 식별자)
    case iban = "IBAN"
    case swift = "SWIFT/BIC"
    case vat = "VAT Number"
    case cryptoWallet = "Crypto Wallet"
    case paypalLink = "PayPal Link"

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .address: return "location.fill"
        case .url: return "link"
        case .creditCard: return "creditcard.fill"
        case .bankAccount: return "banknote.fill"
        case .passportNumber: return "person.text.rectangle.fill"
        case .declarationNumber: return "doc.text.fill"
        case .postalCode: return "mappin.circle.fill"
        case .name: return "person.fill"
        case .birthDate: return "calendar"
        case .taxID: return "number.circle.fill"
        case .insuranceNumber: return "cross.case.fill"
        case .vehiclePlate: return "car.fill"
        case .ipAddress: return "network"
        case .membershipNumber: return "star.circle.fill"
        case .trackingNumber: return "shippingbox.fill"
        case .confirmationCode: return "checkmark.seal.fill"
        case .medicalRecord: return "stethoscope"
        case .employeeID: return "person.badge.key.fill"
        case .image: return "photo.fill"
        case .text: return "doc.text"
        case .iban: return "building.columns.fill"
        case .swift: return "globe"
        case .vat: return "doc.badge.gearshape"
        case .cryptoWallet: return "bitcoinsign.circle.fill"
        case .paypalLink: return "dollarsign.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .email: return "blue"
        case .phone: return "green"
        case .address: return "purple"
        case .url: return "orange"
        case .creditCard: return "red"
        case .bankAccount: return "indigo"
        case .passportNumber: return "brown"
        case .declarationNumber: return "cyan"
        case .postalCode: return "teal"
        case .name: return "pink"
        case .birthDate: return "mint"
        case .taxID: return "yellow"
        case .insuranceNumber: return "teal"
        case .vehiclePlate: return "green"
        case .ipAddress: return "purple"
        case .membershipNumber: return "orange"
        case .trackingNumber: return "brown"
        case .confirmationCode: return "indigo"
        case .medicalRecord: return "red"
        case .employeeID: return "cyan"
        case .image: return "pink"
        case .text: return "gray"
        case .iban: return "blue"
        case .swift: return "indigo"
        case .vat: return "orange"
        case .cryptoWallet: return "yellow"
        case .paypalLink: return "blue"
        }
    }

    // 다국어 지원 표시명
    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Clipboard item type")
    }

    // Xcode String Catalog이 문자열을 감지하도록 하는 헬퍼 함수
    static func preloadLocalizedStrings() {
        _ = NSLocalizedString("이메일", comment: "Email")
        _ = NSLocalizedString("전화번호", comment: "Phone Number")
        _ = NSLocalizedString("주소", comment: "Address")
        _ = NSLocalizedString("URL", comment: "URL")
        _ = NSLocalizedString("카드번호", comment: "Card Number")
        _ = NSLocalizedString("계좌번호", comment: "Account Number")
        _ = NSLocalizedString("여권번호", comment: "Passport Number")
        _ = NSLocalizedString("통관번호", comment: "Declaration Number")
        _ = NSLocalizedString("우편번호", comment: "Postal Code")
        _ = NSLocalizedString("이름", comment: "Name")
        _ = NSLocalizedString("생년월일", comment: "Date of Birth")
        _ = NSLocalizedString("세금번호", comment: "Tax ID")
        _ = NSLocalizedString("보험번호", comment: "Insurance Number")
        _ = NSLocalizedString("차량번호", comment: "Vehicle Plate")
        _ = NSLocalizedString("IP주소", comment: "IP Address")
        _ = NSLocalizedString("회원번호", comment: "Membership Number")
        _ = NSLocalizedString("송장번호", comment: "Tracking Number")
        _ = NSLocalizedString("예약번호", comment: "Confirmation Code")
        _ = NSLocalizedString("진료기록번호", comment: "Medical Record Number")
        _ = NSLocalizedString("사번/학번", comment: "Employee/Student ID")
        _ = NSLocalizedString("이미지", comment: "Image")
        _ = NSLocalizedString("텍스트", comment: "Text")
        // v4.0 글로벌 피봇
        _ = NSLocalizedString("IBAN", comment: "IBAN (International Bank Account Number)")
        _ = NSLocalizedString("SWIFT/BIC", comment: "SWIFT/BIC bank code")
        _ = NSLocalizedString("VAT Number", comment: "VAT identification number")
        _ = NSLocalizedString("Crypto Wallet", comment: "Cryptocurrency wallet address")
        _ = NSLocalizedString("PayPal Link", comment: "PayPal.me link")
    }
}

// MARK: - Clipboard Content Type
enum ClipboardContentType: String, Codable {
    case text = "text"
    case image = "image"
    case emoji = "emoji"
    case mixed = "mixed" // 텍스트 + 이미지
}

// MARK: - Smart Clipboard History (자동 분류 클립보드)
struct SmartClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true

    // 콘텐츠 타입
    var contentType: ClipboardContentType = .text

    // 이미지 데이터 (Base64 인코딩)
    var imageData: String?

    // 이미지 메타데이터
    var imageWidth: Int?
    var imageHeight: Int?
    var imageFormat: String?  // "png", "jpeg", "gif"

    // 자동 분류
    var detectedType: ClipboardItemType = .text
    var confidence: Double = 0.0  // 0.0 ~ 1.0 (인식 신뢰도)

    // 메타데이터
    var sourceApp: String?  // 복사한 앱
    var tags: [String] = []
    var autoSaveOffered: Bool = false  // 자동 저장 제안 했는지

    // 사용자 피드백
    var userCorrectedType: ClipboardItemType?  // 사용자가 수정한 타입

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true, contentType: ClipboardContentType = .text, imageData: String? = nil, detectedType: ClipboardItemType = .text, confidence: Double = 0.0) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
        self.contentType = contentType
        self.imageData = imageData
        self.detectedType = detectedType
        self.confidence = confidence
    }
}

// Clipboard History Model (Legacy - 하위 호환성)
struct ClipboardHistory: Identifiable, Codable {
    var id = UUID()
    var content: String
    var copiedAt: Date = Date()
    var isTemporary: Bool = true // 자동으로 7일 후 삭제

    init(id: UUID = UUID(), content: String, copiedAt: Date = Date(), isTemporary: Bool = true) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isTemporary = isTemporary
    }
}

struct OldMemo: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    var isChecked: Bool = false
}

// 플레이스홀더 값 모델 - 어느 템플릿에서 추가되었는지 추적
struct PlaceholderValue: Identifiable, Codable {
    var id = UUID()
    var value: String
    var sourceMemoId: UUID  // 이 값을 추가한 메모의 ID
    var sourceMemoTitle: String  // 이 값을 추가한 메모의 제목
    var addedAt: Date = Date()

    init(id: UUID = UUID(), value: String, sourceMemoId: UUID, sourceMemoTitle: String, addedAt: Date = Date()) {
        self.id = id
        self.value = value
        self.sourceMemoId = sourceMemoId
        self.sourceMemoTitle = sourceMemoTitle
        self.addedAt = addedAt
    }
}


// MARK: - 스택의 한 칸

/// **단축어 스택**의 한 칸. 이름(`key`)과 넣을 글(`value`)을 함께 갖는다.
///
/// 왜 이름이 필요한가: 예전 콤보는 값만 줄지어 들고 있었다(`[String]`). 키보드에서 → 를
/// 누르면 값이 잠깐 스쳐 지나갈 뿐이라, **지금 몇 번째 무엇인지** 알 길이 없었다.
/// 튜토리얼이 "서로 다른 값 두 개가 들어갔죠?" 를 굳이 짚어 주던 이유가 그것이다.
/// 칸마다 이름이 있으면 키보드가 그 이름을 그대로 보여 줄 수 있다.
///
/// ## 남의 단축어를 가리킬 수도 있다
///
/// `reference` 가 있으면 그 단축어를 가리키는 칸이고, 없으면 스택이 자기 것으로 갖는 칸이다.
///
/// ⚠️ **가리키는 칸도 `value` 를 함께 적어 둔다.** 이 저장소는 참조로 묶는 설계를 두 번
///    만들었다가 두 번 다 인라인 값으로 접었다(`combos.data` 의 `referenceId`,
///    그리고 미출시 `childMemoIds`). 가리키던 단축어가 지워지면 칸이 통째로 비어
///    **스택이 조용히 망가지는** 것이 그 이유였다. 마지막으로 본 값을 함께 들고 있으면
///    원본이 사라져도 칸은 제 몫을 한다. 원본이 살아 있으면 그쪽이 이긴다.
struct StackItem: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    /// 이 칸의 이름. 비어 있으면 화면이 "1단계"처럼 자리로 부른다
    /// (`Memo.displayKey(at:)`). **빈 값을 채워 저장하지 않는다** - 지어낸 이름을
    /// 데이터에 굳히면 나중에 언어를 바꿔도 그 말이 따라오지 않는다.
    var key: String
    /// 이 칸이 넣는 글.
    var value: String
    /// 가리키는 단축어. nil 이면 스택이 자기 것으로 갖는 칸이다.
    var reference: UUID?

    init(id: UUID = UUID(), key: String = "", value: String, reference: UUID? = nil) {
        self.id = id
        self.key = key
        self.value = value
        self.reference = reference
    }

    /// 예전 `comboValues` 한 칸(값만 있던 것)을 옮겨 온다. 이름은 비워 둔다.
    init(legacyValue: String) {
        self.init(key: "", value: legacyValue)
    }

    // ⚠️ 관용적 디코더. `Memo` 와 같은 이유다 - 비옵셔널 키가 없으면 배열 전체가 실패한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.reference = try c.decodeIfPresent(UUID.self, forKey: .reference)
    }

    enum CodingKeys: String, CodingKey {
        case id, key, value, reference
    }
}

struct Memo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var value: String
    var isChecked: Bool = false
    var lastEdited: Date = Date()
    var isFavorite: Bool = false
    var clipCount: Int = 0
    /// 마지막 "사용" 시점. 편집과 구분하여 히어로 카드/최근 섹션/상대시간 라벨 등에 사용된다.
    /// Optional로 선언해 기존 memos.data와 하위 호환을 유지한다 (없으면 lastEdited 폴백).
    var lastUsedAt: Date?

    // New features
    var category: String = "기본"
    var isSecure: Bool = false
    var templateVariables: [String] = []
    /// 템플릿 여부(계산형) - 본문에 {변수}가 있으면(=templateVariables 비어있지 않으면) 템플릿.
    /// 별도 토글/타입 없이 "변수 있으면 템플릿"으로 자동 판정.
    var isTemplate: Bool { !templateVariables.isEmpty }

    // 템플릿의 플레이스홀더 값들 저장 (예: {이름}: [유미, 주디, 리이오])
    var placeholderValues: [String: [String]] = [:]

    /// **단축어 스택** = 이름과 값을 가진 칸들이 순서대로 늘어선 것. 비어 있지 않으면 스택이다.
    ///
    /// ⚠️ 저장될 때는 `stackItems`(새 키)와 `comboValues`(값만 추린 옛 키)를 **함께** 쓴다.
    ///    구버전 앱과 위젯이 옛 키를 읽기 때문이다. 옛 키를 지우면 되돌아간 사람의 스택이
    ///    통째로 사라진다.
    var stackItems: [StackItem] = []
    /// 스택이 값을 차례로 넣을 때 칸 사이 시간 간격(초).
    var stackInterval: TimeInterval = 2.0
    /// 스택 여부(계산형) - 칸이 하나라도 있으면 스택.
    var isStack: Bool { !stackItems.isEmpty }

    /// 칸들의 값만. 값만 쓰던 자리가 아직 많아 그대로 둔다.
    var stackValues: [String] { stackItems.map(\.value) }

    /// 칸의 **값만** 갈아 끼운다. 이름은 자리대로 따라간다.
    ///
    /// ⚠️ 값을 통째로 새로 넣는 자리가 셋 있다(잠글 때 암호화 · 열 때 복호화 · 편집 저장).
    ///    그 셋이 `stackItems` 를 통째로 새로 만들면 **사용자가 지은 이름이 날아간다.**
    ///    개수가 같으면 자리대로 이름을 물려주고, 늘어난 자리만 이름 없이 시작한다.
    mutating func setStackValues(_ values: [String]) {
        stackItems = values.enumerated().map { index, value in
            var item = stackItems.indices.contains(index) ? stackItems[index] : StackItem(value: value)
            item.value = value
            return item
        }
    }

    /// 화면이 부를 이름. 이름을 안 지은 칸은 **자리로 부른다**(1단계, 2단계).
    ///
    /// ⚠️ 이 말은 그릴 때 만든다. 옛 콤보를 옮기며 "1단계" 를 **데이터에 적어 두면**
    ///    영어로 바꾼 사람에게도 한국어가 그대로 남는다. 빈 이름은 빈 채로 두고,
    ///    보여 줄 때만 자리 이름을 붙인다.
    func displayKey(at index: Int) -> String {
        guard stackItems.indices.contains(index) else { return "" }
        let key = stackItems[index].key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { return key }
        return String(format: NSLocalizedString("%d단계", comment: "Stack item fallback name by position"),
                      index + 1)
    }
    /// (레거시) 콤보=자식 메모 참조. 마이그레이션 디코드용으로만 보관. 신규 로직 미사용.
    var childMemoIds: [UUID] = []


    // 자동 분류 관련 (Phase 1 추가)
    var autoDetectedType: ClipboardItemType?

    // 이미지 지원
    var imageFileName: String? // 단일 이미지 (하위 호환성)
    var imageFileNames: [String] = [] // 다중 이미지 지원
    var contentType: ClipboardContentType = .text // 콘텐츠 타입

    /// "어디서 / 언제 쓰나요?" 컨텍스트 힌트.
    /// ADHD·건망증 사용자가 나중에 이 메모를 왜 저장했는지 떠올릴 수 있도록 돕는다.
    /// 값이 있으면 카드 내용 힌트(자동 요약 대신)로도 쓰인다.
    /// Optional이라 기존 데이터와 완전 하위 호환 (없으면 nil).
    var hint: String?
    /// 힌트를 키보드에서도 표시할지 - ON이면 키보드 셀의 "표시할 이름"이 잠시 힌트로
    /// 바뀌었다 돌아온다(동기화). hint가 비어있으면 무의미. 기본 ON.
    var hintShownOnKeyboard: Bool = true

    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false, category: String = "기본", isSecure: Bool = false, templateVariables: [String] = [], placeholderValues: [String: [String]] = [:], stackValues: [String] = [], stackInterval: TimeInterval = 2.0, autoDetectedType: ClipboardItemType? = nil, imageFileName: String? = nil, imageFileNames: [String] = [], contentType: ClipboardContentType = .text, lastUsedAt: Date? = nil, hint: String? = nil, hintShownOnKeyboard: Bool = true) {
        self.id = id
        self.title = title
        self.value = value
        self.isChecked = isChecked
        self.lastEdited = lastEdited
        self.isFavorite = isFavorite
        self.category = category
        self.isSecure = isSecure
        self.templateVariables = templateVariables
        self.placeholderValues = placeholderValues
        self.stackItems = stackValues.map { StackItem(legacyValue: $0) }
        self.stackInterval = stackInterval
        self.autoDetectedType = autoDetectedType
        self.imageFileName = imageFileName
        self.imageFileNames = imageFileNames
        self.contentType = contentType
        self.lastUsedAt = lastUsedAt
        self.hint = hint
        self.hintShownOnKeyboard = hintShownOnKeyboard
    }

    init(from oldMemo: OldMemo) {
        self.id = oldMemo.id
        self.title = oldMemo.title
        self.value = oldMemo.value
        self.isChecked = oldMemo.isChecked
        self.lastEdited = Date() // 새로운 버전에서 추가된 속성 초기화
        self.isFavorite = false
    }

    /// 관용적 디코더 - 모든 필드를 `decodeIfPresent` + 기본값으로 읽는다.
    /// ⚠️ 매우 중요(하위호환): 합성 Codable은 CodingKeys의 비옵셔널 키가 JSON에
    /// 없으면 `keyNotFound`를 던져 **[Memo] 배열 전체 디코딩이 실패**한다. 그러면
    /// load 폴백이 OldMemo(title/value만)로 떨어져 카테고리·즐겨찾기·콤보 등이
    /// 통째로 사라진다. 신규 키(childMemoIds, comboValues, comboInterval 등)가
    /// 없던 구버전 memos.data도 안전하게 디코딩되도록 누락 키를 모두 허용한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        self.lastEdited = try c.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date()
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.clipCount = try c.decodeIfPresent(Int.self, forKey: .clipCount) ?? 0
        self.lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? "기본"
        self.isSecure = try c.decodeIfPresent(Bool.self, forKey: .isSecure) ?? false
        self.templateVariables = try c.decodeIfPresent([String].self, forKey: .templateVariables) ?? []
        self.placeholderValues = try c.decodeIfPresent([String: [String]].self, forKey: .placeholderValues) ?? [:]
        // 스택 칸. 새 키가 있으면 그것이 진짜다. 없으면 **옛 콤보를 그 자리에서 옮긴다**
        // (값만 있던 것 → 이름 없는 칸). 따로 마이그레이션을 돌리지 않는 이유는,
        // 읽는 순간 옮기면 옛 파일도 새 파일도 같은 길로 들어오기 때문이다.
        if let items = try c.decodeIfPresent([StackItem].self, forKey: .stackItems), !items.isEmpty {
            self.stackItems = items
        } else {
            let legacy = try c.decodeIfPresent([String].self, forKey: .comboValues) ?? []
            self.stackItems = legacy.map { StackItem(legacyValue: $0) }
        }
        self.stackInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .comboInterval) ?? 2.0
        self.childMemoIds = try c.decodeIfPresent([UUID].self, forKey: .childMemoIds) ?? []
        self.autoDetectedType = try c.decodeIfPresent(ClipboardItemType.self, forKey: .autoDetectedType)
        self.imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        self.contentType = try c.decodeIfPresent(ClipboardContentType.self, forKey: .contentType) ?? .text
        self.hint = try c.decodeIfPresent(String.self, forKey: .hint)
        self.hintShownOnKeyboard = try c.decodeIfPresent(Bool.self, forKey: .hintShownOnKeyboard) ?? true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case value
        case isChecked
        case lastEdited = "lastEdited"
        case isFavorite = "isFavorite"
        case clipCount
        case category
        case isSecure
        case templateVariables
        case placeholderValues
        // ⚠️ **파일에 적히는 글자는 옛 이름 그대로 둔다.** 코드에서는 스택이라 부르지만
        //    이 글자를 바꾸면 쓰던 사람의 파일을 못 읽고, 되돌아간 앱과 위젯도 못 읽는다.
        //    이름은 코드의 것이고, 글자는 데이터의 것이다.
        case comboValues
        case stackItems
        case childMemoIds
        case comboInterval
        case autoDetectedType
        case imageFileName
        case imageFileNames
        case contentType
        case lastUsedAt
        case hint
        case hintShownOnKeyboard
    }

    /// ⚠️ 하위호환(다운그레이드 안전): 구버전(4.3.0 이하)의 **합성** Codable 디코더는
    /// `isTemplate`/`isCombo`/`currentComboIndex`(비옵셔널) 키가 JSON에 없으면 keyNotFound를
    /// 던져 `[Memo]` 디코딩이 통째로 실패하고, OldMemo(title/value만) 폴백으로 카테고리·
    /// 즐겨찾기·콤보가 전멸한다. 4.3.1에서 이 키들을 stored→계산형으로 바꾸며 인코딩에서
    /// 누락시킨 것이 원인. 계산형 값을 레거시 키로도 함께 써서 구버전이 안전하게 읽게 한다.
    /// (attachedTemplateId는 Optional이라 구버전이 누락을 허용 → 생략.)
    private enum LegacyCompatKeys: String, CodingKey {
        case isTemplate
        case isStack
        case currentComboIndex
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(value, forKey: .value)
        try c.encode(isChecked, forKey: .isChecked)
        try c.encode(lastEdited, forKey: .lastEdited)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(clipCount, forKey: .clipCount)
        try c.encode(category, forKey: .category)
        try c.encode(isSecure, forKey: .isSecure)
        try c.encode(templateVariables, forKey: .templateVariables)
        try c.encode(placeholderValues, forKey: .placeholderValues)
        // ⚠️ **둘 다 쓴다.** 새 키는 이름까지 담고, 옛 키는 값만 담는다.
        //    되돌아간 앱과 위젯이 옛 키를 읽으므로, 빼면 그 사람들의 스택이 사라진다.
        try c.encode(stackItems, forKey: .stackItems)
        try c.encode(stackValues, forKey: .comboValues)
        try c.encode(childMemoIds, forKey: .childMemoIds)
        try c.encode(stackInterval, forKey: .comboInterval)
        try c.encodeIfPresent(autoDetectedType, forKey: .autoDetectedType)
        try c.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try c.encode(imageFileNames, forKey: .imageFileNames)
        try c.encode(contentType, forKey: .contentType)
        try c.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try c.encodeIfPresent(hint, forKey: .hint)
        try c.encode(hintShownOnKeyboard, forKey: .hintShownOnKeyboard)

        // 레거시 키도 함께 기록 - 구버전 디코더가 필수로 요구하는 키.
        var legacy = encoder.container(keyedBy: LegacyCompatKeys.self)
        try legacy.encode(isTemplate, forKey: .isTemplate)
        try legacy.encode(isStack, forKey: .isStack)   // 글자는 옛 이름, 값은 지금 것
        try legacy.encode(0, forKey: .currentComboIndex)
    }

    static var dummyData: [Memo] = {
        let date = dateFormatter.date(from: "2023-08-31 10:00:00") ?? Date()
        return [
            Memo(title: "계좌번호",
                 value: "123412341234123412341234123412341234123412341234",
                 lastEdited: date),
            Memo(title: "부모님 댁 주소",
                 value: "거기 어딘가",
                 lastEdited: date),
            Memo(title: "통관번호",
                 value: "p12341234",
                 lastEdited: date)
        ]
    }()
}

// MARK: - Combo System (Phase 2)

// Combo Item Type - 어떤 종류의 항목인지
enum ComboItemType: String, Codable {
    // ⚠️ rawValue는 저장 데이터에 직렬화됨 - 용어가 바뀌어도 절대 변경 금지("메모" 유지).
    case memo = "메모"
    case clipboardHistory = "클립보드"
    case template = "템플릿"

    // 다국어 지원 표시명 - rawValue와 분리(용어 개편: 저장 항목은 '단축어').
    var localizedName: String {
        switch self {
        case .memo: return NSLocalizedString("단축어", comment: "Snippet (saved key-value item) display name")
        case .clipboardHistory: return NSLocalizedString("클립보드", comment: "Clipboard")
        case .template: return NSLocalizedString("템플릿", comment: "Template")
        }
    }
}

// Combo에 포함되는 개별 항목
struct ComboItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: ComboItemType
    var referenceId: UUID  // 메모 또는 클립보드 항목의 ID
    var order: Int  // 실행 순서

    // 표시용 정보 (캐시)
    var displayTitle: String?  // 항목의 제목/미리보기
    var displayValue: String?  // 항목의 실제 값 (미리보기용)

    init(id: UUID = UUID(), type: ComboItemType, referenceId: UUID, order: Int, displayTitle: String? = nil, displayValue: String? = nil) {
        self.id = id
        self.type = type
        self.referenceId = referenceId
        self.order = order
        self.displayTitle = displayTitle
        self.displayValue = displayValue
    }
}

// Combo - 여러 메모를 순서대로 자동 입력하는 시스템
struct Combo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [ComboItem]  // 순서대로 실행될 항목들
    var interval: TimeInterval = 2.0  // 각 항목 사이의 시간 간격 (초)
    var createdAt: Date = Date()
    var lastUsed: Date?
    var category: String = "텍스트"
    var useCount: Int = 0
    var isFavorite: Bool = false

    init(id: UUID = UUID(), title: String, items: [ComboItem] = [], interval: TimeInterval = 2.0, createdAt: Date = Date(), lastUsed: Date? = nil, category: String = "텍스트", useCount: Int = 0, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.items = items.sorted(by: { $0.order < $1.order })
        self.interval = interval
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.category = category
        self.useCount = useCount
        self.isFavorite = isFavorite
    }

    // 항목을 순서대로 정렬
    mutating func sortItems() {
        items.sort(by: { $0.order < $1.order })
    }
}

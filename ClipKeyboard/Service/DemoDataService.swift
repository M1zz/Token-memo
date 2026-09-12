//
//  DemoDataService.swift
//  ClipKeyboard
//
//  "데모 데이터" 토글의 실체 - 스크린샷·영상 촬영이나 앱 소개용으로
//  잘 짜인 페르소나(프리랜서 디자이너) 데이터 한 벌을 즉시 켜고 끌 수 있게 한다.
//
//  설계 원칙
//  - **내 데이터는 절대 잃지 않는다**: 켜기 직전의 단축어/클립보드를 App Group에
//    통째로 백업하고, 끄면 그대로 되돌린다(백업이 없으면 되돌리기 대신 데모만 비운다).
//  - **언어별 데이터셋**: 여기 문자열들은 UI 라벨이 아니라 "저장된 사용자 데이터"를
//    흉내 내는 샘플 콘텐츠다. 번역 슬롯을 거치면 한/영 스크린샷에서 문맥이 어긋나므로
//    ko/en 데이터셋을 각각 손으로 쓰고 현재 언어로 고른다. (UI 라벨은 SettingView에서
//    NSLocalizedString으로 처리한다.)
//

import Foundation

// MARK: - Demo Data Service

final class DemoDataService {
    static let shared = DemoDataService()
    private init() {}

    /// 데모 데이터가 켜져 있는지 (App Group - 키보드 익스텐션도 같은 데이터를 본다).
    var isActive: Bool {
        AppGroup.defaults?
            .bool(forKey: DefaultsKey.demoDataActive) ?? false
    }

    // MARK: Public

    /// 데모 데이터를 켠다. 현재 데이터는 백업해 두고 끌 때 복원한다.
    /// - Returns: 성공 여부. 실패 시 원본 데이터는 건드리지 않는다.
    @discardableResult
    func enable() -> Bool {
        guard !isActive else { return true }
        guard backupCurrentData() else {
            print("❌ [DemoDataService.enable] 백업 실패, 데모 적용을 중단합니다")
            return false
        }
        do {
            try MemoStore.shared.save(memos: Self.demoMemos(), type: .memo, recordHistory: false)
            try MemoStore.shared.saveSmartClipboardHistory(history: Self.demoClipboard())
            setActive(true)
            print("✅ [DemoDataService.enable] 데모 데이터 적용 완료")
            return true
        } catch {
            print("❌ [DemoDataService.enable] 데모 데이터 저장 실패: \(error)")
            // 저장이 반쯤 진행됐을 수 있으니 백업을 즉시 되돌린다.
            _ = restoreBackup()
            return false
        }
    }

    /// 데모 데이터를 끄고 원래 데이터를 복원한다.
    @discardableResult
    func disable() -> Bool {
        guard isActive else { return true }
        let restored = restoreBackup()
        setActive(false)
        print(restored
              ? "✅ [DemoDataService.disable] 원본 데이터 복원 완료"
              : "⚠️ [DemoDataService.disable] 복원할 백업이 없어 데모 데이터만 비웠습니다")
        return restored
    }

    // MARK: Backup / Restore

    private var backupURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("demo.backup.data")
    }

    /// 현재 단축어/클립보드를 한 파일로 백업. 이미 백업이 있으면 덮어쓰지 않는다
    /// (데모 상태에서 중복 호출돼도 원본이 데모로 대체되지 않도록).
    private func backupCurrentData() -> Bool {
        guard let url = backupURL else { return false }
        if FileManager.default.fileExists(atPath: url.path) { return true }
        do {
            let payload = BackupPayload(
                memos: (try? MemoStore.shared.load(type: .memo)) ?? [],
                clipboard: (try? MemoStore.shared.loadSmartClipboardHistory()) ?? []
            )
            let data = try JSONEncoder().encode(payload)
            // atomic - 쓰다 중단돼도 이전 백업/원본이 깨지지 않는다.
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("❌ [DemoDataService.backupCurrentData] \(error)")
            return false
        }
    }

    /// 백업을 되돌리고 백업 파일을 지운다. 백업이 없으면 데모 데이터만 비운다.
    private func restoreBackup() -> Bool {
        guard let url = backupURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(BackupPayload.self, from: data) else {
            try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
            try? MemoStore.shared.saveSmartClipboardHistory(history: [])
            return false
        }
        do {
            try MemoStore.shared.save(memos: payload.memos, type: .memo, recordHistory: false)
            try MemoStore.shared.saveSmartClipboardHistory(history: payload.clipboard)
            try? FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("❌ [DemoDataService.restoreBackup] \(error)")
            return false
        }
    }

    private func setActive(_ active: Bool) {
        AppGroup.defaults?
            .set(active, forKey: DefaultsKey.demoDataActive)
    }

    private struct BackupPayload: Codable {
        let memos: [Memo]
        let clipboard: [SmartClipboardHistory]
    }
}

// MARK: - Demo Dataset (페르소나: 프리랜서 브랜드 디자이너)

extension DemoDataService {

    /// 현재 앱 언어가 한국어인지. 데이터셋 선택에만 쓴다(UI 라벨과 무관).
    private static var usesKorean: Bool {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("ko")
    }

    /// 시연용 단축어 6개 - 무료 한도(10) 안쪽이라 업셀 배너 없이 깔끔하게 보인다.
    /// 즐겨찾기 2개 + 템플릿 1개 + 콤보 1개 + 보안 1개로 앱의 기능 폭을 한 화면에 담는다.
    static func demoMemos() -> [Memo] {
        let now = Date()
        func ago(hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        if usesKorean {
            return [
                make("정산 계좌", "카카오뱅크 3333-08-1234567 이현호",
                     hint: "인보이스 보낼 때", favorite: true, clips: 89,
                     used: ago(hours: 2), type: .bankAccount),
                make("업무 메일", "leeo.design@gmail.com",
                     hint: "회원가입·문의 답장", favorite: true, clips: 132,
                     used: ago(hours: 1), type: .email),
                make("견적 회신",
                     "{클라이언트}님 안녕하세요!\n문의주신 {프로젝트} 작업은 {금액}원, 기간은 2주로 견적드립니다.\n검토 후 편하게 회신 주세요 :)",
                     hint: "견적 문의 올 때 30초 컷", clips: 31, used: ago(hours: 8),
                     variables: ["클라이언트", "프로젝트", "금액"],
                     placeholders: [
                        "클라이언트": ["소연", "민준 팀장", "J님"],
                        "프로젝트": ["로고 리뉴얼", "상세페이지", "브랜드 가이드"],
                        "금액": ["1,800,000", "3,500,000", "900,000"]
                     ]),
                make("계약 안내 콤보", "안녕하세요, 계약서 보내드립니다.",
                     hint: "계약 단계에서 순서대로", clips: 12, used: ago(hours: 26),
                     stack: ["안녕하세요, 계약서 보내드립니다. 확인 부탁드려요.",
                             "서명 후 회신 주시면 착수 일정 잡겠습니다.",
                             "감사합니다. 좋은 하루 되세요!"]),
                make("포트폴리오", "https://leeo.design",
                     hint: "첫 미팅 전에 공유", clips: 56, used: ago(hours: 3), type: .url),
                make("여권번호", "M12345678",
                     hint: "해외 결제·항공권 예약", clips: 8, used: ago(hours: 120), secure: true),
            ]
        }
        return [
            make("Payout account", "Wise USD 8312-4459-22 Leeo Studio",
                 hint: "When sending invoices", favorite: true, clips: 89,
                 used: ago(hours: 2), type: .bankAccount),
            make("Work email", "leeo.design@gmail.com",
                 hint: "Sign-ups & replies", favorite: true, clips: 132,
                 used: ago(hours: 1), type: .email),
            make("Quote reply",
                 "Hi {client}!\nFor {project}, the quote is {price} USD with a 2-week turnaround.\nLooking forward to your thoughts :)",
                 hint: "30-second quote replies", clips: 31, used: ago(hours: 8),
                 variables: ["client", "project", "price"],
                 placeholders: [
                    "client": ["Sofia", "Mr. Park", "Jamie"],
                    "project": ["logo refresh", "landing page", "brand guide"],
                    "price": ["1,800", "3,500", "900"]
                 ]),
            make("Contract combo", "Hi! Please find the contract attached.",
                 hint: "Step by step at contract time", clips: 12, used: ago(hours: 26),
                 stack: ["Hi! Please find the contract attached.",
                         "Once signed, I'll lock in the start date.",
                         "Thanks: have a great day!"]),
            make("Portfolio", "https://leeo.design",
                 hint: "Share before the first call", clips: 56, used: ago(hours: 3), type: .url),
            make("Passport number", "M12345678",
                 hint: "Flights & overseas payments", clips: 8, used: ago(hours: 120), secure: true),
        ]
    }

    /// 시연용 클립보드 6건 - 자동 분류가 한눈에 보이도록 타입을 골고루 섞었다.
    static func demoClipboard() -> [SmartClipboardHistory] {
        let now = Date()
        func ago(minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

        let rows: [(String, ClipboardItemType, Double, Double)] = usesKorean
            ? [("brief@agency.co.kr", .email, 0.95, 10),
               ("010-5551-2342", .phone, 0.9, 40),
               ("https://www.notion.so/leeo/brief-0721", .url, 0.9, 130),
               ("서울 강남구 테헤란로 427", .address, 0.85, 200),
               ("DE89 3704 0044 0532 0130 00", .iban, 0.9, 1500),
               ("597231650123", .trackingNumber, 0.8, 1700)]
            : [("brief@agency.com", .email, 0.95, 10),
               ("+1 415-555-2342", .phone, 0.9, 40),
               ("https://www.notion.so/leeo/brief-0721", .url, 0.9, 130),
               ("427 Teheran-ro, Gangnam-gu, Seoul", .address, 0.85, 200),
               ("DE89 3704 0044 0532 0130 00", .iban, 0.9, 1500),
               ("597231650123", .trackingNumber, 0.8, 1700)]

        return rows.map { content, type, confidence, minutes in
            SmartClipboardHistory(content: content, copiedAt: ago(minutes: minutes),
                                  detectedType: type, confidence: confidence)
        }
    }

    // MARK: Helper

    private static func make(
        _ title: String,
        _ value: String,
        hint: String,
        favorite: Bool = false,
        clips: Int = 0,
        used: Date,
        type: ClipboardItemType? = nil,
        secure: Bool = false,
        variables: [String] = [],
        placeholders: [String: [String]] = [:],
        stack: [String] = []
    ) -> Memo {
        var memo = Memo(
            title: title,
            value: value,
            isFavorite: favorite,
            isSecure: secure,
            templateVariables: variables,
            placeholderValues: placeholders,
            stackValues: stack,
            autoDetectedType: type,
            lastUsedAt: used,
            hint: hint
        )
        memo.clipCount = clips
        memo.lastEdited = used
        return memo
    }
}

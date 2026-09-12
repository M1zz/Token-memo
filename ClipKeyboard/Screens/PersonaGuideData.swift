//
//  PersonaGuideData.swift
//  ClipKeyboard
//
//  "이런 분들이 매일 아낍니다" - 활용 사례 화면(UsageGuideView)의 페르소나 스토리 데이터.
//  누가(페르소나) 어떤 불편을 겪고, ClipKeyboard로 무엇이 어떻게 달라지는지 공감 스토리로 전한다.
//  로케일(ko/id/en)별로 그 나라의 실제 맥락에 맞는 문구를 직접 담는다. 문자열은 배열 자체가
//  이미 해당 언어라 NSLocalizedString 없이 그대로 표시한다(usageCategories와 동일 원칙).
//

import SwiftUI

// MARK: - Model

/// 페르소나 스토리 한 편(활용 방법 1개).
/// pain(공감되는 불편함) → example(저장할 문구) → impact(무엇이 달라지는지)의 3단 구성.
struct PersonaScenario: Identifiable {
    let id = UUID()
    let title: String        // 상황 제목
    let pain: String         // 공감 맥락: "이런 순간, 불편했죠"
    let example: String      // 저장할 문구 예시 ({플레이스홀더} 포함 가능)
    let impact: String       // "이렇게 달라져요" - 만들어지는 차이
    let feature: ScenarioFeature
}

/// 한 페르소나의 스토리 묶음.
struct PersonaGuide: Identifiable {
    var id: String { persona.rawValue }
    let persona: Persona
    let intro: String                 // 페르소나 공감 인트로(하루의 풍경)
    let scenarios: [PersonaScenario]  // 10개 이상의 활용 방법
}

// MARK: - Locale-aware accessor

/// 현재 로케일에 맞는 페르소나 가이드. UsageGuideView가 참조.
var personaGuides: [PersonaGuide] {
    let lang = Locale.current.language.languageCode?.identifier ?? "en"
    switch lang {
    case "ko": return PersonaGuideCatalog.korean
    case "id": return PersonaGuideCatalog.indonesian
    default:   return PersonaGuideCatalog.english
    }
}

// MARK: - Content

private enum PersonaGuideCatalog {

    // =====================================================================
    // MARK: - 한국어 (ko)
    // =====================================================================

    static let korean: [PersonaGuide] = [

        // ------------------------------------------------------------- 노마드
        PersonaGuide(
            persona: .nomad,
            intro: "카페와 코워킹 스페이스를 옮겨 다니며 해외 클라이언트와 일하는 당신. 시차, 국제 송금, 비자, 매번 비슷한 영어 이메일: 필요한 정보를 다른 창에서 찾아 붙여넣는 사이 하루가 새어나갑니다. 한 번 저장해두면, 그다음부턴 탭 한 번이면 끝나요.",
            scenarios: [
                PersonaScenario(
                    title: "해외 송금 정보 요청",
                    pain: "\"Send me your banking details\" 한 줄에, IBAN·SWIFT를 은행 앱에서 다시 찾아 헤맵니다.",
                    example: "Name: {영문 이름}\nIBAN: {IBAN}\nSWIFT/BIC: {SWIFT}\nBank address: {은행 주소}\nWise: {Wise 이메일}",
                    impact: "송금 요청이 올 때마다 30초 검색이 탭 한 번으로. 자릿수 틀릴 걱정도 사라집니다.",
                    feature: .stack
                ),
                PersonaScenario(
                    title: "시차 안내 한 줄",
                    pain: "새벽 2시에 온 \"Can we hop on a call?\"에 매번 시차를 설명하느라 지칩니다.",
                    example: "Hi {이름}, I'm in GMT+{시차} ({도시}) right now. I can do {가능 시간대}. Calendly: {링크}",
                    impact: "\"몇 시가 편하세요\" 왕복 3통이 한 통으로 줄어듭니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "인보이스 발송",
                    pain: "인보이스 번호·금액·통화·기한을 매번 손으로 맞춰 적습니다.",
                    example: "Invoice #{번호} · {통화} {금액}\nDue: {기한}\nPayment: Wise ({이메일})\nThank you! 🙏",
                    impact: "빠뜨리기 쉬운 항목을 템플릿이 붙잡아줘, 재청구·정정 메일이 줄어요.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "제안서 팔로업",
                    pain: "보낸 제안서에 3일째 답이 없을 때, 재촉 같지 않게 쓰는 게 매번 어렵습니다.",
                    example: "Hi {클라이언트}, just following up on the proposal I sent {요일}. Happy to jump on a quick call if anything needs clarifying.\n\nBest, {이름}",
                    impact: "정중한 팔로업을 고민 없이 즉시 발송, 놓치던 계약을 되살립니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "여권·비자 정보",
                    pain: "항공·숙소·비자 신청마다 여권번호와 만료일을 확인하러 서랍을 뒤집니다.",
                    example: "여권번호: {여권번호}\n영문 성명: {영문 이름}\n발급일/만료일: {발급일} / {만료일}\n국적: {국적}",
                    impact: "보안 단축어(생체인증)로 잠가두면, 필요할 때만 열어 안전하게 붙여넣기.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "\"어디 사세요?\" 답변",
                    pain: "새 클라이언트의 가벼운 질문에, 노마드라는 걸 매번 길게 설명하게 됩니다.",
                    example: "Based nowhere in particular: currently in {도시}. I work async-first, so timezones rarely matter, but I'll always give you a clear window when I'm reachable.",
                    impact: "불안해 보이지 않게, 프로페셔널한 인상을 한 번에 전달합니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "와이파이 끊김 알림",
                    pain: "통화 직전 코워킹 와이파이가 끊기면, 급하게 사과 메시지를 쥐어짜냅니다.",
                    example: "Hi team, wifi at my co-working just dropped. Moving to a backup spot: back online in {분}분. Ready to continue right after. 🙏",
                    impact: "당황한 순간에도 침착하고 신뢰감 있는 한 줄을 즉시 보냅니다.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "환율·견적 안내",
                    pain: "통화가 다른 클라이언트에게 견적을 줄 때, 환율 안내 문구를 매번 새로 씁니다.",
                    example: "Quote: {통화} {금액} (≈ {환산액} at today's rate).\nInvoiced in {통화} via Wise to keep fees low for you.",
                    impact: "가격 오해를 미리 차단해, 정산 단계의 실랑이를 없앱니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "신규 클라이언트 온보딩",
                    pain: "계약 직후 캘린들리·슬랙·결제·진행 방식을 매번 순서대로 안내합니다.",
                    example: "환영합니다, {클라이언트}님! 진행은 이렇게 해요:\n1. 첫 미팅 캘린들리: {링크}\n2. 결제(원할 시 송금 정보 첨부)\n3. 슬랙 초대 24시간 내 발송\n4. 매주 목요일 진행 데모\n\n잘 부탁드려요!",
                    impact: "Combo로 여러 단축어를 순서대로 자동 입력, 온보딩 메일이 5분에서 5초로.",
                    feature: .stack
                ),
                PersonaScenario(
                    title: "하루 마감·오프라인 전환",
                    pain: "밤 10시 급한 DM에 '지금은 대응 어렵다'를 매번 예의 있게 쓰기 어렵습니다.",
                    example: "Hi! Signing off for the night ({시간} in {도시}). I'll reply first thing in my morning, thanks for your patience 🙏",
                    impact: "경계는 지키되 무례하지 않게, 번아웃 없이 신뢰를 지킵니다.",
                    feature: .template
                )
            ]
        ),

        // ------------------------------------------------------------- 비즈니스
        PersonaGuide(
            persona: .business,
            intro: "회의, 보고, 회신: 하루에도 수십 번 같은 문구를 다시 씁니다. '확인 부탁드립니다', 미팅 안내, 부재중 응답. 예의를 갖춘 반복 문구를 저장해두면, 손이 아니라 머리를 일에 씁니다.",
            scenarios: [
                PersonaScenario(
                    title: "부재중 자동응답",
                    pain: "휴가·출장 때마다 부재 안내를 새로 쓰고, 대체 담당자 연락처를 빠뜨립니다.",
                    example: "안녕하세요. {시작일}부터 {종료일}까지 부재중입니다.\n급한 업무는 {담당자}({연락처})에게 연락 주세요.\n복귀 후 순차적으로 회신드리겠습니다. 감사합니다.",
                    impact: "빠짐없는 안내로 업무 공백을 막고, 복귀 후 폭탄 회신을 줄입니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "회의 일정 안내",
                    pain: "미팅을 잡을 때마다 일시·장소·안건 형식을 매번 새로 타이핑합니다.",
                    example: "안녕하세요 {이름}님,\n아래 일정으로 미팅 요청드립니다.\n📅 일시: {날짜} {시간}\n📍 장소: {장소}\n📌 안건: {안건}\n참석 가능 여부 회신 부탁드립니다 😊",
                    impact: "정돈된 안내로 재확인 메일이 줄고, 노쇼가 눈에 띄게 감소합니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "주간 업무 보고",
                    pain: "매주 같은 양식의 보고를 빈 화면에서 다시 시작합니다.",
                    example: "안녕하세요. 금주 업무 보고드립니다.\n✅ 완료: {완료사항}\n🔄 진행 중: {진행중}\n📋 다음 주 예정: {예정사항}\n문의사항 있으시면 말씀해 주세요.",
                    impact: "양식은 고정, 내용만 채우면 끝: 금요일 저녁이 가벼워집니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "명함·자기소개",
                    pain: "처음 인사드리는 자리마다 소속·직함·연락처를 매번 다르게 적습니다.",
                    example: "안녕하세요, {이름}입니다.\n{소속}에서 {업무}를 맡고 있습니다.\n📧 {이메일} / 📞 {전화번호}\n잘 부탁드립니다 🙏",
                    impact: "일관된 소개로 신뢰를 주고, 오타 난 연락처로 연락이 끊길 일이 없어요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "이메일 서명",
                    pain: "회사 메일 앱마다 서명이 안 옮겨져, 매번 손으로 붙입니다.",
                    example: "{이름}\n{직책} | {회사명}\n📧 {이메일}\n📞 {전화번호}\n🌐 {홈페이지}",
                    impact: "어느 앱·기기에서 보내든 통일된 서명. 브랜드 인상이 흐트러지지 않아요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "세금계산서·입금 정보",
                    pain: "거래처가 계좌·사업자번호를 물을 때마다 회계 파일을 열어 확인합니다.",
                    example: "입금 계좌: {은행} {계좌번호} ({예금주})\n사업자등록번호: {사업자번호}\n상호: {상호}\n세금계산서 이메일: {이메일}",
                    impact: "요청 즉시 정확히 전달, 정산 지연과 오류 입금이 사라집니다.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "외주·협업 제안",
                    pain: "협업을 제안할 때, 나를 소개하고 용건을 정중히 여는 첫 메일이 늘 어렵습니다.",
                    example: "안녕하세요 {담당자}님,\n{프로젝트} 관련 협업을 제안드리고자 연락드립니다.\n저는 {회사/이름}에서 {업무}를 맡고 있습니다.\n간단히 통화 가능하실까요? 편하신 시간 알려주세요. 감사합니다.",
                    impact: "매번 고민하던 첫 문장을 즉시 발송, 제안 횟수 자체가 늘어납니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "회신 지연 양해",
                    pain: "답이 늦어질 때, 무성의해 보이지 않게 양해를 구하는 게 신경 쓰입니다.",
                    example: "안녕하세요 {이름}님, 회신이 늦어 죄송합니다. {사유}로 확인이 지연되었습니다. {일시}까지 정리해 다시 연락드리겠습니다. 양해 부탁드립니다.",
                    impact: "침묵 대신 신뢰를 주는 한 줄로, 관계가 상하지 않게 지킵니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "프로젝트 마무리 감사",
                    pain: "잘 끝난 프로젝트일수록, 마무리 인사를 미루다 타이밍을 놓칩니다.",
                    example: "안녕하세요 {이름}님,\n이번 {프로젝트} 함께해 주셔서 진심으로 감사드립니다.\n덕분에 좋은 결과를 낼 수 있었습니다.\n앞으로도 좋은 인연 이어가고 싶습니다 😊",
                    impact: "관계를 다음 일로 잇는 인사를 놓치지 않게, 재의뢰로 이어집니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "정산·비용 청구",
                    pain: "월말마다 정산 내역과 계좌를 정리해 보내느라 손이 많이 갑니다.",
                    example: "안녕하세요! {월}월 정산 내역 보내드립니다.\n금액: {금액}원 (VAT 포함)\n입금 계좌: {은행} {계좌번호} ({예금주})\n확인 부탁드립니다 😊",
                    impact: "형식 실수 없는 청구로 재작성이 사라지고, 입금이 빨라집니다.",
                    feature: .template
                )
            ]
        ),

        // ------------------------------------------------------------- 학생
        PersonaGuide(
            persona: .student,
            intro: "학번, 학교 이메일, 과제 제출 양식, 조별과제 공지: 학교 생활은 반복 입력의 연속입니다. 교수님 메일부터 팀플 정산, 자취방 주소까지 저장해두면, 그만큼 공부와 나에게 쓸 시간이 늘어나요.",
            scenarios: [
                PersonaScenario(
                    title: "학번+이름 세트",
                    pain: "수강신청·과제 제출·증명서 발급마다 학번과 이름을 다시 칩니다.",
                    example: "{학과} {학번} {이름}",
                    impact: "제출칸에 탭 한 번. 마감 직전 오타로 감점되는 일이 없어져요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "교수님께 보내는 메일",
                    pain: "교수님 메일은 예의를 갖춰야 해서, 첫 문장부터 매번 긴장됩니다.",
                    example: "안녕하세요 교수님, {학과} {학번} {이름}입니다.\n{과목}({분반}) 수강 중입니다.\n{용건}에 대해 여쭤보고자 메일 드립니다.\n바쁘신 중에 죄송합니다. 감사합니다.",
                    impact: "형식 걱정 없이 용건만 채우면 끝, 메일 보내기가 미루지 않게 됩니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "과제 표지·제출 양식",
                    pain: "과목마다 표지 양식이 달라, 제출 직전에 형식 맞추느라 시간을 씁니다.",
                    example: "과목명: {과목}\n담당 교수: {교수}\n제출자: {학과} {학번} {이름}\n제출일: {날짜}\n주제: {주제}",
                    impact: "양식은 저장, 내용만 갱신: 마감 스트레스가 한 겹 줄어요.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "조별과제 공지",
                    pain: "팀 단톡에 회의 일정·역할 분담을 정리해 올리는 게 매번 번거롭습니다.",
                    example: "[{과제}] 팀 공지 📢\n다음 회의: {날짜} {시간} @ {장소/링크}\n각자 준비: {준비물}\n마감: {마감일}\n확인하면 👍 눌러주세요!",
                    impact: "정돈된 공지로 '언제였지?' 되묻기가 사라지고 팀이 굴러갑니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "자취방·기숙사 주소",
                    pain: "배달·택배마다 상세주소와 공동현관 비번을 다시 입력합니다.",
                    example: "{우편번호}\n{주소}\n{상세주소}\n공동현관: {비밀번호}\n받는 분: {이름} / {전화번호}",
                    impact: "배달앱 주소칸에 탭 한 번. 잘못 간 택배로 헤맬 일이 없어요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "팀플·모임 N빵 정산",
                    pain: "회식·과제 재료비를 걷을 때, 금액과 계좌를 매번 계산해 올립니다.",
                    example: "오늘 총 {총금액}원! {인원}명이니까 1인당 {1인금액}원이에요 🙏\n{은행} {계좌번호} ({이름})으로 보내주세요~",
                    impact: "정산 메시지를 즉시 발송, 돈 얘기 꺼내는 어색함이 줄어듭니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "결석·사유 안내",
                    pain: "아프거나 사정이 생겼을 때, 교수님·조교께 알리는 문구가 급할수록 안 떠오릅니다.",
                    example: "안녕하세요 교수님, {학번} {이름}입니다.\n{날짜} {과목} 수업에 {사유}로 부득이 결석하게 되었습니다.\n관련 증빙은 {방법}으로 제출하겠습니다. 죄송합니다.",
                    impact: "당황한 순간에도 예의를 갖춘 연락을 즉시, 불이익을 줄입니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "동아리·스터디 모집",
                    pain: "모집 글을 여러 커뮤니티에 올릴 때마다 소개를 조금씩 다시 씁니다.",
                    example: "[{모임명}] 함께할 분을 찾아요! 🙌\n활동: {활동 내용}\n시간: {요일/시간}\n장소: {장소}\n신청: {링크/연락처}\n부담 없이 문의 주세요 😊",
                    impact: "여러 곳에 같은 글을 붙여넣기 한 번으로, 모집이 훨씬 빨라져요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "인턴 지원 기본 정보",
                    pain: "지원서마다 이름·연락처·학력·링크를 반복 입력하다 지칩니다.",
                    example: "{이름} · {전화번호} · {이메일}\n{학교} {학과} ({학년})\n포트폴리오: {링크}\nGitHub/블로그: {링크}",
                    impact: "지원 폼 채우기가 빨라져, 더 많은 기회에 도전하게 됩니다.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "지각·약속 변경",
                    pain: "수업·약속에 늦을 때, 미안한 마음에 문장이 자꾸 길어집니다.",
                    example: "미안해! {분}분 정도 늦을 것 같아. 거의 다 왔어 🙏",
                    impact: "짧고 확실한 연락으로, 기다리는 사람의 불안을 바로 덜어줍니다.",
                    feature: .template
                )
            ]
        ),

        // ------------------------------------------------------------- 일반/개인
        PersonaGuide(
            persona: .general,
            intro: "매일 쓰는 기본 정보: 계좌번호, 집 주소, 전화번호, 자주 보내는 인사. 매번 기억을 더듬거나 예전 대화를 뒤지지 않아도, 필요한 순간 탭 한 번이면 됩니다. 사소해 보여도, 하루에 쌓이면 꽤 큰 시간이에요.",
            scenarios: [
                PersonaScenario(
                    title: "계좌번호 공유",
                    pain: "\"계좌 좀\" 한마디에 은행 앱을 열어 번호를 확인하고 옮겨 적습니다.",
                    example: "{은행} {계좌번호}\n예금주: {이름}\n(카카오페이/토스도 가능해요 🙏)",
                    impact: "탭 한 번으로 정확히 전달, 자릿수 실수로 엉뚱한 곳에 갈 걱정이 없어요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "집 주소(배송)",
                    pain: "쇼핑·중고거래마다 상세주소와 연락처를 처음부터 다시 칩니다.",
                    example: "{우편번호}\n{주소}\n{상세주소}\n받는 분: {이름} / {전화번호}",
                    impact: "주소 입력이 한 번에 끝나, 오배송으로 시간 버릴 일이 줄어요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "약속 잡기",
                    pain: "만날 때마다 시간·장소를 조율하는 메시지를 새로 씁니다.",
                    example: "{날짜} {시간}에 {장소} 어때요? 안 되면 편한 시간 알려줘요 😊",
                    impact: "제안을 먼저 던지는 한 줄로, 약속이 훨씬 빨리 정해집니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "지각 알림",
                    pain: "늦을 때마다 미안함에 사과 문장을 길게 고쳐 씁니다.",
                    example: "미안해요! {분}분 정도 늦을 것 같아요. 먼저 가 계세요 🙏",
                    impact: "바로 보내는 짧은 알림이, 기다리는 사람 마음을 편하게 합니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "경조사 계좌 안내",
                    pain: "축의·조의 계좌를 물어올 때, 급하게 번호를 찾아 전합니다.",
                    example: "마음 전해주셔서 감사합니다.\n{은행} {계좌번호} ({예금주})\n와주시는 것만으로 큰 힘이 됩니다 🙏",
                    impact: "경황 없는 순간에도, 실수 없이 정중하게 안내할 수 있어요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "중고거래 안내",
                    pain: "거래마다 가격·상태·직거래 장소를 비슷하게 다시 씁니다.",
                    example: "{상품명} 판매합니다.\n가격: {가격} (네고 {가능/불가})\n상태: {상태}\n거래: {직거래 장소} 또는 택배\n연락: {연락처}",
                    impact: "여러 플랫폼에 붙여넣기 한 번, 문의 대응이 빨라집니다.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "긴급 연락처·가족 정보",
                    pain: "병원 접수·서류 작성 때 보호자 연락처와 정보를 매번 떠올립니다.",
                    example: "보호자: {이름} ({관계})\n연락처: {전화번호}\n혈액형: {혈액형}\n특이사항/알레르기: {내용}",
                    impact: "급한 순간에 정확한 정보를 바로, 당황 대신 침착하게 대응합니다.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "병원·예약 정보",
                    pain: "예약 문의·접수 때 이름·생년월일·증상을 매번 정리해 전합니다.",
                    example: "예약 문의드립니다.\n이름: {이름} / 생년월일: {생년월일}\n증상: {증상}\n희망 일시: {날짜} {시간}",
                    impact: "정리된 문의로 통화가 짧아지고, 원하는 시간을 잡기 쉬워집니다.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "와이파이 비번 공유",
                    pain: "손님이 올 때마다 공유기 비밀번호를 불러주거나 사진 찾아 헤맵니다.",
                    example: "WiFi: {네트워크 이름}\n비밀번호: {비밀번호}\n편하게 쓰세요 😊",
                    impact: "한 번에 공유: \"비번 뭐예요\"를 세 번 반복하지 않아도 돼요.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "자주 쓰는 안부 인사",
                    pain: "명절·생일마다 비슷한 안부를, 매번 처음부터 고민해 씁니다.",
                    example: "{이름}님, {행사} 잘 보내고 계세요? 늘 건강하고 좋은 일만 가득하시길 바라요 😊",
                    impact: "마음은 담되 시간은 아껴, 챙길 사람을 더 많이 챙기게 됩니다.",
                    feature: .template
                )
            ]
        )
    ]

    // =====================================================================
    // MARK: - English (en / default)
    // =====================================================================

    static let english: [PersonaGuide] = [

        // -------------------------------------------------------- Nomad
        PersonaGuide(
            persona: .nomad,
            intro: "You hop between cafés and co-working spaces, working with clients across the world. Timezones, international transfers, visas, near-identical English emails: your day leaks away hunting for the same details in another tab. Save each one once, and from then on it's a single tap.",
            scenarios: [
                PersonaScenario(
                    title: "\"Send your banking details\"",
                    pain: "One line from a client sends you digging through your bank app for the IBAN and SWIFT again.",
                    example: "Name: {your name}\nIBAN: {IBAN}\nSWIFT/BIC: {SWIFT}\nBank address: {bank address}\nWise: {Wise email}",
                    impact: "A 30-second hunt becomes one tap, and no more transposed digits.",
                    feature: .stack
                ),
                PersonaScenario(
                    title: "Timezone reply",
                    pain: "A 2 a.m. \"Can we hop on a call?\" and you're explaining your timezone yet again.",
                    example: "Hi {client}, I'm in GMT+{offset} ({city}) right now. I can do {time window}. Calendly: {link}",
                    impact: "Three back-and-forth messages collapse into one clear answer.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Sending an invoice",
                    pain: "You re-type the invoice number, amount, currency, and due date every single time.",
                    example: "Invoice #{no} · {currency} {amount}\nDue: {due date}\nPayment: Wise ({email})\nThank you! 🙏",
                    impact: "The template catches the fields you'd forget: fewer re-bills and corrections.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Proposal follow-up",
                    pain: "Three days of silence, and writing a nudge that doesn't feel pushy is hard every time.",
                    example: "Hi {client}, just following up on the proposal I sent {day}. Happy to jump on a quick call if anything needs clarifying.\n\nBest, {name}",
                    impact: "A polite follow-up you send instantly, rescuing deals you used to let slip.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Passport & visa info",
                    pain: "Every flight, stay, or visa form has you hunting for your passport number and expiry.",
                    example: "Passport no: {passport}\nFull name: {name}\nIssued / Expires: {issued} / {expiry}\nNationality: {nationality}",
                    impact: "Lock it behind Face ID as a secure snippet, open only when you need it.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "\"Where are you based?\"",
                    pain: "A new client asks casually, and you over-explain the nomad thing every time.",
                    example: "Based nowhere in particular: currently in {city}. I work async-first, so timezones rarely matter, but I'll always give you a clear window when I'm reachable.",
                    impact: "One confident, professional answer instead of sounding unsettled.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Wifi dropped",
                    pain: "The co-working wifi dies right before a call and you scramble for an apology.",
                    example: "Hi team, wifi at my co-working just dropped. Moving to a backup spot: back online in {min} min. Ready to continue right after. 🙏",
                    impact: "Even mid-panic, you send a calm, reassuring line in a second.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Currency & quote note",
                    pain: "Quoting a client in another currency means re-writing the FX caveat each time.",
                    example: "Quote: {currency} {amount} (≈ {converted} at today's rate).\nInvoiced in {currency} via Wise to keep fees low for you.",
                    impact: "Head off price confusion early, no haggling at payment time.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "New client onboarding",
                    pain: "Right after signing, you walk every client through Calendly, Slack, payment, cadence.",
                    example: "Welcome aboard, {client}! Here's how we'll work:\n1. First sync: Calendly: {link}\n2. Payment (banking info attached if needed)\n3. Slack invite within 24h\n4. Progress demos every Thursday\n\nExcited to get started!",
                    impact: "A Combo pastes several snippets in order, onboarding drops from 5 minutes to 5 seconds.",
                    feature: .stack
                ),
                PersonaScenario(
                    title: "Signing off for the night",
                    pain: "A 10 p.m. urgent DM, and saying \"not now\" politely is awkward every time.",
                    example: "Hi! Signing off for the night ({time} in {city}). I'll reply first thing in my morning, thanks for your patience 🙏",
                    impact: "Hold your boundary without seeming rude: trust intact, burnout avoided.",
                    feature: .template
                )
            ]
        ),

        // -------------------------------------------------------- Business
        PersonaGuide(
            persona: .business,
            intro: "Meetings, reports, replies: you rewrite the same phrases dozens of times a day. \"Please confirm,\" meeting invites, out-of-office notes. Save the polite, repeated lines once, and spend your focus on the work, not the wording.",
            scenarios: [
                PersonaScenario(
                    title: "Out-of-office reply",
                    pain: "Every trip means rewriting your away note, and forgetting the backup contact.",
                    example: "Hello, I'm out of office from {start} to {end}.\nFor anything urgent, please reach {contact} ({phone}).\nI'll reply in order once I'm back. Thank you.",
                    impact: "No gaps in coverage, and no inbox avalanche waiting when you return.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Meeting invite",
                    pain: "You retype the date / place / agenda format for every single meeting.",
                    example: "Hi {name},\nRequesting a meeting as follows:\n📅 {date} {time}\n📍 {place}\n📌 Agenda: {agenda}\nPlease confirm if you can join 😊",
                    impact: "A clean invite means fewer re-confirmations and far fewer no-shows.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Weekly status report",
                    pain: "Every week you start the same report format from a blank screen.",
                    example: "Hi team, this week's update:\n✅ Done: {done}\n🔄 In progress: {in progress}\n📋 Next week: {planned}\nHappy to discuss anything above.",
                    impact: "Format fixed, just fill the content. Friday evenings get lighter.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Intro & business card",
                    pain: "Every first introduction has you re-typing your role, team, and contact.",
                    example: "Hi, I'm {name}.\nI handle {role} at {company}.\n📧 {email} / 📞 {phone}\nLooking forward to working together 🙏",
                    impact: "A consistent intro builds trust, and no dropped contact from a typo.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Email signature",
                    pain: "Signatures don't carry across mail apps, so you paste yours by hand.",
                    example: "{name}\n{title} | {company}\n📧 {email}\n📞 {phone}\n🌐 {website}",
                    impact: "One signature, any app or device: your brand impression stays sharp.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Payment & tax details",
                    pain: "Every time a vendor asks for account or tax info, you dig through finance files.",
                    example: "Account: {bank} {number} ({holder})\nTax ID: {tax id}\nCompany: {company}\nInvoice email: {email}",
                    impact: "Send it exactly right, instantly: no delayed or misdirected payments.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Partnership outreach",
                    pain: "Proposing a collaboration, that polite opening line is always the hard part.",
                    example: "Hi {name},\nReaching out about a possible collaboration on {project}.\nI handle {role} at {company/name}.\nWould a quick call work? Let me know a time that suits you. Thanks!",
                    impact: "The first sentence you agonized over is ready, so you actually reach out more.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Apologizing for a late reply",
                    pain: "When you're slow to respond, asking forgiveness without sounding careless is delicate.",
                    example: "Hi {name}, apologies for the delayed reply. {reason} held things up. I'll get back to you with details by {date}. Thanks for your patience.",
                    impact: "A line that earns trust instead of silence, the relationship stays intact.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Project wrap-up thanks",
                    pain: "The better the project went, the more you delay the thank-you and miss the moment.",
                    example: "Hi {name},\nThank you sincerely for working together on {project}.\nWe reached a great outcome because of you.\nI'd love to keep the door open for what's next 😊",
                    impact: "Never miss the note that turns a project into the next one, repeat work follows.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Billing & settlement",
                    pain: "Month-end means assembling the statement and account details by hand again.",
                    example: "Hi! Here's the {month} statement.\nAmount: {amount} (incl. tax)\nAccount: {bank} {number} ({holder})\nPlease confirm 😊",
                    impact: "A format-perfect bill means no rewrites, and you get paid faster.",
                    feature: .template
                )
            ]
        ),

        // -------------------------------------------------------- Student
        PersonaGuide(
            persona: .student,
            intro: "Student ID, school email, assignment cover sheets, group-project notices: campus life is one repeated form after another. Save your professor emails, group settle-ups, and apartment address, and you win back time for studying and for yourself.",
            scenarios: [
                PersonaScenario(
                    title: "Student ID + name",
                    pain: "Course registration, submissions, certificates: you re-type your ID and name each time.",
                    example: "{major} {student ID} {name}",
                    impact: "One tap into any field, no last-minute typo costing you points.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Email to a professor",
                    pain: "Professor emails demand a polite tone, so the first line makes you tense every time.",
                    example: "Dear Professor, this is {name} ({student ID}), from {major}.\nI'm enrolled in {course} (section {no}).\nI'm writing regarding {topic}.\nSorry to bother you, and thank you.",
                    impact: "Fill in the point, format's handled: you stop putting off emails.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Assignment cover sheet",
                    pain: "Every course wants a different cover format, so you fuss with it right before the deadline.",
                    example: "Course: {course}\nProfessor: {professor}\nSubmitted by: {major} {student ID} {name}\nDate: {date}\nTopic: {topic}",
                    impact: "Format saved, content refreshed: one layer of deadline stress gone.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Group-project notice",
                    pain: "Posting the meeting time and role split to the team chat is a chore every round.",
                    example: "[{assignment}] Team notice 📢\nNext meeting: {date} {time} @ {place/link}\nBring: {items}\nDeadline: {due}\nReact 👍 once you've seen this!",
                    impact: "A tidy notice ends the \"wait, when was it?\" and keeps the team moving.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Apartment / dorm address",
                    pain: "Every delivery has you re-entering the full address and door code.",
                    example: "{postcode}\n{address}\n{unit details}\nEntry code: {code}\nRecipient: {name} / {phone}",
                    impact: "One tap into the delivery app, no packages lost to a wrong address.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Splitting the bill",
                    pain: "Collecting money for supplies or a team dinner means recalculating and posting it each time.",
                    example: "Total was {total} for {people} people, so {per person} each 🙏\nSend to {bank} {number} ({name}) please~",
                    impact: "Send the split instantly: and the money talk feels a lot less awkward.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Absence notice",
                    pain: "When you're sick, the note to a professor or TA won't come to mind exactly when it's urgent.",
                    example: "Dear Professor, this is {name} ({student ID}).\nI have to miss {course} on {date} due to {reason}.\nI'll submit documentation via {method}. My apologies.",
                    impact: "Even flustered, you send a courteous heads-up right away: less penalty.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Club / study recruiting",
                    pain: "Posting a recruit call across communities means rewriting the intro slightly each time.",
                    example: "[{group}] Looking for members! 🙌\nWhat we do: {activity}\nWhen: {day/time}\nWhere: {place}\nApply: {link/contact}\nReach out anytime 😊",
                    impact: "Paste the same post everywhere in one tap, recruiting moves much faster.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Internship application basics",
                    pain: "Every application repeats your name, contact, education, and links until you're worn out.",
                    example: "{name} · {phone} · {email}\n{school} {major} (year {year})\nPortfolio: {link}\nGitHub/blog: {link}",
                    impact: "Filling forms gets fast, so you apply to more opportunities.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Running late",
                    pain: "When you're late to class or a friend, guilt makes the message longer and longer.",
                    example: "So sorry! I'll be about {min} min late. Almost there 🙏",
                    impact: "A short, sure message eases the waiting person right away.",
                    feature: .template
                )
            ]
        ),

        // -------------------------------------------------------- General
        PersonaGuide(
            persona: .general,
            intro: "The basics you use every day: account number, home address, phone number, the greetings you send often. No more digging through memory or old chats; when the moment comes, it's a single tap. Small on their own, these add up to real time across a day.",
            scenarios: [
                PersonaScenario(
                    title: "Sharing an account number",
                    pain: "\"What's your account?\" and you open the bank app to check and copy the number.",
                    example: "{bank} {account number}\nHolder: {name}\n(Apple Pay / transfer also fine 🙏)",
                    impact: "One tap, exactly right: no wrong digits sending money astray.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Home address (delivery)",
                    pain: "Shopping and resale both make you re-type the full address and contact.",
                    example: "{postcode}\n{address}\n{unit details}\nRecipient: {name} / {phone}",
                    impact: "Address entry done in one go, fewer misdeliveries eating your time.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Making plans",
                    pain: "Every meet-up means writing a fresh message to sort time and place.",
                    example: "How about {place} at {time} on {date}? If not, tell me what works 😊",
                    impact: "Leading with a concrete offer gets plans locked in much faster.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Running late",
                    pain: "Each time you're late, guilt has you rewriting the apology at length.",
                    example: "So sorry! I'll be about {min} min late. Go ahead without me 🙏",
                    impact: "A quick note sent right away puts the waiting person at ease.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Event account (gifts/condolences)",
                    pain: "When someone asks for the gift or condolence account, you scramble for the number.",
                    example: "Thank you for the kind thought.\n{bank} {account number} ({holder})\nYour presence alone means so much 🙏",
                    impact: "Even in a hectic moment, you share it correctly and graciously.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Resale listing",
                    pain: "Every sale has you rewriting price, condition, and meet-up spot the same way.",
                    example: "Selling: {item}\nPrice: {price} (negotiable: {yes/no})\nCondition: {condition}\nMeet: {location} or shipping\nContact: {contact}",
                    impact: "Paste to any platform in one tap, you answer buyers faster.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Emergency & family info",
                    pain: "Hospital check-in and forms have you recalling guardian contact and details every time.",
                    example: "Guardian: {name} ({relation})\nPhone: {phone}\nBlood type: {blood type}\nNotes/allergies: {details}",
                    impact: "Accurate info in an urgent moment, calm response instead of panic.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Appointment / booking info",
                    pain: "Booking calls have you assembling name, birth date, and symptoms each time.",
                    example: "I'd like to book an appointment.\nName: {name} / DOB: {DOB}\nReason: {reason}\nPreferred: {date} {time}",
                    impact: "A tidy request shortens the call and lands the time you want.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Sharing wifi password",
                    pain: "Every guest means reading out the router password or hunting for a photo of it.",
                    example: "WiFi: {network name}\nPassword: {password}\nEnjoy 😊",
                    impact: "Share it once: no repeating \"what's the password?\" three times.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Go-to greetings",
                    pain: "Holidays and birthdays have you drafting a similar note from scratch each time.",
                    example: "Hi {name}, hope your {occasion} is wonderful! Wishing you good health and only good things ahead 😊",
                    impact: "Heartfelt but quick: so you actually reach everyone you meant to.",
                    feature: .template
                )
            ]
        )
    ]

    // =====================================================================
    // MARK: - Bahasa Indonesia (id)
    // =====================================================================

    static let indonesian: [PersonaGuide] = [

        // -------------------------------------------------------- Nomad
        PersonaGuide(
            persona: .nomad,
            intro: "Berpindah dari kafe ke co-working sambil bekerja dengan klien lintas negara. Zona waktu, transfer internasional, visa, email berbahasa Inggris yang mirip-mirip: waktumu habis mencari info yang sama di tab lain. Simpan sekali, setelah itu cukup satu ketukan.",
            scenarios: [
                PersonaScenario(
                    title: "Diminta info rekening",
                    pain: "Satu baris \"Send your banking details\" bikin kamu bongkar app bank lagi cari IBAN dan SWIFT.",
                    example: "Name: {nama}\nIBAN: {IBAN}\nSWIFT/BIC: {SWIFT}\nBank address: {alamat bank}\nWise: {email Wise}",
                    impact: "Pencarian 30 detik jadi satu ketukan, tanpa risiko salah digit.",
                    feature: .stack
                ),
                PersonaScenario(
                    title: "Menjelaskan zona waktu",
                    pain: "Pukul 2 pagi ada \"Can we call?\" dan kamu menjelaskan zona waktumu lagi.",
                    example: "Hi {klien}, I'm in GMT+{selisih} ({kota}) right now. I can do {rentang waktu}. Calendly: {tautan}",
                    impact: "Tiga kali bolak-balik pesan jadi satu jawaban yang jelas.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Kirim invoice",
                    pain: "Nomor invoice, jumlah, mata uang, tenggat: kamu ketik ulang tiap kali.",
                    example: "Invoice #{no} · {mata uang} {jumlah}\nDue: {tenggat}\nPayment: Wise ({email})\nTerima kasih! 🙏",
                    impact: "Template menahan bagian yang sering lupa, lebih sedikit tagih ulang.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Follow-up proposal",
                    pain: "Sudah 3 hari sepi, dan menulis pengingat yang tak terkesan memaksa itu sulit tiap kali.",
                    example: "Hi {klien}, just following up on the proposal I sent {hari}. Happy to jump on a quick call if anything needs clarifying.\n\nBest, {nama}",
                    impact: "Follow-up sopan langsung terkirim: menyelamatkan proyek yang biasanya lolos.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Data paspor & visa",
                    pain: "Tiap pesan tiket, hotel, atau visa, kamu cari nomor paspor dan tanggal kedaluwarsanya.",
                    example: "No. paspor: {paspor}\nNama lengkap: {nama}\nTerbit / Kedaluwarsa: {terbit} / {kedaluwarsa}\nKewarganegaraan: {kewarganegaraan}",
                    impact: "Kunci sebagai snippet aman (Face ID), buka hanya saat perlu.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "\"Kamu tinggal di mana?\"",
                    pain: "Klien baru bertanya santai, dan kamu menjelaskan soal nomad panjang lebar tiap kali.",
                    example: "Based nowhere in particular: currently in {kota}. I work async-first, so timezones rarely matter, but I'll always give you a clear window when I'm reachable.",
                    impact: "Satu jawaban percaya diri dan profesional, bukan terkesan tak menentu.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Wifi putus",
                    pain: "Wifi co-working mati tepat sebelum call, kamu buru-buru menyusun permintaan maaf.",
                    example: "Hi team, wifi at my co-working just dropped. Pindah ke lokasi cadangan: online lagi dalam {menit} menit. Siap lanjut setelahnya. 🙏",
                    impact: "Meski panik, kamu kirim satu baris yang tenang dan meyakinkan seketika.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Catatan kurs & penawaran",
                    pain: "Memberi penawaran dalam mata uang lain berarti menulis ulang catatan kurs tiap kali.",
                    example: "Penawaran: {mata uang} {jumlah} (≈ {konversi} kurs hari ini).\nDitagih dalam {mata uang} via Wise agar biayamu lebih rendah.",
                    impact: "Cegah salah paham harga sejak awal, tak ada tawar-menawar saat bayar.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Onboarding klien baru",
                    pain: "Sesudah deal, kamu memandu tiap klien soal Calendly, Slack, pembayaran, ritme kerja.",
                    example: "Selamat bergabung, {klien}! Beginilah kita bekerja:\n1. Sinkron pertama. Calendly: {tautan}\n2. Pembayaran (info rekening menyusul bila perlu)\n3. Undangan Slack dalam 24 jam\n4. Demo progres tiap Kamis\n\nSemangat mulai!",
                    impact: "Combo menempel beberapa snippet berurutan, onboarding dari 5 menit jadi 5 detik.",
                    feature: .stack
                ),
                PersonaScenario(
                    title: "Pamit di malam hari",
                    pain: "DM mendesak jam 10 malam, dan menolak dengan sopan itu canggung tiap kali.",
                    example: "Hi! Saya pamit dulu malam ini ({waktu} di {kota}). Akan saya balas pagi hari pertama, terima kasih atas pengertiannya 🙏",
                    impact: "Jaga batas tanpa terkesan kasar: kepercayaan tetap, burnout terhindar.",
                    feature: .template
                )
            ]
        ),

        // -------------------------------------------------------- Business
        PersonaGuide(
            persona: .business,
            intro: "Rapat, laporan, balasan: kamu menulis ulang kalimat yang sama puluhan kali sehari. \"Mohon dikonfirmasi,\" undangan rapat, pesan tidak di tempat. Simpan kalimat sopan yang berulang sekali saja, dan fokusmu untuk pekerjaannya, bukan kata-katanya.",
            scenarios: [
                PersonaScenario(
                    title: "Balasan otomatis cuti",
                    pain: "Tiap cuti atau dinas, kamu menulis ulang pesan absen dan lupa kontak pengganti.",
                    example: "Halo, saya tidak di tempat dari {mulai} sampai {selesai}.\nUntuk hal mendesak, hubungi {kontak} ({telepon}).\nAkan saya balas berurutan setelah kembali. Terima kasih.",
                    impact: "Tak ada celah pekerjaan, dan inbox tak meledak saat kamu kembali.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Undangan rapat",
                    pain: "Kamu mengetik ulang format tanggal / tempat / agenda untuk tiap rapat.",
                    example: "Halo {nama},\nMengundang rapat berikut:\n📅 {tanggal} {waktu}\n📍 {tempat}\n📌 Agenda: {agenda}\nMohon konfirmasi kehadiran 😊",
                    impact: "Undangan rapi berarti lebih sedikit konfirmasi ulang dan jauh lebih sedikit yang absen.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Laporan mingguan",
                    pain: "Tiap minggu kamu memulai format laporan yang sama dari layar kosong.",
                    example: "Halo tim, update minggu ini:\n✅ Selesai: {selesai}\n🔄 Berjalan: {berjalan}\n📋 Minggu depan: {rencana}\nSilakan bila ada yang mau dibahas.",
                    impact: "Format tetap, tinggal isi konten. Jumat sore terasa lebih ringan.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Perkenalan & kartu nama",
                    pain: "Tiap perkenalan pertama, kamu mengetik ulang jabatan, tim, dan kontak.",
                    example: "Halo, saya {nama}.\nSaya menangani {peran} di {perusahaan}.\n📧 {email} / 📞 {telepon}\nSenang bisa bekerja sama 🙏",
                    impact: "Perkenalan konsisten membangun kepercayaan: tanpa kontak salah ketik.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Tanda tangan email",
                    pain: "Tanda tangan tak terbawa antar aplikasi email, jadi kamu tempel manual.",
                    example: "{nama}\n{jabatan} | {perusahaan}\n📧 {email}\n📞 {telepon}\n🌐 {website}",
                    impact: "Satu tanda tangan, aplikasi atau perangkat mana pun: kesan brand tetap rapi.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Info rekening & pajak",
                    pain: "Tiap vendor minta info rekening atau NPWP, kamu bongkar berkas keuangan.",
                    example: "Rekening: {bank} {nomor} a/n {pemilik}\nNPWP: {npwp}\nPerusahaan: {perusahaan}\nEmail invoice: {email}",
                    impact: "Kirim persis benar, seketika: tak ada bayaran telat atau salah tujuan.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Ajakan kerja sama",
                    pain: "Mengajukan kolaborasi, kalimat pembuka yang sopan selalu jadi bagian tersulit.",
                    example: "Halo {nama},\nSaya menghubungi soal kemungkinan kerja sama pada {proyek}.\nSaya menangani {peran} di {perusahaan/nama}.\nBisa call singkat? Beri tahu waktu yang cocok. Terima kasih!",
                    impact: "Kalimat pertama yang bikin ragu sudah siap, jadi kamu lebih sering menawarkan.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Minta maaf balas telat",
                    pain: "Saat balasanmu lambat, minta maaf tanpa terkesan cuek itu rumit.",
                    example: "Halo {nama}, mohon maaf balasannya telat. {alasan} membuat prosesnya tertunda. Saya kabari detailnya paling lambat {tanggal}. Terima kasih atas pengertiannya.",
                    impact: "Satu baris yang membangun kepercayaan, bukan kesunyian: hubungan tetap terjaga.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Terima kasih akhir proyek",
                    pain: "Makin lancar proyeknya, makin kamu tunda ucapan penutup sampai kelewat momennya.",
                    example: "Halo {nama},\nTerima kasih tulus sudah bekerja sama di {proyek}.\nHasil baik ini berkat Anda.\nSemoga kita bisa lanjut untuk hal berikutnya 😊",
                    impact: "Jangan lewatkan pesan yang mengubah satu proyek jadi proyek berikutnya.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Penagihan & penyelesaian",
                    pain: "Akhir bulan berarti menyusun rincian dan info rekening dengan tangan lagi.",
                    example: "Halo! Ini rincian bulan {bulan}.\nJumlah: {jumlah} (termasuk pajak)\nRekening: {bank} {nomor} a/n {pemilik}\nMohon dikonfirmasi 😊",
                    impact: "Tagihan tanpa salah format berarti tanpa tulis ulang, dan kamu dibayar lebih cepat.",
                    feature: .template
                )
            ]
        ),

        // -------------------------------------------------------- Student
        PersonaGuide(
            persona: .student,
            intro: "NIM, email kampus, lembar sampul tugas, pengumuman tugas kelompok: hidup kampus adalah rentetan formulir berulang. Simpan email ke dosen, patungan kelompok, sampai alamat kos, dan kamu dapat lebih banyak waktu untuk belajar dan untuk dirimu.",
            scenarios: [
                PersonaScenario(
                    title: "NIM + nama",
                    pain: "KRS, pengumpulan tugas, surat keterangan: kamu ketik ulang NIM dan nama tiap kali.",
                    example: "{jurusan} {NIM} {nama}",
                    impact: "Satu ketukan ke kolom mana pun, tanpa salah ketik jelang tenggat.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Email ke dosen",
                    pain: "Email ke dosen butuh nada sopan, jadi kalimat pertama bikin tegang tiap kali.",
                    example: "Selamat pagi Bapak/Ibu, saya {nama} ({NIM}) dari {jurusan}.\nSaya mengambil {mata kuliah} (kelas {kelas}).\nSaya ingin menanyakan {perihal}.\nMohon maaf mengganggu, terima kasih.",
                    impact: "Tinggal isi perihal, format beres: kamu berhenti menunda kirim email.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Lembar sampul tugas",
                    pain: "Tiap mata kuliah minta format sampul berbeda, jadi ribet menjelang tenggat.",
                    example: "Mata kuliah: {mata kuliah}\nDosen: {dosen}\nOleh: {jurusan} {NIM} {nama}\nTanggal: {tanggal}\nTopik: {topik}",
                    impact: "Format tersimpan, konten diperbarui: satu lapis stres tenggat hilang.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Pengumuman tugas kelompok",
                    pain: "Memposting jadwal rapat dan pembagian tugas ke grup itu merepotkan tiap kali.",
                    example: "[{tugas}] Pengumuman tim 📢\nRapat berikutnya: {tanggal} {waktu} @ {tempat/tautan}\nSiapkan: {bahan}\nTenggat: {tenggat}\nBeri 👍 kalau sudah baca!",
                    impact: "Pengumuman rapi menghentikan \"kapan ya?\" dan tim tetap jalan.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Alamat kos / asrama",
                    pain: "Tiap pesan antar, kamu masukkan lagi alamat lengkap dan kode pintu.",
                    example: "{kode pos}\n{alamat}\n{detail unit}\nKode masuk: {kode}\nPenerima: {nama} / {telepon}",
                    impact: "Satu ketukan ke aplikasi pesan-antar, tak ada paket nyasar.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Patungan kelompok",
                    pain: "Mengumpulkan uang bahan atau makan bareng berarti hitung ulang dan posting tiap kali.",
                    example: "Total tadi {total} untuk {orang} orang, jadi {per orang} per orang ya 🙏\nTransfer ke {bank} {nomor} a/n {nama}~",
                    impact: "Kirim rincian patungan seketika: dan bahas uang jadi tak secanggung itu.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Izin tidak hadir",
                    pain: "Saat sakit, pesan ke dosen atau asisten tak terpikir tepat saat dibutuhkan.",
                    example: "Selamat pagi Bapak/Ibu, saya {nama} ({NIM}).\nSaya tidak bisa hadir di {mata kuliah} pada {tanggal} karena {alasan}.\nBukti akan saya kirim via {cara}. Mohon maaf.",
                    impact: "Meski panik, kamu kirim izin yang sopan seketika: mengurangi kerugian nilai.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Rekrut klub / kelompok belajar",
                    pain: "Memposting ajakan ke banyak komunitas berarti menulis ulang perkenalan tiap kali.",
                    example: "[{nama grup}] Mencari anggota! 🙌\nKegiatan: {kegiatan}\nWaktu: {hari/jam}\nTempat: {tempat}\nDaftar: {tautan/kontak}\nJangan ragu bertanya 😊",
                    impact: "Tempel pesan yang sama ke mana-mana dalam satu ketukan, rekrutmen jauh lebih cepat.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Data lamaran magang",
                    pain: "Tiap lamaran mengulang nama, kontak, pendidikan, tautan sampai kamu lelah.",
                    example: "{nama} · {telepon} · {email}\n{kampus} {jurusan} (angkatan {tahun})\nPortofolio: {tautan}\nGitHub/blog: {tautan}",
                    impact: "Isi formulir jadi cepat, jadi kamu melamar ke lebih banyak peluang.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Terlambat / ubah janji",
                    pain: "Saat terlambat ke kelas atau teman, rasa bersalah bikin pesan makin panjang.",
                    example: "Maaf ya! Aku telat sekitar {menit} menit. Sudah hampir sampai 🙏",
                    impact: "Pesan singkat dan pasti langsung menenangkan yang menunggu.",
                    feature: .template
                )
            ]
        ),

        // -------------------------------------------------------- General
        PersonaGuide(
            persona: .general,
            intro: "Info dasar yang dipakai tiap hari: nomor rekening, alamat rumah, nomor telepon, sapaan yang sering dikirim. Tak perlu mengingat-ingat atau menggeledah chat lama; saat dibutuhkan, cukup satu ketukan. Kelihatannya sepele, tapi kalau dihitung sehari, itu waktu yang lumayan.",
            scenarios: [
                PersonaScenario(
                    title: "Bagikan nomor rekening",
                    pain: "\"Rekeningnya berapa?\" dan kamu buka app bank untuk cek lalu salin nomornya.",
                    example: "{bank} {nomor rekening}\nA/N: {nama}\n(Bisa juga GoPay/OVO 🙏)",
                    impact: "Satu ketukan, persis benar: tak ada salah digit bikin uang nyasar.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Alamat rumah (pengiriman)",
                    pain: "Belanja dan jual-beli sama-sama bikin kamu ketik ulang alamat lengkap dan kontak.",
                    example: "{kode pos}\n{alamat}\n{detail unit}\nPenerima: {nama} / {telepon}",
                    impact: "Isi alamat selesai sekali jalan, lebih sedikit salah kirim yang buang waktu.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Membuat janji",
                    pain: "Tiap mau ketemu, kamu tulis pesan baru untuk mengatur waktu dan tempat.",
                    example: "Gimana kalau di {tempat} jam {waktu} tanggal {tanggal}? Kalau nggak bisa, kabari waktu yang pas 😊",
                    impact: "Menawarkan opsi konkret duluan bikin janji cepat terkunci.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Kabar terlambat",
                    pain: "Tiap terlambat, rasa bersalah bikin kamu menulis ulang permintaan maaf panjang.",
                    example: "Maaf ya! Aku telat sekitar {menit} menit. Duluan aja nggak apa-apa 🙏",
                    impact: "Pesan cepat yang langsung terkirim menenangkan yang menunggu.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Rekening acara (kado/duka)",
                    pain: "Saat ada yang minta rekening kado atau duka, kamu buru-buru cari nomornya.",
                    example: "Terima kasih atas perhatiannya.\n{bank} {nomor rekening} a/n {nama}\nKehadiran Anda saja sudah sangat berarti 🙏",
                    impact: "Bahkan di momen sibuk, kamu berbagi dengan benar dan santun.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Iklan jual-beli",
                    pain: "Tiap jualan, kamu tulis ulang harga, kondisi, dan lokasi COD yang mirip.",
                    example: "Dijual: {barang}\nHarga: {harga} (nego: {bisa/tidak})\nKondisi: {kondisi}\nCOD: {lokasi} atau kirim\nKontak: {kontak}",
                    impact: "Tempel ke banyak platform sekali ketuk, kamu balas pembeli lebih cepat.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Kontak darurat & keluarga",
                    pain: "Pendaftaran rumah sakit dan formulir bikin kamu mengingat kontak wali tiap kali.",
                    example: "Wali: {nama} ({hubungan})\nTelepon: {telepon}\nGolongan darah: {golongan}\nCatatan/alergi: {detail}",
                    impact: "Info akurat di saat mendesak: tanggap dengan tenang, bukan panik.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Info janji / reservasi",
                    pain: "Telepon reservasi bikin kamu menyusun nama, tanggal lahir, dan keluhan tiap kali.",
                    example: "Saya ingin membuat janji.\nNama: {nama} / Tgl lahir: {tanggal lahir}\nKeluhan: {keluhan}\nWaktu diinginkan: {tanggal} {waktu}",
                    impact: "Permintaan yang rapi mempersingkat telepon dan memudahkan dapat jadwal.",
                    feature: .template
                ),
                PersonaScenario(
                    title: "Bagikan sandi wifi",
                    pain: "Tiap ada tamu, kamu bacakan sandi router atau cari-cari fotonya.",
                    example: "WiFi: {nama jaringan}\nSandi: {sandi}\nSilakan dipakai 😊",
                    impact: "Bagikan sekali: tak perlu ulang \"sandinya apa?\" tiga kali.",
                    feature: .snippet
                ),
                PersonaScenario(
                    title: "Sapaan andalan",
                    pain: "Hari raya dan ulang tahun bikin kamu menyusun pesan serupa dari nol tiap kali.",
                    example: "Halo {nama}, semoga {acara}-nya menyenangkan! Sehat selalu dan semoga hal-hal baik selalu menyertai 😊",
                    impact: "Tulus tapi cepat: jadi kamu benar-benar menyapa semua yang kamu niatkan.",
                    feature: .template
                )
            ]
        )
    ]
}

//
//  ChangelogView.swift
//  ClipKeyboard
//
//  변경사항(업데이트 기록) - 설정 > 도움말에서 언제든 다시 볼 수 있는 화면.
//
//  `WhatsNewView` 와의 역할 구분:
//   · WhatsNewView  = 업데이트 직후 **1회만** 뜨는 새 기능 소개(놓치면 다시 못 봄)
//   · ChangelogView = **상시 조회**용 버전별 기록. "그 기능이 언제 들어왔더라"에 답한다
//
//  ⚠️ 내용은 `docs/release-notes/<버전>.md` 의 App Store 문안과 **같은 문장**을 쓴다.
//     새 버전을 낼 때 이 파일 맨 위에 항목을 추가하고, 문자열을 ko/en 에 넣을 것.
//
//  ⚠️ 옛 버전 항목은 **기록에서 되살린 것**이라 출시일(released)이 nil 이다.
//     날짜를 지어내지 않는다. 그 버전의 전문은 docs/release-notes/ 에 있다.
//     (릴리즈 노트를 런타임에 읽지 않는 이유: docs/ 는 앱 번들에 포함되지 않는다)
//

import SwiftUI

/// 한 버전의 변경 기록.
struct ChangelogEntry: Identifiable {
    let version: String
    /// 출시일 (yyyy-MM-dd). 아직 안 나온 버전, 그리고 **기록에서 되살려 출시일을
    /// 모르는 옛 버전**은 nil. 화면에는 날짜 줄이 아예 안 나온다.
    let released: String?
    let highlights: [String]

    var id: String { version }
}

enum ChangelogData {

    /// 최신 버전이 위로 온다.
    /// ⚠️ 사용자에게 보이는 문장이므로 전부 NSLocalizedString 을 거친다.
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "5.1.0",
            released: nil,
            highlights: [
                // 지구본
                NSLocalizedString("지구본을 길게 누르면 이모지 키보드로 바로 갈 수 있어요. 다른 키보드를 함께 써도 됩니다", comment: "Changelog 5.1.0 emoji keyboard"),
                NSLocalizedString("갈래를 하나만 쓰셔도 지구본이 사라지지 않아요", comment: "Changelog 5.1.0 globe always visible"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.9",
            released: nil,
            highlights: [
                // 키보드
                NSLocalizedString("키보드에 보내기 키가 생겼어요. 단축어를 넣고 키보드를 바꾸지 않고 그 자리에서 보냅니다", comment: "Changelog 5.0.9 return key"),
                NSLocalizedString("잠근 단축어에 값이 여러 개면, 화살표로 고른 다음 인증해서 그 값만 넣어요", comment: "Changelog 5.0.9 secure combo pick"),
                // 사진
                NSLocalizedString("키보드에서 사진 단축어를 눌러도 붙여넣어지지 않던 것을 고쳤어요", comment: "Changelog 5.0.9 keyboard image paste"),
                NSLocalizedString("글과 사진을 함께 담은 단축어를 복사하면 사진이 빠지던 것을 고쳤어요", comment: "Changelog 5.0.9 mixed memo image"),
                // 앱 소개
                NSLocalizedString("설정에 '함께 쓰는 앱'이 생겼어요. 이어 쓰면 좋은 앱들을 장면으로 소개해요", comment: "Changelog 5.0.9 family apps"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.8",
            released: nil,
            highlights: [
                // 키보드
                NSLocalizedString("키보드에 지우기 키가 생겼어요. 오타 하나를 고치려고 다른 키보드로 건너갈 일이 없어요", comment: "Changelog 5.0.8 backspace key"),
                NSLocalizedString("붙여넣기 키를 길게 누르면 복사한 것 중 필요한 데까지만 골라 넣을 수 있어요", comment: "Changelog 5.0.8 partial paste"),
                NSLocalizedString("띄어쓰기가 없는 중국어와 일본어도 단어로 잘라서 보여드려요", comment: "Changelog 5.0.8 word split cjk"),
                NSLocalizedString("빈칸이 여러 개인 단축어를 채울 때, 지금 채우는 칸만 펼쳐요. 하나를 고르면 다음 칸이 저절로 펼쳐집니다", comment: "Changelog 5.0.8 compact placeholders"),
                NSLocalizedString("단축어를 추가할 때 빈 자리가 먼저 서고 그 위로 만들기 화면이 열려요. 어디에 생기는지 보여요", comment: "Changelog 5.0.8 new memo slot"),
                // 날짜 서식
                NSLocalizedString("날짜와 시간 서식을 직접 만들 수 있어요. 조각을 눌러 넣으면 오늘 날짜가 그 모양으로 바로 보여요", comment: "Changelog 5.0.8 custom date format"),
                // 번역
                NSLocalizedString("번역이 Apple Intelligence 없이도 동작해요. 쓸 수 있는 언어도 늘었어요", comment: "Changelog 5.0.8 translation"),
                // 언어
                NSLocalizedString("러시아어를 지원해요", comment: "Changelog 5.0.8 russian"),
                NSLocalizedString("중국어에서 여러 줄 안내가 첫 줄만 보이던 것을 고쳤어요", comment: "Changelog 5.0.8 chinese truncation"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.7",
            released: nil,
            highlights: [
                // 여러 개 고르기
                NSLocalizedString("여러 단축어를 한 번에 골라 카테고리로 옮기거나 지울 수 있어요", comment: "Changelog 5.0.7 bulk select"),
                NSLocalizedString("목록에서 두 손가락으로 톡 치면 고르는 화면이 열려요. 카드를 꾹 누른 판에도 같은 길이 있어요", comment: "Changelog 5.0.7 two finger tap"),
                NSLocalizedString("보이스오버를 쓰실 때는 두 손가락 탭이 열리지 않아요. 그 몸짓은 읽기를 멈추는 데 이미 쓰이니까요", comment: "Changelog 5.0.7 voiceover"),
                // 빈칸
                NSLocalizedString("빈칸에 적은 값은 이번에만 써요. 남길 값만 옆의 별을 누르면 돼요", comment: "Changelog 5.0.7 one off value"),
                NSLocalizedString("복사할 때 값이 저절로 저장되지 않아요. 한 번 쓰고 말 값으로 목록이 차던 것을 고쳤어요", comment: "Changelog 5.0.7 no auto save"),
                NSLocalizedString("빈칸 관리에서 값을 끌어 순서를 정할 수 있어요. 쓴다고 자리가 움직이지 않아요", comment: "Changelog 5.0.7 value order"),
                // 말
                NSLocalizedString("플레이스홀더와 변수로 갈려 있던 말을 빈칸 하나로 맞췄어요", comment: "Changelog 5.0.7 terminology"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.6",
            released: nil,
            highlights: [
                // 날짜·시간 모양
                NSLocalizedString("날짜와 시간이 사시는 곳의 모양으로 들어가요. 미국은 08/31/2026 과 9:57 PM, 영국은 31/08/2026 이에요", comment: "Changelog 5.0.6 date format"),
                NSLocalizedString("설정의 단축어에서 날짜 형식과 시간 형식을 직접 고를 수 있어요. 보기마다 오늘 날짜를 그 모양으로 그려서 보여드려요", comment: "Changelog 5.0.6 date picker"),
                // 저장할 때 카테고리
                NSLocalizedString("저장할 때 카테고리를 고를 수 있어요. 그 자리에서 새 카테고리도 만들어요", comment: "Changelog 5.0.6 save into category"),
                NSLocalizedString("저장한 뒤에는 그 단축어가 보이는 자리로 데려가요. 이미 보이고 있으면 화면을 옮기지 않아요", comment: "Changelog 5.0.6 reveal after save"),
                // 키보드 높이
                NSLocalizedString("키보드 높이를 기기의 기본 키보드에 맞췄어요. 올라올 때 높이가 튀던 것도 함께 없앴어요", comment: "Changelog 5.0.6 keyboard height"),
                NSLocalizedString("iOS 26 에서 지구본 줄과 배경색이 갈려 보이던 것을 고쳤어요. 두 부분이 한 장으로 이어져요", comment: "Changelog 5.0.6 ios26 chrome"),
                // 카테고리
                NSLocalizedString("카테고리가 저절로 늘어나지 않아요. 이제 직접 만드실 때만 생겨요", comment: "Changelog 5.0.6 category growth"),
                NSLocalizedString("맥에서 카테고리 탭이 사라지던 것과, 복원할 때 카테고리가 빠지던 것을 고쳤어요", comment: "Changelog 5.0.6 category sync"),
                // 목록·속도
                NSLocalizedString("카테고리를 넘길 때 목록이 번쩍이던 것을 없앴어요", comment: "Changelog 5.0.6 list flash"),
                NSLocalizedString("앱이 빨라졌어요. 켤 때 멎던 구간이 없어지고, 첫 10초에 쓰는 시간이 절반으로 줄었어요", comment: "Changelog 5.0.6 performance"),
                NSLocalizedString("영상을 만들 때와 글을 쓸 때 앱이 갑자기 닫히던 자리 둘을 고쳤어요", comment: "Changelog 5.0.6 crashes"),
                // 그 밖에
                NSLocalizedString("잠근 단축어에 자물쇠가 늘 보여요. 구분 표시를 꺼 두셔도 보입니다", comment: "Changelog 5.0.6 secure lock"),
                NSLocalizedString("새 단축어 화면을 접지 않아요. 만들 때도 고칠 때도 처음부터 다 펼쳐져 있어요", comment: "Changelog 5.0.6 unfolded editor"),
                NSLocalizedString("새 단축어 화면이 뜰 때 클립보드를 훔쳐보던 것을 없앴어요. 붙여넣기는 단추로 서 있어요", comment: "Changelog 5.0.6 no clipboard peek"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.5",
            released: nil,
            highlights: [
                // 중국어 · 언어 고르기
                NSLocalizedString("중국어를 넣었어요. 간체와 번체 두 벌이고, 앱 이름도 함께 바뀌어요", comment: "Changelog 5.0.5 chinese"),
                NSLocalizedString("번체는 글자만 바꾼 게 아니에요. 대만에서 쓰는 말과 인용부호로 적고, 예시의 은행·주소도 그 지역 것으로 바꿨어요", comment: "Changelog 5.0.5 traditional"),
                NSLocalizedString("설정에서 언어를 고를 수 있어요. 고르는 즉시 바뀌고, 키보드는 다음에 열 때부터 따라와요", comment: "Changelog 5.0.5 language picker"),

                // 키보드 순서
                NSLocalizedString("키보드 안에서 문구 순서를 바꿔요. 순서를 고치려고 앱까지 다녀와야 하면 대개 안 고치니까요", comment: "Changelog 5.0.5 keyboard reorder"),
                NSLocalizedString("보이는 것 전체를 한 줄로 늘어놓고 옮겨요. 1번 페이지의 것을 2번 페이지 맨 위로 보낼 수 있어요", comment: "Changelog 5.0.5 reorder across pages"),

                // 빈칸 관리
                NSLocalizedString("빈칸 이름을 바꿀 수 있어요. 그 이름을 쓰는 단축어의 내용도 함께 바뀌고, 몇 개가 바뀌는지 먼저 보여드려요", comment: "Changelog 5.0.5 rename blank"),
                NSLocalizedString("쓰는 단축어가 없는 빈칸은 지울 수 있어요. 쓰는 곳이 있는 빈칸은 지워도 되살아나서 삭제를 내놓지 않아요", comment: "Changelog 5.0.5 delete blank"),

                // 고친 것
                NSLocalizedString("단축어를 만들다 이어지는 단계를 지울 때 앱이 죽던 것을 고쳤어요", comment: "Changelog 5.0.5 continuation crash"),

                // 피드백 · 별점
                NSLocalizedString("의견을 보내실 때 답장 받을 이름과 이메일을 적을 수 있어요. 적어 두면 다음에 자동으로 채워드려요", comment: "Changelog 5.0.5 feedback contact"),
                NSLocalizedString("별점은 키보드에서 한 번이라도 붙여넣어 보신 뒤에 여쭤봐요", comment: "Changelog 5.0.5 review gate"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.4",
            released: nil,
            highlights: [
                // 공유 영상 - 바꿔 말하기
                NSLocalizedString("친구들에게 알리기 영상에서 큰 자리에 아낀 시간 대신 그걸 빗댄 것이 서요. 12.5km 달리기, 드라마 8편, 책 3권, 마라톤 4번처럼요", comment: "Changelog 5.0.4 share video equivalents"),
                NSLocalizedString("열 가지 중에서 열 때마다 다른 것이 뽑혀요. 마음에 안 들면 다른 걸로 버튼으로 굴려 볼 수 있어요", comment: "Changelog 5.0.4 reroll"),
                NSLocalizedString("돈으로 셈하는 것은 사는 나라의 최저임금과 물건값을 봐요. 사는 곳의 값을 모르면 그 갈래는 아예 안 나와요", comment: "Changelog 5.0.4 local prices"),
                NSLocalizedString("아낀 시간과 실제 횟수는 아래에 작게 남아요. 큰 글씨는 어림한 것이고 그 줄만 실제로 센 것이라서요", comment: "Changelog 5.0.4 footer stays"),

                // 설정·페르소나
                NSLocalizedString("배경 이미지를 설정에서도 직접 넣고 지울 수 있어요. 그동안 목록 화면 선택기에만 있던 길이에요", comment: "Changelog 5.0.4 background in settings"),
                NSLocalizedString("페르소나를 처음이 아니라 써 보고 나서 여쭤봐요. 단축어를 두 개 만드셨거나 카테고리를 하나 만드셨을 때 한 번만요", comment: "Changelog 5.0.4 persona later"),
                NSLocalizedString("그전까지는 일반으로 둬요. 예전 기본값이던 디지털 노마드는 앱이 출발한 자리지 쓰시는 분의 자리가 아니었어요", comment: "Changelog 5.0.4 persona general"),
                NSLocalizedString("설정에서 키보드 연습하기를 뺐어요. 바로 위 키보드 설정 가이드가 같은 일을 하고 있었어요", comment: "Changelog 5.0.4 practice removed"),
                NSLocalizedString("붙여넣기 알림 설정을 붙여넣기 알림 허용 끄기로 바꿨어요. 빈칸 관리·카테고리 관리·보관함도 나란히 모았어요", comment: "Changelog 5.0.4 settings rename"),

                // 사용 기록 카드
                NSLocalizedString("사용 기록의 축하 카드와 횟수 카드를 한 장으로 합쳤어요. 같은 말이 위아래로 두 번 적혀 있었어요", comment: "Changelog 5.0.4 merged card"),
                NSLocalizedString("빗대는 줄을 누르면 다른 것으로 바뀌어요. 영화 한 편이 안 와닿으면 30km 달리기, 드라마 4편, 커피 7잔으로요", comment: "Changelog 5.0.4 tap to cycle"),
                NSLocalizedString("체크 도장은 언제나 연두예요. 축하 카드의 도장만 혼자 키 컬러를 따라가고 있었어요", comment: "Changelog 5.0.4 green seal"),

                // 이미지 키
                NSLocalizedString("이미지 단축어 옆의 키가 눌리지 않던 것을 고쳤어요. 가로로 긴 사진이 자기 칸을 넘어 옆 키를 덮고 있었어요", comment: "Changelog 5.0.4 image key overflow"),
                NSLocalizedString("이미지 단축어의 둥근 모서리를 눌러도 이제 반응해요", comment: "Changelog 5.0.4 image key corners"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.3",
            released: nil,
            highlights: [
                // 키 컬러
                NSLocalizedString("설정에서 키 컬러를 고를 수 있어요. 일곱 가지 중에 고르면 앱과 키보드가 함께 그 색으로 바뀌어요", comment: "Changelog 5.0.3 key color"),
                NSLocalizedString("기본값은 아이폰이 쓰는 그 파랑이에요. 예전 주황은 테라코타로, 색을 아예 빼고 싶으면 먹으로 고르면 돼요", comment: "Changelog 5.0.3 default blue"),
                NSLocalizedString("화면 색조에서 옅게 섞여 있던 노란 기를 걷어냈어요. 삭제·저장·주의를 알리는 빨강·초록·노랑과 갈래 색은 그대로예요", comment: "Changelog 5.0.3 neutral tone"),
                NSLocalizedString("체크 표시는 언제나 연두예요. 골랐다는 말은 원래 자기 색을 갖고 있어서, 키 컬러를 따라가지 않아요", comment: "Changelog 5.0.3 check green"),

                // 스스로 배우는 것들
                NSLocalizedString("넣고 나서 매번 같은 자리로 커서를 옮겨 이어 쓰시면, 세 번째부터 커서를 그 자리에 세워 드려요. 본문은 한 글자도 고치지 않고, 단축어 편집에서 끌 수 있어요", comment: "Changelog 5.0.3 cursor memory"),
                NSLocalizedString("넣고 나서 매번 같은 자리를 고치시면 그 자리를 빈칸으로 만들지 물어봐요. 매번 같은 값으로 고치시면 저장해 둔 글을 그 값으로 바꿀지 물어봐요", comment: "Changelog 5.0.3 edit pattern"),
                NSLocalizedString("여러 줄을 붙여넣거나 손으로 줄줄이 만들고 계시면, 한 번에 정리하기를 그 자리에서 내놓아요", comment: "Changelog 5.0.3 bulk import nudge"),

                // 처음 쓰는 사람이 지나는 길
                NSLocalizedString("콤보를 배우는 자리를 다시 만들었어요. 값을 넣고 보내고, 오른쪽 화살표로 값을 바꾸고, 다시 넣고 보내는 데까지 데려가요", comment: "Changelog 5.0.3 combo tutorial"),
                NSLocalizedString("이 탭에 화면이 둘이라는 것을 한 번 짚어 드려요. 카드 목록과 키보드 화면을 오가는 두 가지 길을 같이 알려드려요", comment: "Changelog 5.0.3 switch hint"),
                NSLocalizedString("장과 장 사이 기다리는 시간을 3초로 줄였고, 그 동그라미를 누르면 곧바로 넘어가요", comment: "Changelog 5.0.3 countdown"),
                NSLocalizedString("붙여넣기 연습 화면을 뺐어요. 카드를 누른 순간 값은 이미 들어간 뒤였어요", comment: "Changelog 5.0.3 paste practice removed"),
                NSLocalizedString("템플릿을 배울 때 다 끝난 걸음의 키가 한 번 더 물결치던 것을 고쳤어요", comment: "Changelog 5.0.3 template ripple"),

                // 만드는 자리
                NSLocalizedString("단축어를 만들 때 내용 칸의 파란 버튼 줄을 접었어요. 쓸 때 채우는 칸을 누르면 펼쳐지고, 한 번 펼치면 그대로 남아요", comment: "Changelog 5.0.3 token bar drawer"),
                NSLocalizedString("첫 단축어를 만드는 자리까지 안내가 이어져요. 이름, 값을 가져오는 방법, 붙여넣을 내용, 저장까지 위에서부터 하나씩 짚어 드려요", comment: "Changelog 5.0.3 new snippet coach"),

                // 키보드 켜기 안내
                NSLocalizedString("키보드를 켜라는 안내가 더는 앞을 막지 않아요. 키보드 화면 위쪽에 띠로 남고, 다른 안내가 그 자리를 쓰고 있으면 비켜 있다가 자리가 비면 올라와요", comment: "Changelog 5.0.3 setup banner"),
                NSLocalizedString("키보드를 설정에서 뺐는데도 켜라는 안내가 다시는 안 뜨던 것을 고쳤어요. 이제 설정 목록을 그때그때 확인해요", comment: "Changelog 5.0.3 install state fix"),

                // 가리키는 표시
                NSLocalizedString("화면이 둘이라고 알려 드릴 때 위의 버튼과 아래 탭이 함께 빛나요. 콤보 키에서 잘려 나가던 물결도 고쳤어요", comment: "Changelog 5.0.3 highlight fix"),
                NSLocalizedString("키보드 화면이 아래로 사라질 때 끝에서 끌리던 것과 말풍선 꼬리 모양을 손봤어요", comment: "Changelog 5.0.3 stage polish"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.2",
            released: nil,
            highlights: [
                // 사진에서 글자 가져오기
                NSLocalizedString("사진을 찍고 필요한 글자 위를 손가락으로 문지르면 그 부분만 값으로 들어와요. 통장 사진에서 계좌번호만 집어 올 수 있어요", comment: "Changelog 5.0.2 smear to pick"),
                NSLocalizedString("문지르기 어려우면 읽은 줄을 목록에서 고를 수도 있어요", comment: "Changelog 5.0.2 smear fallback"),
                NSLocalizedString("붙여넣을 내용의 단추를 둘로 갈랐어요. 스캔해서 글자 넣기는 사진 속 글자만 가져오고, 이미지 붙이기는 사진을 그대로 담아요", comment: "Changelog 5.0.2 scan vs image"),

                // 멈춤
                NSLocalizedString("앱을 다시 열 때 잠깐 멈추던 것을 고쳤어요. 맥에서 복사한 것을 가져오느라 기다리던 자리를 화면 밖으로 옮겼어요", comment: "Changelog 5.0.2 pasteboard hang"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.1",
            released: nil,
            highlights: [
                NSLocalizedString("한 번 꺼내 쓸 때마다 적어도 2분은 아낀 것으로 세요. 깃 토큰처럼 갈래를 못 알아보는 값이 10초로 적히던 걸 고쳤어요", comment: "Changelog 5.0.1 baseline"),
                NSLocalizedString("손으로 쳐 넣은 계좌번호도 이제 계좌번호로 알아봐요. 클립보드에서 온 것만 갈래가 붙던 걸 고쳤어요", comment: "Changelog 5.0.1 resolve type"),
                NSLocalizedString("다른 앱에서 찾아오던 시간을 실제로 재 본 크기로 올렸어요. 은행 앱을 여는 건 28초에 끝나는 일이 아니었어요", comment: "Changelog 5.0.1 retrieval"),
                NSLocalizedString("같은 문구를 잇달아 쓰면 찾아오는 시간을 한 번만 세요. 한 번 꺼내 온 값은 이미 손에 있으니까요", comment: "Changelog 5.0.1 repeat"),
                NSLocalizedString("아주 긴 글은 손으로 옮겨 적었을 만큼까지만 세요. 탭 한 번에 20분을 아꼈다고 적지 않아요", comment: "Changelog 5.0.1 ceiling"),
                NSLocalizedString("사용 기록의 내역에 뺀 시간도 함께 적어서, 줄을 더해 보면 위의 숫자가 나와요", comment: "Changelog 5.0.1 reconcile"),
                NSLocalizedString("셈을 고치기 전에 쓴 기록도 새 셈으로 보여요. 기간마다 같은 한 번이 다른 금액으로 찍히던 걸 고쳤어요", comment: "Changelog 5.0.1 reprice"),
                NSLocalizedString("문구를 만드실 때 실제로 치는 속도를 재 두었다가 그 속도로 셈해요. 어림하던 것을 하나 줄였어요", comment: "Changelog 5.0.1 measured typing"),
                NSLocalizedString("영수증과 자랑 영상이 '센 횟수'를 앞에 두고 '어림한 시간'을 뒤에 둬요. 어느 쪽이 사실인지 밝혀요", comment: "Changelog 5.0.1 fact first"),

                // 자랑하기
                NSLocalizedString("영수증을 뽑으면 지금 보고 있던 기간이 그대로 찍혀요. 종이 한 장만 뜹니다", comment: "Changelog 5.0.1 receipt period"),
                NSLocalizedString("영수증과 영상을 공유하기 한 번으로 어디로든 보낼 수 있어요", comment: "Changelog 5.0.1 share"),
                NSLocalizedString("친구들에게 알리기를 누르면 영상을 먼저 보고 나서 보낼 수 있어요", comment: "Changelog 5.0.1 video preview"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.0",
            released: nil,
            highlights: [
                // 처음 오는 길
                NSLocalizedString("처음 쓰는 분께는 만들라고 하지 않고, 준비된 단축어를 하나씩 눌러보게 안내해요", comment: "Changelog 5.0.0 item 10"),
                NSLocalizedString("누를 곳마다 물결이 번져서 다음에 무엇을 할지 알 수 있어요", comment: "Changelog 5.0.0 ripple"),
                NSLocalizedString("셋을 눌러 본 뒤에는 직접 하나 만들어 보는 걸음으로 이어져요", comment: "Changelog 5.0.0 make own"),
                NSLocalizedString("연습용 단축어는 다 끝나면 치울지 한 번 물어봐요", comment: "Changelog 5.0.0 cleanup"),
                NSLocalizedString("키보드를 켠 것이 확인될 때까지 안내가 다시 떠요. 닫기만 해서는 끝나지 않아요", comment: "Changelog 5.0.0 keyboard nag"),
                NSLocalizedString("앱 안 키보드 미리보기에서 글이 한 글자씩 흘러 들어가요", comment: "Changelog 5.0.0 typing"),

                // 템플릿
                NSLocalizedString("빈칸마다 무슨 값인지 이름이 보이고, 칸이 따로 구분돼요", comment: "Changelog 5.0.0 blank names"),
                NSLocalizedString("값을 고르면 미리보기가 먼저 바뀌고, 입력하기를 눌러야 들어가요", comment: "Changelog 5.0.0 insert"),
                NSLocalizedString("오늘 날짜처럼 자동으로 채워지는 자리는 구멍이 아니라 값으로 보여요", comment: "Changelog 5.0.0 preview"),
                NSLocalizedString("저장된 값이 없으면 그 자리에서 바로 만들 수 있어요", comment: "Changelog 5.0.0 inline add"),
                NSLocalizedString("플레이스홀더 값 관리를 단축어 목록과 편집 화면에서 바로 열 수 있어요", comment: "Changelog 5.0.0 placeholder reach"),

                // 아낀 시간
                NSLocalizedString("아낀 시간을 다시 셌어요. 치는 시간만 세던 걸 고쳐서, 다른 앱에서 찾아와야 했던 값은 찾는 시간까지 셉니다", comment: "Changelog 5.0.0 item 3"),
                NSLocalizedString("찾은 뒤 선택하고 복사해서 돌아오는 손놀림도 이제 함께 세요", comment: "Changelog 5.0.0 handling"),
                NSLocalizedString("아낀 시간이 어떻게 계산됐는지 사용 기록에서 펼쳐 볼 수 있어요", comment: "Changelog 5.0.0 item 4"),
                NSLocalizedString("1분·5분·한 시간처럼 눈에 잡히는 만큼 아끼면 알려드려요", comment: "Changelog 5.0.0 item 5"),
                NSLocalizedString("아낀 시간을 3초짜리 세로 영상으로 뽑아 스토리에 올릴 수 있어요", comment: "Changelog 5.0.0 item 6"),
                NSLocalizedString("환급 영수증에서 픽셀 그림을 빼고 진짜 영수증처럼 바꿨어요", comment: "Changelog 5.0.0 item 7"),

                // 알려 주는 것들
                NSLocalizedString("며칠에 한 번, 아직 모르실 만한 기능을 하나씩 알려드려요", comment: "Changelog 5.0.0 dyk"),
                NSLocalizedString("고르신 쓰임새에 맞는 갈래와 문구를 골라 알려드려요", comment: "Changelog 5.0.0 persona"),
                NSLocalizedString("잠긴 단축어가 있는데 잠금 번호가 없으면 누르기 전에 알려드려요", comment: "Changelog 5.0.0 pin"),

                // 화면
                NSLocalizedString("목록 배경으로 내 사진을 쓸 수 있어요", comment: "Changelog 5.0.0 background"),
                NSLocalizedString("이렇게들 써요에서 사람을 고르면 그 사람 이야기만 따로 볼 수 있어요", comment: "Changelog 5.0.0 persona detail"),
                NSLocalizedString("키컬러를 주황으로 바꿔 눌러야 할 곳이 분명해졌어요", comment: "Changelog 5.0.0 accent"),
                NSLocalizedString("대비 증가를 켜면 흐린 글자와 선이 또렷해져요", comment: "Changelog 5.0.0 contrast"),
                NSLocalizedString("이름만 없던 버튼들에 이름을 붙여 보이스오버와 음성 제어로 부를 수 있어요", comment: "Changelog 5.0.0 a11y labels"),

                // 고친 것
                NSLocalizedString("앱을 다시 깔거나 새 폰을 켜도, 켜기 전에는 iCloud 데이터를 당겨오지 않아요", comment: "Changelog 5.0.0 sync consent"),
                NSLocalizedString("홈 화면 앱 이름과 아이콘을 바로잡았어요", comment: "Changelog 5.0.0 name icon"),
                NSLocalizedString("목록 탭에 들어갈 때 화면이 한 번 까매지던 것을 고쳤어요", comment: "Changelog 5.0.0 black flash"),
                NSLocalizedString("튜토리얼이 가리키는 단축어가 다른 페이지에 있어 안 보이던 것을 고쳤어요", comment: "Changelog 5.0.0 tutorial page"),
            ]
        ),
        ChangelogEntry(
            version: "4.4.8",
            released: nil,
            highlights: [
                NSLocalizedString("앱을 열다가 멈추던 문제를 고쳤어요. iCloud 준비를 첫 화면 그리는 일에서 떼어 놓았어요", comment: "Changelog 4.4.8 item 1"),
                NSLocalizedString("시작하다 문제가 생겨도 다음 실행은 열려요. 걸린 부분만 쉬고 화면부터 띄워요", comment: "Changelog 4.4.8 item 2"),
                NSLocalizedString("기기 간 동기화에서 처음 올린 뒤의 수정과 삭제가 반영되지 않던 문제를 고쳤어요", comment: "Changelog 4.4.8 item 3"),
                NSLocalizedString("이미지 단축어를 누르면 미리보기 입력창에 바로 붙고, 보내면 그대로 올라가요", comment: "Changelog 4.4.7 item 1"),
                NSLocalizedString("카테고리에 단축어가 들어 있으면 탭을 숨기기 전에 알려드리고, 다른 카테고리로 한 번에 옮길 수 있어요", comment: "Changelog 4.4.7 item 2"),
                NSLocalizedString("탭을 숨긴 카테고리의 단축어가 어디에도 보이지 않던 문제를 고쳤어요. 갈 수 있는 탭이 없으면 기본 탭에 모여요", comment: "Changelog 4.4.7 item 3"),
                NSLocalizedString("키를 길게 누르면 값이 키보드를 꽉 채워 보여요. 잠긴 단축어는 값을 보여주지 않아요", comment: "Changelog 4.4.7 item 4"),
                NSLocalizedString("설정을 열면 단축어를 몇 칸 더 만들 수 있는지 맨 위에 보여요", comment: "Changelog 4.4.7 item 5"),
                NSLocalizedString("탭을 한 번 더 누르면 단축어 목록과 키보드 화면이 오가요", comment: "Changelog 4.4.7 item 6"),
                NSLocalizedString("클립보드는 설정 > 내 데이터로, 사용 기록은 탭으로 자리를 바꿨어요", comment: "Changelog 4.4.7 item 7"),
                NSLocalizedString("설정을 하려는 일로 묶어 16개에서 8개로 정리했어요. 첫 화면은 한 줄로 접히고 현재 값이 보여요", comment: "Changelog 4.4.6 item 1"),
                NSLocalizedString("카테고리 아이콘은 카테고리 관리 안에서 바로 고를 수 있어요", comment: "Changelog 4.4.6 item 2"),
                NSLocalizedString("안정성 화면에 영문 오류 대신 지금 무엇을 기다리는 상태인지 알려드려요", comment: "Changelog 4.4.6 item 3"),
                NSLocalizedString("한꺼번에 가져올 때 저장하기 전에 키보드 모습으로 보여줘요. 키를 눌러 뺄 것만 빼면 돼요", comment: "Changelog 4.4.5 item 1"),
                NSLocalizedString("사진 속 글자를 값으로 바로 넣을 수 있어요. 읽은 줄에서 필요한 것만 고르면 돼요", comment: "Changelog 4.4.5 item 2"),
                NSLocalizedString("단축어 마트가 생겼어요. 상황을 고르고 빈칸만 내 것으로 채우면 바로 키보드에 들어가요", comment: "Changelog 4.4.5 item 4"),
                NSLocalizedString("제어센터와 위젯에서 앱을 열지 않고 바로 복사돼요. 제어센터에 '값 복사' 버튼을 추가해 보세요", comment: "Changelog 4.4.5 item 5"),
                NSLocalizedString("사파리 등에서 공유하면 바로 단축어로 담겨요. 앱에 들어가 한 번 더 누르지 않아도 돼요", comment: "Changelog 4.4.5 item 6"),
                NSLocalizedString("공유 시트 아래 목록의 '단축어로 저장'을 누르면 화면 없이 한 번에 담겨요", comment: "Changelog 4.4.5 item 7"),
                NSLocalizedString("체크해서 함께 쓰는 값들을 콤보 한 키로 묶을 수 있어요. 떨어져 있어도 묶여요", comment: "Changelog 4.4.5 item 3"),
                NSLocalizedString("앱을 열면 키보드가 올라온 모습 그대로, 눌러서 바로 써 볼 수 있어요", comment: "Changelog 4.4.4 item 1"),
                NSLocalizedString("설정 > 첫 화면에서 단축어 목록과 키보드 화면 중 고를 수 있어요(툴바 버튼으로 바로 전환)", comment: "Changelog 4.4.4 item 2"),
                NSLocalizedString("짧게 누르면 입력창에, 길게 누르면 클립보드로: 앱 안에서요", comment: "Changelog 4.4.4 item 4"),
                NSLocalizedString("처음 쓰신다면 단축어를 직접 하나 만들고, 눌러 써 봐야 다음으로 넘어가요", comment: "Changelog 4.4.4 item 3"),
                NSLocalizedString("템플릿 → 있는 걸 템플릿으로 바꾸기 → 콤보까지 차례로 익혀요(\"나중에\"를 고르면 다시 묻지 않아요)", comment: "Changelog 4.4.4 item 8"),
                NSLocalizedString("채우는 칸이 뭔지 같은 문장을 값만 바꿔 두 줄로 보여줘요. { } 기호는 어디서도 안 보여요", comment: "Changelog 4.4.4 item 9"),
                NSLocalizedString("연습으로 만든 단축어는 끝나고 지울지 한 번만 물어봐요(설정에서 다시 볼 수도 있어요)", comment: "Changelog 4.4.4 item 10"),
                NSLocalizedString("카테고리 탭과 좌우 넘기기가 처음부터 보여요", comment: "Changelog 4.4.4 item 5"),
                NSLocalizedString("붙여넣기 허용 팝업을 며칠 써 보신 뒤로 미뤘어요. 설치하자마자 묻지 않아요", comment: "Changelog 4.4.4 item 6"),
                NSLocalizedString("눌러 넣은 글이 사라지던 문제, 안내가 중간에 끊기던 문제, 카테고리 배경색이 없어진 문제를 고쳤어요", comment: "Changelog 4.4.4 item 7")
            ]
        ),
        ChangelogEntry(
            version: "4.4.7",
            released: nil,
            highlights: [
                NSLocalizedString("이미지 단축어를 누르면 무엇이 복사됐는지 바로 보여요", comment: "Changelog 4.4.7 item 1"),
                NSLocalizedString("키보드에서 길게 누르면 값이 크게 보여요", comment: "Changelog 4.4.7 item 2"),
                NSLocalizedString("카테고리를 정리하는 자리를 하나로 모았어요", comment: "Changelog 4.4.7 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.4.6",
            released: nil,
            highlights: [
                NSLocalizedString("앱을 열다가 멈추던 것을 고쳤어요. iCloud 준비가 첫 화면을 그리는 일과 같은 줄에 서 있었어요", comment: "Changelog 4.4.6 item 1"),
                NSLocalizedString("시작하다 문제가 생겨도 다음 실행은 열려요", comment: "Changelog 4.4.6 item 2"),
                NSLocalizedString("기기 사이 동기화에서 수정과 삭제가 반영되지 않던 것을 고쳤어요", comment: "Changelog 4.4.6 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.4.5",
            released: nil,
            highlights: [
                NSLocalizedString("제어센터와 위젯에서 앱을 열지 않고 바로 복사해요", comment: "Changelog 4.4.5 item 1"),
                NSLocalizedString("다른 앱에서 고른 글을 공유로 바로 단축어로 저장해요", comment: "Changelog 4.4.5 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.4.4",
            released: nil,
            highlights: [
                NSLocalizedString("앱을 열면 키보드가 올라온 모습이 그대로 보여요", comment: "Changelog 4.4.4 item 1"),
                NSLocalizedString("짧게 누르면 입력, 길게 누르면 복사예요", comment: "Changelog 4.4.4 item 2"),
                NSLocalizedString("단축어 마트에서 쓸 만한 문구를 골라 담을 수 있어요", comment: "Changelog 4.4.4 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.4.3",
            released: "2026-07-30",
            highlights: [
                NSLocalizedString("한 단축어에 여러 값: \"내용 더 넣기\"로 담고, 기존 단축어에서 값 가져오기도 가능", comment: "Changelog 4.4.3 item 1"),
                NSLocalizedString("앱에서 탭하면 값 목록에서 골라 복사, 키보드에선 2/3 분할로 값을 하나씩 입력", comment: "Changelog 4.4.3 item 2"),
                NSLocalizedString("이미지와 여러 값을 한 단축어에 함께 담을 수 있어요", comment: "Changelog 4.4.3 item 3"),
                NSLocalizedString("새 단축어 화면 정리, 채우기 버튼과 변수 설명이 또렷해졌어요", comment: "Changelog 4.4.3 item 4"),
                NSLocalizedString("기기 간 동기화(베타) 수정, 전송이 확정된 뒤에만 완료 처리해 누락을 막아요", comment: "Changelog 4.4.3 item 5")
            ]
        ),
        ChangelogEntry(
            version: "4.4.1",
            released: nil,
            highlights: [
                NSLocalizedString("콤보를 키보드에서 값 하나씩 골라 넣을 수 있어요", comment: "Changelog 4.4.1 item 1"),
                NSLocalizedString("이미 만들어 둔 단축어를 골라 콤보로 묶을 수 있어요", comment: "Changelog 4.4.1 item 2"),
                NSLocalizedString("키보드 검색창에 한글을 칠 때 글자가 깨지던 것을 고쳤어요", comment: "Changelog 4.4.1 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.4.0",
            released: "2026-07-23",
            highlights: [
                NSLocalizedString("맥에서 단축어 순서를 끌어다 바꾸고, 그 순서를 아이폰·키보드까지 동기화", comment: "Changelog 4.4.0 item 1"),
                NSLocalizedString("아이폰에서 바꾼 순서도 맥의 모든 화면에 그대로 반영", comment: "Changelog 4.4.0 item 2"),
                NSLocalizedString("키보드 검색에서 한글이 흩어지던 문제 수정, 이제 정확히 조합돼 찾아져요", comment: "Changelog 4.4.0 item 3"),
                NSLocalizedString("켜 둔 빈 카테고리도 탭으로 남아 스와이프로 바로 이동", comment: "Changelog 4.4.0 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.9",
            released: "2026-07-18",
            highlights: [
                NSLocalizedString("맑은 유리 카드와 배경 사진, 8가지 풍경이 탭마다 다르게 비쳐요", comment: "Changelog 4.3.9 item 1"),
                NSLocalizedString("한번에 가져오기 개편, 붙여넣으면 서비스명·아이디·비밀번호를 알아서 분리", comment: "Changelog 4.3.9 item 2"),
                NSLocalizedString("비밀번호·PIN·인증서는 가져올 때부터 자동으로 암호화되는 보안 단축어로", comment: "Changelog 4.3.9 item 3"),
                NSLocalizedString("사진·카메라에서 텍스트를 인식해 가져오기, 카드 사진은 번호와 유효기간만", comment: "Changelog 4.3.9 item 4"),
                NSLocalizedString("콤보가 쉬워졌어요. 값을 이어 붙이고 보안 콤보로 암호화 저장까지", comment: "Changelog 4.3.9 item 5")
            ]
        ),
        ChangelogEntry(
            version: "4.3.8",
            released: "2026-07-17",
            highlights: [
                NSLocalizedString("iOS 26 순정 디자인 전면 적용, 유리 탭바와 투명한 상단", comment: "Changelog 4.3.8 item 1"),
                NSLocalizedString("큰 제목이 스크롤에 따라 작아졌다 커지는 순정 타이틀 동작", comment: "Changelog 4.3.8 item 2"),
                NSLocalizedString("만들다 만 단축어만 임시저장, 열어만 봐도 쌓이던 문제 정리", comment: "Changelog 4.3.8 item 3"),
                NSLocalizedString("이미지와 이름만 넣은 단축어가 저장되지 않던 문제 해결", comment: "Changelog 4.3.8 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.7",
            released: "2026-07-14",
            highlights: [
                NSLocalizedString("메모 구분 표시를 꺼도 남아있던 카드 테두리까지 완전히 숨김", comment: "Changelog 4.3.7 item 1"),
                NSLocalizedString("홈 화면 작성 가이드 카드를 닫으면 조용히 사라져요", comment: "Changelog 4.3.7 item 2"),
                NSLocalizedString("붙여넣기 허용을 한 번에, 클립보드 화면에서 iOS 설정으로 바로 이동", comment: "Changelog 4.3.7 item 3"),
                NSLocalizedString("여러분이 남겨주신 피드백을 반영한 다듬기 업데이트", comment: "Changelog 4.3.7 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.6",
            released: nil,
            highlights: [
                NSLocalizedString("정규식으로 알아보기 어렵던 것을 기기 안의 AI가 다시 분류해요", comment: "Changelog 4.3.6 item 1"),
                NSLocalizedString("복사한 것에 맞는 단축 버튼이 붙어요. URL은 브라우저로, 주소는 지도로", comment: "Changelog 4.3.6 item 2"),
                NSLocalizedString("클립보드 글을 16개 언어로 기기 안에서 번역해요", comment: "Changelog 4.3.6 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.3.5",
            released: nil,
            highlights: [
                NSLocalizedString("제어센터에서 한 번 눌러 빠른 메모를 적어요", comment: "Changelog 4.3.5 item 1"),
                NSLocalizedString("잠금 화면과 홈 화면 위젯에서도 바로 적을 수 있어요", comment: "Changelog 4.3.5 item 2"),
                NSLocalizedString("카테고리에서 추가하면 그 카테고리로 저장돼요", comment: "Changelog 4.3.5 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.3.4",
            released: nil,
            highlights: [
                NSLocalizedString("데이터를 파일 하나로 내보내고 가져올 수 있어요. 사진까지 함께 담겨요", comment: "Changelog 4.3.4 item 1"),
                NSLocalizedString("백업이 무엇을 올렸는지 분명하게 알려줘요", comment: "Changelog 4.3.4 item 2"),
                NSLocalizedString("저장하는 도중 앱이 닫혀도 원본이 깨지지 않아요", comment: "Changelog 4.3.4 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.3.3",
            released: nil,
            highlights: [
                NSLocalizedString("iCloud 백업에 첨부 사진까지 담겨요", comment: "Changelog 4.3.3 item 1"),
                NSLocalizedString("새 기기에서 처음 열면 예전 단축어를 불러올 수 있다고 알려줘요", comment: "Changelog 4.3.3 item 2"),
                NSLocalizedString("아이폰과 맥에서 단축어를 함께 써요 (베타)", comment: "Changelog 4.3.3 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.3.2",
            released: nil,
            highlights: [
                NSLocalizedString("카드가 잠시 머물면 제목 아래에 내용이 살며시 맺혀요", comment: "Changelog 4.3.2 item 1"),
                NSLocalizedString("보여줄 한 줄을 직접 정할 수 있어요", comment: "Changelog 4.3.2 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.3.1",
            released: nil,
            highlights: [
                NSLocalizedString("템플릿을 누르면 그 자리에서 빈칸을 채워 복사해요", comment: "Changelog 4.3.1 item 1"),
                NSLocalizedString("단축어를 길게 눌러 템플릿으로 만들 수 있어요", comment: "Changelog 4.3.1 item 2"),
                NSLocalizedString("따로 있던 콤보를 단축어 목록 안으로 들여왔어요", comment: "Changelog 4.3.1 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.3.0",
            released: nil,
            highlights: [
                NSLocalizedString("단축어를 끌어서 순서를 바꿀 수 있어요", comment: "Changelog 4.3.0 item 1"),
                NSLocalizedString("종류별로 모아 보는 카테고리를 준비해 뒀어요", comment: "Changelog 4.3.0 item 2"),
                NSLocalizedString("모든 카테고리 끝에 추가 카드가 생겼어요", comment: "Changelog 4.3.0 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.2.2",
            released: nil,
            highlights: [
                NSLocalizedString("카테고리를 만들고 고치는 자리를 한곳으로 모았어요", comment: "Changelog 4.2.2 item 1"),
                NSLocalizedString("키보드에서 카테고리 색이 엉뚱하게 나오던 것을 고쳤어요", comment: "Changelog 4.2.2 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.2.1",
            released: nil,
            highlights: [
                NSLocalizedString("예전 유료 버전을 사신 분께 Pro 안내가 계속 뜨던 것을 고쳤어요", comment: "Changelog 4.2.1 item 1"),
                NSLocalizedString("카테고리를 처음부터 비워 뒀어요. 필요한 것만 만들어 쓰세요", comment: "Changelog 4.2.1 item 2"),
                NSLocalizedString("같은 종류가 쌓이면 카테고리를 만들어 드릴까 여쭤봐요", comment: "Changelog 4.2.1 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.2.0",
            released: nil,
            highlights: [
                NSLocalizedString("빨리 칠 때 첫 입력이 끊기던 것을 고쳤어요", comment: "Changelog 4.2.0 item 1"),
                NSLocalizedString("키보드 카드에서 작은 뱃지를 걷어내고 제목만 남겼어요", comment: "Changelog 4.2.0 item 2"),
                NSLocalizedString("템플릿과 콤보와 잠긴 단축어를 테두리 무늬로 구분해요", comment: "Changelog 4.2.0 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.1.0",
            released: nil,
            highlights: [
                NSLocalizedString("카테고리를 고르면 그에 맞는 예시가 미리 채워져요", comment: "Changelog 4.1.0 item 1"),
                NSLocalizedString("처음 쓰시는 분께 쓰임새에 맞는 예시를 세 개씩 보여드려요", comment: "Changelog 4.1.0 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.0.9",
            released: nil,
            highlights: [
                NSLocalizedString("무엇을 저장할지부터 묻고, 제목은 그 다음에 물어요", comment: "Changelog 4.0.9 item 1"),
                NSLocalizedString("채워야 할 자리를 빨갛게 보여드려요", comment: "Changelog 4.0.9 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.0.8",
            released: nil,
            highlights: [
                NSLocalizedString("단축어 하나에 템플릿을 붙여 쓸 수 있어요", comment: "Changelog 4.0.8 item 1"),
                NSLocalizedString("금액이나 수량처럼 숫자를 넣는 칸은 숫자 키패드로 열려요", comment: "Changelog 4.0.8 item 2"),
                NSLocalizedString("채우는 동안 최종 결과를 미리 보여드려요", comment: "Changelog 4.0.8 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.0.7",
            released: nil,
            highlights: [
                NSLocalizedString("처음 실행에서 쓰임새를 고르면 자주 쓰는 갈래를 미리 만들어 드려요", comment: "Changelog 4.0.7 item 1"),
                NSLocalizedString("노마드, 직장인, 학생, 개인 네 갈래를 준비했어요", comment: "Changelog 4.0.7 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.0.6",
            released: nil,
            highlights: [
                NSLocalizedString("무료로 쓸 수 있는 단축어를 5개에서 10개로 늘렸어요", comment: "Changelog 4.0.6 item 1"),
                NSLocalizedString("콤보는 3개까지, 클립보드 기록은 50개까지 늘렸어요", comment: "Changelog 4.0.6 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.0.5",
            released: nil,
            highlights: [
                NSLocalizedString("다른 메모 앱의 글을 통째로 붙여넣으면 알아서 나눠 담아요", comment: "Changelog 4.0.5 item 1"),
                NSLocalizedString("카테고리를 직접 만들고 이름과 순서를 바꿀 수 있어요", comment: "Changelog 4.0.5 item 2")
            ]
        ),
        ChangelogEntry(
            version: "4.0.4",
            released: nil,
            highlights: [
                NSLocalizedString("천지인 키보드의 한글 조합을 바로잡았어요", comment: "Changelog 4.0.4 item 1")
            ]
        ),
        ChangelogEntry(
            version: "4.0.3",
            released: nil,
            highlights: [
                NSLocalizedString("키보드가 화면을 넓게 쓰고, 키보드 안에서 바로 칠 수 있어요", comment: "Changelog 4.0.3 item 1"),
                NSLocalizedString("키보드의 기본 동작을 결제 없이 쓸 수 있어요", comment: "Changelog 4.0.3 item 2"),
                NSLocalizedString("화면 전체를 종이 느낌으로 다시 칠했어요", comment: "Changelog 4.0.3 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.0.1",
            released: nil,
            highlights: [
                NSLocalizedString("Mac 앱이 완전히 새로워졌어요. 단축키 하나로 어디서든 문구를 꺼내 써요", comment: "Changelog 4.0.1 item 1"),
                NSLocalizedString("목록에서 제목 아래 내용이 한 줄 보이고, 민감한 값은 가려져요", comment: "Changelog 4.0.1 item 2"),
                NSLocalizedString("IBAN, SWIFT, VAT 같은 해외 업무용 값도 갈래를 찾아내요", comment: "Changelog 4.0.1 item 3")
            ]
        ),
        ChangelogEntry(
            version: "4.0.0",
            released: nil,
            highlights: [
                NSLocalizedString("잠금화면 위젯에서 즐겨찾기를 바로 복사해요", comment: "Changelog 4.0.0 item 1"),
                NSLocalizedString("Pro 를 열었어요. 기본 기능은 그대로 무료예요", comment: "Changelog 4.0.0 item 2")
            ]
        ),
        ChangelogEntry(
            version: "3.1.3",
            released: nil,
            highlights: [
                NSLocalizedString("키보드 오른쪽 끝이 잘려 보이던 것을 고쳤어요", comment: "Changelog 3.1.3 item 1")
            ]
        ),
        ChangelogEntry(
            version: "3.1.2",
            released: nil,
            highlights: [
                NSLocalizedString("첫 실행에 무엇부터 할지 알려 드리는 안내를 넣었어요", comment: "Changelog 3.1.2 item 1"),
                NSLocalizedString("콤보를 앱에서 바로 고칠 수 있어요", comment: "Changelog 3.1.2 item 2"),
                NSLocalizedString("갈래마다 아이콘이 붙어 목록에서 찾기 쉬워졌어요", comment: "Changelog 3.1.2 item 3")
            ]
        ),
        ChangelogEntry(
            version: "3.1.0",
            released: nil,
            highlights: [
                NSLocalizedString("설정 화면까지 전부 영어로 볼 수 있어요", comment: "Changelog 3.1.0 item 1"),
                NSLocalizedString("iCloud 동기화가 어긋나던 것을 고쳤어요", comment: "Changelog 3.1.0 item 2")
            ]
        ),
        ChangelogEntry(
            version: "3.0.4",
            released: nil,
            highlights: [
                NSLocalizedString("모든 화면이 한국어와 영어로 제공돼요", comment: "Changelog 3.0.4 item 1"),
                NSLocalizedString("적절한 때에만 리뷰를 여쭤봐요", comment: "Changelog 3.0.4 item 2")
            ]
        )
    ]

    /// 현재 실행 중인 앱 버전 - 목록에서 강조하는 데 쓴다.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}

struct ChangelogView: View {

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            ForEach(ChangelogData.entries) { entry in
                Section {
                    ForEach(Array(entry.highlights.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(theme.textFaint)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(item)
                                .font(.body)
                                .foregroundColor(theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 1)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(entry.version)
                            .font(.headline)
                            .foregroundColor(theme.text)
                        // 지금 쓰고 있는 버전을 표시해 "내 앱이 어디까지 왔는지" 알 수 있게.
                        if entry.version == ChangelogData.currentVersion {
                            Text(NSLocalizedString("사용 중", comment: "Changelog: currently installed version badge"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if let released = entry.released {
                            Text(released)
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                    .textCase(nil)   // 버전 번호가 대문자 변환되지 않도록
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                Text(NSLocalizedString("더 자세한 내용은 App Store의 '새로운 기능'에서 볼 수 있어요.", comment: "Changelog footer note"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
        }
        .navigationTitle(NSLocalizedString("변경사항", comment: "Changelog screen title"))
    }
}

#Preview {
    NavigationStack { ChangelogView() }
}

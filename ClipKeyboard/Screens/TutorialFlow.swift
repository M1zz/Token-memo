//
//  TutorialFlow.swift
//  ClipKeyboard
//
//  **써 보는 튜토리얼** - 단축어 다음에 템플릿, 그다음에 콤보.
//
//  ⚠️ 여기서 **아무것도 만들게 하지 않는다.** 예전에는 첫 단축어·템플릿·콤보를 차례로
//     직접 만들게 했는데, 처음 온 사람에게 빈 칸을 세 번 내미는 일이었다. 만드는 법은
//     쓸 일이 생겼을 때 배우면 되고, 처음 필요한 것은 **이게 무엇을 해주는 물건인지**다.
//
//  ⚠️ 대신 **우리가 시나리오를 넣어 둔다.** 설치 첫 실행에 단축어·템플릿·콤보가
//     한 벌씩 목록에 들어가고(`performSampleInsertion`), 튜토리얼은 그것들을 차례로
//     가리키며 눌러 보게 한다. 세 번 누르고 나면 셋이 어떻게 다른지 손이 안다.
//
//  ⚠️ 넣어 둔 것도 **진짜다.** 튜토리얼이 끝나도 지우지 않는다. 연습용 가짜를 만들었다가
//     지우면 아무것도 안 남고, 남겨 두면 그날부터 바로 쓸 수 있는 세 개가 된다.
//

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import LeeoKit
#endif

// MARK: - 장

/// 써 보는 순서: 단축어 → 템플릿 → 콤보.
///
/// ⚠️ 순서에 뜻이 있다. 단축어는 누르면 그대로 들어가고, 템플릿은 빈칸을 한 번 채우고,
///    콤보는 여러 개가 차례로 들어간다. **뒤로 갈수록 한 겹씩 얹히는** 순서라야
///    "아까 것과 뭐가 다르지"가 매번 한 가지로 답해진다.
enum TutorialChapter: String, Identifiable, CaseIterable {
    /// 눌러서 그대로 입력되는 가장 단순한 것.
    case snippet
    /// 빈칸을 채워 쓰는 것.
    case template
    /// 여러 값이 순서대로 들어가는 것.
    case stack
    /// **써 본 다음에** 키보드 크기를 한 번 정한다.
    ///
    /// ⚠️ 앞의 셋과 성격이 다르다. 저쪽은 넣어 둔 것을 눌러 보는 장이고 이 장은 누를 것이
    ///    없다(`TutorialScenarios.match` 가 nil 을 준다). 그래서 환영 화면의
    ///    "이런 걸 넣어뒀어요" 목록에는 저절로 안 들어간다 - 그 목록은 가리킬 것이 있는
    ///    장만 그린다.
    ///
    /// ⚠️ **맨 뒤에 둔다.** 크기를 먼저 물으면 무엇을 담을 키보드인지 모르는 채로 고르게
    ///    된다. 셋을 눌러 보고 나면 화면에 자기 단축어가 서 있어서, 그걸 보며 고른다.
    case layout

    var id: String { rawValue }

    /// 가리키는 카드·키 옆에 뜨는 안내 한 줄.
    ///
    /// ⚠️ "무엇을 누르라"가 아니라 **"누르면 무슨 일이 나는지"**를 적는다. 처음 온 사람은
    ///    누르는 법을 모르는 게 아니라 눌러도 되는지를 모른다.
    var coachLine: String {
        switch self {
        case .snippet:
            return NSLocalizedString("이걸 눌러보세요. 적힌 그대로 입력돼요.",
                                     comment: "Coach line: try the prepared snippet")
        case .template:
            return NSLocalizedString("이번엔 템플릿이에요. 눌러서 빈칸만 채워보세요.",
                                     comment: "Coach line: try the prepared template")
        case .stack:
            return NSLocalizedString("마지막은 콤보예요. 여러 개가 순서대로 들어가요.",
                                     comment: "Coach line: try the prepared combo")
        case .layout:
            return NSLocalizedString("마지막으로 키보드 크기만 정하면 끝이에요.",
                                     comment: "Coach line: choose the keyboard size")
        }
    }

    /// 환영 화면에서 "이런 걸 넣어뒀어요"로 소개하는 한 줄.
    var introLine: String {
        switch self {
        case .snippet:
            return NSLocalizedString("눌러서 그대로 입력하는 단축어",
                                     comment: "Welcome: what a snippet is")
        case .template:
            return NSLocalizedString("빈칸만 채워 쓰는 템플릿",
                                     comment: "Welcome: what a template is")
        case .stack:
            return NSLocalizedString("여러 값을 순서대로 넣는 콤보",
                                     comment: "Welcome: what a combo is")
        case .layout:
            // 환영 화면 목록에는 안 들어가지만(가리킬 것이 없어 걸러진다) 스위치는 다 채운다.
            return NSLocalizedString("내 손에 맞는 키보드 크기",
                                     comment: "Welcome: choosing the keyboard size")
        }
    }

    var symbolName: String {
        switch self {
        case .snippet:  return "text.cursor"
        case .template: return "square.dashed"
        case .stack:    return "list.number"
        case .layout:   return "arrow.up.and.down"
        }
    }
}

// MARK: - 콤보는 한 번 눌러서는 안 배워진다

/// 콤보 장 **안쪽**의 걸음들.
///
/// ⚠️ 왜 콤보만 여러 걸음인가: 단축어와 템플릿은 한 번 누르면 그것이 무엇인지 다 보인다.
///    콤보는 **한 번 눌러서는 아무것도 안 보인다.** 값 하나가 들어갈 뿐이라 보통 단축어와
///    똑같이 생겼고, 이 키가 값 여러 개를 갖고 있다는 사실이 화면 어디에도 안 나타난다.
///    서로 다른 값이 **두 번** 들어가는 걸 자기 눈으로 봐야 그때 알아진다.
///
/// ⚠️ 그래서 걸음이 다섯이다. 넣고 → 보내고 → **→ 로 값을 바꾸고** → 다시 넣고 → 보낸다.
///    가운데 세 번째가 이 장의 전부다. 나머지 넷은 그 하나를 앞뒤로 감싸 대비를 만든다.
///
/// ⚠️ 마지막에 **묻는다.** 두 번 보내 놓고 그냥 지나가면 두 번 눌렀다는 것만 남는다.
///    "서로 다른 값 두 개가 들어갔죠?" 를 한 번 짚어 주어야 손에 남은 것이 뜻이 된다.
enum StackTutorialStep: String, CaseIterable, Identifiable {
    /// 콤보 키 **왼쪽**을 눌러 첫 값을 넣는다.
    case insertFirst
    /// 보내기(위 화살표)를 눌러 올린다.
    case sendFirst
    /// 콤보 키 **오른쪽 →** 를 눌러 다음 값으로 넘긴다. 이 장의 핵심.
    case advance
    /// 다시 왼쪽을 눌러 **아까와 다른 값**을 넣는다.
    case insertSecond
    /// 다시 보낸다 - 두 말풍선이 나란히 서야 다른 값인 것이 보인다.
    case sendSecond
    /// 무엇을 본 것인지 한 번 짚는다.
    case confirm

    var id: String { rawValue }

    /// 무대 위 안내 한 줄.
    ///
    /// ⚠️ "무엇을 누르라"가 아니라 **"누르면 무슨 일이 나는지"**를 적는다(다른 장과 같은 규칙).
    var coachLine: String {
        switch self {
        case .insertFirst:
            return NSLocalizedString("마지막은 콤보예요. 키의 왼쪽을 눌러 첫 번째 값을 넣어보세요.",
                                     comment: "Combo step: insert the first value")
        case .sendFirst:
            return NSLocalizedString("들어갔어요. 보내기를 눌러 올려보세요.",
                                     comment: "Combo step: send the first value")
        case .advance:
            return NSLocalizedString("이제 키의 오른쪽 → 를 눌러보세요. 다음 값으로 바뀝니다.",
                                     comment: "Combo step: advance to the next value")
        case .insertSecond:
            return NSLocalizedString("값이 바뀌었죠? 이번엔 왼쪽을 눌러 두 번째 값을 넣어보세요.",
                                     comment: "Combo step: insert the second value")
        case .sendSecond:
            return NSLocalizedString("아까와 다른 값이에요. 한 번 더 보내볼까요?",
                                     comment: "Combo step: send the second value")
        case .confirm:
            return NSLocalizedString("서로 다른 값 두 개가 들어갔어요",
                                     comment: "Combo step: confirmation headline")
        }
    }

    /// 지금 가리키는 것이 콤보 키의 어느 쪽인가. nil 이면 키가 아닌 다른 곳을 가리킨다.
    var stackPart: KeyboardView.StackKeyPart? {
        switch self {
        case .insertFirst, .insertSecond: return .value
        case .advance:                    return .next
        case .sendFirst, .sendSecond, .confirm: return nil
        }
    }

    /// 지금 보내기 동그라미를 가리키고 있는가.
    var highlightsSend: Bool {
        self == .sendFirst || self == .sendSecond
    }

    /// 이 걸음을 지나면 다음은 무엇인가. 마지막(`confirm`)이면 nil - 장이 끝난다.
    var next: StackTutorialStep? {
        let all = StackTutorialStep.allCases
        guard let i = all.firstIndex(of: self), i + 1 < all.count else { return nil }
        return all[i + 1]
    }
}

// MARK: - 넣어 둔 시나리오

/// 첫 실행에 심어 둔 시나리오 중 **장마다 하나씩**을 찾아 준다.
///
/// ⚠️ 새로 만들지 않는다. 이미 목록에 들어가 있는 것(`SampleMemoStorage`)에서 고른다.
///    튜토리얼이 자기 것을 따로 만들면, 화면에 보이는 카드와 튜토리얼이 가리키는 것이
///    다른 물건이 되어 "그래서 뭘 누르라는 거지"가 된다.
///
/// ⚠️ 지운 것은 없는 것으로 친다. 심어 준 것을 사용자가 지웠을 수도 있고, 그때는
///    그 장을 조용히 건너뛴다 - 없는 카드를 가리키며 누르라고 할 수는 없다.
enum TutorialScenarios {

    /// 장에 해당하는, 지금 목록에 실제로 있는 메모. 없으면 nil.
    static func memo(for chapter: TutorialChapter, in memos: [Memo]) -> Memo? {
        let seeded = SampleMemoStorage.load()
        // 심어 둔 것 먼저, 없으면 목록 전체에서 같은 성격의 것을 찾는다.
        // (튜토리얼을 다시 하는 사람은 심어 둔 것을 이미 지웠을 수 있다.)
        let preferred = memos.filter { seeded.contains($0.id) }
        return match(chapter, in: preferred) ?? match(chapter, in: memos)
    }

    private static func match(_ chapter: TutorialChapter, in memos: [Memo]) -> Memo? {
        switch chapter {
        case .snippet:
            return memos.first {
                !$0.isTemplate && !$0.isStack && $0.contentType == .text
                    && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .template:
            return memos.first { $0.isTemplate && !$0.isStack }
        case .stack:
            // ⚠️ **값이 둘 이상이라야 한다.** `isStack` 는 값이 하나여도 참이다
            //    (`stackValues` 가 비지만 않으면 콤보다). 값이 하나뿐인 콤보를 가리키면
            //    "오른쪽 → 를 눌러보세요, 다음 값으로 바뀝니다" 라고 해 놓고 아무것도
            //    안 바뀐다. 가리킬 것이 없으면 그 장은 조용히 건너뛰는 편이 낫다.
            return memos.first { $0.stackValues.count > 1 }
        case .layout:
            // 가리킬 카드가 없는 장이다. 여기서 nil 을 주는 덕분에 환영 화면의
            // "이런 걸 넣어뒀어요" 목록에서 저절로 빠진다(`availableChapters`).
            return nil
        }
    }

    /// 지금 목록으로 **실제로 써 볼 수 있는** 장들. 환영 화면이 이걸로 목록을 그린다.
    static func availableChapters(in memos: [Memo]) -> [TutorialChapter] {
        TutorialChapter.allCases.filter { memo(for: $0, in: memos) != nil }
    }
}

// MARK: - 마스코트

/// 손 흔드는 악어 - 배경이 **비어 있는**(알파) HEVC 영상을 그대로 재생한다.
///
/// ⚠️ 원본 mp4 는 이름과 달리 옅은 회색 판 위에 그려져 있었다. 그대로 얹으면 라이트에서는
///    화면보다 어두운 사각형이, 다크에서는 밝은 사각형이 캐릭터를 둘러싼다. 그래서 회색을
///    빼고 **알파를 가진 HEVC**(`MascotWave.mov`)로 다시 굽었다. 이제 뒤에 무엇이 깔리든
///    캐릭터만 뜬다 - 테마가 바뀌어도 배경색을 맞출 일이 없다.
///
/// ⚠️ 알파를 살리려면 레이어에 `pixelBufferAttributes` 로 BGRA 를 요구해야 한다.
///    이것이 없으면 알파가 검게 합성되어 **캐릭터 뒤가 검은 사각형**이 된다.
///
/// ⚠️ 소리는 없다(트랙 자체를 뺐다). 온보딩에서 소리가 나면 놀라서 앱을 닫는다.
struct MascotWaveView: UIViewRepresentable {
    /// 움직임 줄이기를 켠 사람에게는 흔들지 않고 **첫 장면만** 세워 둔다.
    var animates: Bool

    static let resourceName = "MascotWave"

    static var videoURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mov")
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.load(url: Self.videoURL, animates: animates)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.setAnimating(animates)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        uiView.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private var player: AVQueuePlayer?
        /// 되풀이는 이 객체가 붙잡고 있어야 이어진다 - 놓으면 한 번 돌고 멈춘다.
        private var looper: AVPlayerLooper?
        /// 지금 움직여야 하는가. 아래 감시들이 모두 이 값 하나를 보고 판단한다.
        private var wantsAnimation = true
        private var rateObservation: NSKeyValueObservation?

        deinit { NotificationCenter.default.removeObserver(self) }

        func load(url: URL?, animates: Bool) {
            guard let url else { return }
            wantsAnimation = animates
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            // ⚠️ 다른 앱의 소리를 끊지 않는다. 음소거여도 세션을 건드리면 배경 음악이 멎는다.
            queue.actionAtItemEnd = .none
            // 로컬 파일이라 버퍼링을 기다릴 이유가 없다. 기다리게 두면 **첫 프레임에서 멈춘 채**
            // 화면에 서 있다.
            queue.automaticallyWaitsToMinimizeStalling = false
            looper = AVPlayerLooper(player: queue, templateItem: item)
            playerLayer.player = queue
            playerLayer.videoGravity = .resizeAspect
            // 알파를 살리는 유일한 열쇠 - 없으면 캐릭터 뒤가 검게 찬다.
            playerLayer.pixelBufferAttributes = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            player = queue

            // ⚠️ **런치 중에 부른 play() 는 살아남지 못한다.**
            //    앱이 아직 활성이 아닌 동안 시작한 재생은 시스템이 곧바로 멈춰 세우고,
            //    그 뒤로는 스스로 되살아나지 않는다. 그래서 처음 온 사람에게는 악어가
            //    **가만히 서 있다가** 뭔가를 누른 뒤에야(뷰가 갱신되며 play 가 다시 불려서)
            //    손을 흔들기 시작했다. 맞이하는 그림이 맞이를 안 한 셈이다.
            //
            //    멈춤을 직접 지켜보고 되살린다 - 창에 붙을 때, 앱이 활성이 될 때,
            //    그리고 누가 멈춰 세웠든 rate 가 0 이 될 때.
            rateObservation = queue.observe(\.rate, options: [.new]) { [weak self] _, _ in
                guard let self else { return }
                DispatchQueue.main.async { self.resumeIfWanted() }
            }
            NotificationCenter.default.addObserver(
                self, selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification, object: nil)

            setAnimating(animates)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resumeIfWanted()
        }

        @objc private func appDidBecomeActive() {
            resumeIfWanted()
        }

        /// 움직여야 하는데 멈춰 있으면 다시 굴린다.
        private func resumeIfWanted() {
            guard wantsAnimation, window != nil, let player, player.rate == 0 else { return }
            player.play()
        }

        func setAnimating(_ animating: Bool) {
            wantsAnimation = animating
            guard let player else { return }
            if animating {
                player.play()
            } else {
                player.pause()
                // 멈춘 채로도 캐릭터는 보여야 한다 - 빈 자리가 남으면 무엇이 빠진 것처럼 보인다.
                player.seek(to: .zero)
            }
        }

        func stop() {
            wantsAnimation = false
            rateObservation = nil
            NotificationCenter.default.removeObserver(self)
            player?.pause()
            playerLayer.player = nil
            looper = nil
            player = nil
        }
    }
}

// MARK: - 환영

/// 첫 화면 - **무엇을 넣어 뒀는지** 알리고 바로 써 보게 한다.
///
/// ⚠️ 여기서 기능을 설명하지 않는다. 셋을 다 설명하면 하나도 안 남는다. 이름만 대고
///    "눌러 보면 안다"로 넘긴다 - 실제 설명은 누른 순간 화면이 대신 해 준다.
struct TutorialWelcomeView: View {

    /// 준비된 것을 써 보러 간다.
    let onStart: () -> Void
    /// 지금은 됐다 - 평소 화면으로.
    let onSkip: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 지금 목록에 실제로 있는 장들만 소개한다.
    ///
    /// ⚠️ 계산 프로퍼티로 두지 않는다 - body 가 그려질 때마다 저장소를 디스크에서 읽게 된다.
    ///    화면이 뜰 때 한 번만 읽고 붙잡아 둔다.
    @State private var chapters: [TutorialChapter] = TutorialChapter.allCases

    /// 손 흔드는 마스코트. 영상이 없으면 손 흔드는 기호로 대신한다 -
    /// 첫 화면이 통째로 비는 것보다 낫다.
    @ViewBuilder
    private var mascot: some View {
        ZStack {
            // 알파 영상이라 뒤가 비어 있다. 캐릭터가 허공에 뜬 것처럼 보이지 않게
            // 브랜드색 옅은 원을 깔아 바닥을 만들어 준다(라이트·다크 각각의 accentSoft).
            Circle()
                .fill(theme.accentSoft)
                .frame(width: 132, height: 132)

            if MascotWaveView.videoURL != nil {
                MascotWaveView(animates: !reduceMotion)
                    .frame(width: 148, height: 148)
            } else {
                Image(systemName: "hand.wave.fill")
                    .font(.largeTitle)
                    .foregroundColor(theme.accent)
            }
        }
        .accessibilityHidden(true)
    }

    private func loadChapters() {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let available = TutorialScenarios.availableChapters(in: memos)
        chapters = available.isEmpty ? TutorialChapter.allCases : available
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            mascot

            Text(NSLocalizedString("바로 써 볼 수 있게 준비해 뒀어요",
                                   comment: "Tutorial welcome: headline"))
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Text(NSLocalizedString("만드는 법은 나중에 알아도 돼요. 먼저 눌러서 어떤 물건인지부터 보세요.",
                                   comment: "Tutorial welcome: body"))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(chapters) { chapter in
                    HStack(spacing: 12) {
                        Image(systemName: chapter.symbolName)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accent)
                            .frame(width: 26)
                            .accessibilityHidden(true)
                        Text(chapter.introLine)
                            .font(.subheadline)
                            .foregroundColor(theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .padding(.top, 26)

            Button(action: onStart) {
                Text(NSLocalizedString("준비되었어요", comment: "Tutorial welcome: start"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.accentFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 26)

            // 빠져나갈 길은 열어 두되, **눈에 덜 띄게** 둔다. 이 튜토리얼은 한 번은
            // 지나야 하는 길이라 "해볼래요/말래요"의 고르기가 아니다. 그래서 위 버튼은
            // 권유가 아니라 준비 확인("준비되었어요")이고, 이쪽은 미루기다.
            Button(action: onSkip) {
                Text(NSLocalizedString("지금 말고 다음에 할래요", comment: "Tutorial welcome: skip"))
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadChapters() }
    }
}

// MARK: - 코치 위치

/// 코치가 가리킬 카드의 화면상 위치(global). 카드가 스스로 올려보낸다.
struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - 코치

/// "이걸 눌러보세요" - 목록 위에 뜨는 안내.
///
/// ⚠️ 처음에는 작은 회색 알약이었는데 **아무도 못 봤다.** 이 안내는 튜토리얼의 전부라
///    놓치면 흐름이 거기서 끊긴다. 그래서 배경을 강조색으로 채우고, 글자를 키우고,
///    천천히 맥박처럼 커졌다 작아지게 했다 - 화면에서 **유일하게 움직이는 것**이라야 눈이 간다.
///
/// ⚠️ 닫기 버튼은 없다. 한 번 쓰면 스스로 사라진다.
struct FirstUseCoachChip: View {
    let line: String
    /// 위쪽 카드를 가리키는 꼭지. 카드 **아래**에 놓일 때만 쓴다.
    var pointsUp: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            if pointsUp {
                // 말풍선 꼬리 - 안내가 무엇을 가리키는지 화살표 하나가 문장보다 빠르다.
                Triangle()
                    .fill(theme.accent)
                    .frame(width: 16, height: 9)
            }
            chip
        }
        .scaleEffect(pulsing ? 1.045 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel(line)
    }

    private var chip: some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.handTap)
                .font(.title3.weight(.bold))
            Text(line)
                .font(.callout.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(theme.accentFg)
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            Capsule().fill(theme.accent)
        )
        .shadow(color: theme.accent.opacity(0.45), radius: 14, x: 0, y: 6)
    }
}

/// 위를 가리키는 삼각형 꼭지.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 다음 장까지

/// 장과 장 사이에 도는 3초 원.
///
/// ⚠️ 왜 그냥 기다리지 않고 원을 보여주나: 방금 하나를 끝냈는데 화면이 잠시 아무것도 안 하면
///    **끝난 건지 멈춘 건지** 알 수 없다. 남은 시간이 보이면 그 몇 초가 '기다림'이 아니라
///    '숨 고르기'가 된다 - 곧 뭔가 온다는 걸 알고 쉬는 것과 모르고 멈춰 있는 건 다르다.
///
/// ⚠️ **누르면 곧바로 넘어간다.** 예전에는 누를 수 없는 표시였다(`allowsHitTesting(false)`).
///    그런데 화면 한가운데에 숫자가 줄어드는 원이 떠 있으면 사람은 그걸 누른다 - 눌러도
///    아무 일이 없으면 앱이 굳은 것으로 읽힌다. 기다리는 것은 배우는 일이 아니므로,
///    빨리 가고 싶은 사람에게는 길을 열어 준다.
struct NextChapterCountdown: View {
    let endsAt: Date
    let total: Double
    /// 눌러서 남은 시간을 건너뛴다. 다음 장이 곧바로 열린다.
    var onSkip: () -> Void = {}

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ring: CGFloat = 46

    var body: some View {
        Button(action: onSkip) {
            TimelineView(.animation) { context in
                let remaining = max(0, endsAt.timeIntervalSince(context.date))
                let progress = total > 0 ? remaining / total : 0

                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(theme.divider, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))   // 12시 방향에서 줄어들게
                        Text("\(Int(remaining.rounded(.up)))")
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(theme.text)
                    }
                    .frame(width: ring, height: ring)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("다음 튜토리얼까지", comment: "Countdown to the next tutorial chapter"))
                            .font(.footnote.weight(.medium))
                            .foregroundColor(theme.textMuted)
                        // 누를 수 있다는 것은 **적어 주어야** 안다. 원만 돌면 기다리는 표시로 읽힌다.
                        Text(NSLocalizedString("눌러서 바로 넘어가기", comment: "Countdown: tap to skip the wait"))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(theme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(theme.divider, lineWidth: 0.5))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("다음 튜토리얼까지", comment: "Countdown to the next tutorial chapter"))
        .accessibilityHint(NSLocalizedString("눌러서 바로 넘어가기", comment: "Countdown: tap to skip the wait"))
    }
}

// MARK: - 다시 하기

enum TutorialReset {

    /// 튜토리얼을 **처음부터 다시** 할 수 있게 표식을 지운다.
    ///
    /// ⚠️ 한 번 배우고 끝이 아니다. 몇 달 만에 열어 본 사람은 템플릿이 뭐였는지, 콤보가
    ///    무엇이었는지 기억하지 못한다. 그때 다시 볼 길이 없으면 "예전엔 됐는데"로 끝난다.
    ///
    /// ⚠️ 지워지는 것은 **표식뿐이다.** 목록의 단축어·템플릿·콤보는 그대로 남는다.
    ///    튜토리얼은 그중에서 가리킬 것을 다시 고른다(`TutorialScenarios`).
    ///
    /// ⚠️ `startedFresh` 도 함께 켠다 - 이 흐름은 그 표식을 보고 도는데, 쓰던 사람에게는
    ///    꺼져 있어서 켜 주지 않으면 다시 하기를 눌러도 아무 일도 안 일어난다.
    static func restartAll() {
        let d = UserDefaults.standard
        d.set(true, forKey: DefaultsKey.startedFreshV444)
        d.set(false, forKey: DefaultsKey.tutorialWelcomeDone)
        d.set(false, forKey: DefaultsKey.tutorialSnippetDone)
        d.set(false, forKey: DefaultsKey.tutorialTemplateDone)
        d.set(false, forKey: DefaultsKey.tutorialStackDone)
        // 콤보 장 안쪽의 걸음도 함께 비운다 - 남겨 두면 다시 하기를 눌러도 그 장이
        // 중간부터 열려서, 처음부터 다시 하겠다고 한 사람의 말과 어긋난다.
        d.set("", forKey: DefaultsKey.tutorialStackStep)
        d.set(false, forKey: DefaultsKey.tutorialSwitchHintSeen)
        d.set(false, forKey: DefaultsKey.tutorialChaptersDone)
        d.set(false, forKey: DefaultsKey.tutorialMakeOwnDone)
        d.set(false, forKey: DefaultsKey.keyboardSetupTutorialDone)
        // ⚠️ 샘플 정리 물음은 **되살리지 않는다.** 이미 답한 사람에게 다시 묻는 것은
        //    묻는 게 아니라 재촉이다. 다시 하기는 배우는 길을 되짚는 것이지,
        //    한 번 고른 결정을 없던 일로 만드는 것이 아니다.
        d.set("", forKey: DefaultsKey.tutorialFirstUseMemoId)
        // 튜토리얼은 무대에서 시작한다 - 목록에 있으면 첫 걸음이 열리지 않는다.
        d.set(SnippetsTabStyle.keyboard.rawValue, forKey: DefaultsKey.snippetsTabStyle)
        print("🎓 [TutorialReset] 튜토리얼 표식 초기화, 처음부터 다시")
    }
}

// MARK: - 크기를 한 번 정하는 장

/// 튜토리얼 마지막 장에 무대 위로 올라오는 카드.
///
/// 왜 이 장이 있나: 크기 설정은 설정 > 키보드 > 키보드 레이아웃, 세 단계 안쪽에 있다.
/// 거기까지 들어가는 사람은 드물어서 "키보드가 너무 크다"는 리뷰를 남긴 사람조차 그 자리를
/// 못 찾았다. 설명으로 알리는 대신 **한 번 지나가게** 한다.
///
/// ⚠️ **바로 아래에 진짜 키보드가 서 있다.** 이 카드는 무대 위, 키보드 바로 위에 얹힌다.
///    끄는 대로 아래가 따라 움직이는 것이 이 장의 전부다. 설명을 길게 쓰지 않는 이유다.
///
/// ⚠️ **막는 문이 아니다.** 고르지 않고 넘어가도 되고, 나중에 설정에서 언제든 바꾼다.
///    온보딩에 문을 세우면 지날 길이 없는 사람이 생긴다(키보드 켜기 걸음을 뺀 것과 같은 이유).
///
/// ⚠️ 두 가지만 묻는다. 높이와 키 크기. 여기에 열 개수·글자 크기·색까지 얹으면
///    설정 화면을 온보딩에 옮겨 놓은 것이 되고, 그러면 아무것도 안 고르고 넘긴다.
struct TutorialLayoutCard: View {

    /// "이대로 할게요" 또는 "그냥 둘게요".
    var onDone: () -> Void

    @AppStorage(DefaultsKey.keyboardHeightPreset, store: AppGroup.defaults)
    private var heightPresetRaw: String = KeyboardHeightPreset.fallback.rawValue
    @AppStorage("keyboardButtonHeight", store: AppGroup.defaults)
    private var buttonHeight: Double = 44.0

    private var preset: KeyboardHeightPreset {
        KeyboardHeightPreset(rawValue: heightPresetRaw) ?? .fallback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.arrowUpAndDown)
                    .font(.subheadline.weight(.semibold))
                Text(NSLocalizedString("키보드 크기를 정해 볼까요", comment: "Layout step: headline"))
                    .font(.subheadline.weight(.bold))
                Spacer(minLength: 0)
            }

            Text(NSLocalizedString("아래 키보드가 바로 따라 바뀝니다. 나중에 설정에서 언제든 다시 바꿀 수 있어요.",
                                   comment: "Layout step: body"))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)

            Picker(NSLocalizedString("키보드 높이", comment: "Keyboard height section title"),
                   selection: $heightPresetRaw) {
                ForEach(KeyboardHeightPreset.allCases) { candidate in
                    Text(candidate.localizedName).tag(candidate.rawValue)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(NSLocalizedString("단축어 높이", comment: "Memo cell height"))
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Text("\(Int(buttonHeight))pt").font(.footnote)
                }
                Slider(value: $buttonHeight, in: 32...120, step: 1)
            }

            Button(action: onDone) {
                Text(NSLocalizedString("이대로 할게요", comment: "Layout step: confirm button"))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.accentForeground))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(Color.accentForeground)
        .tint(Color.accentForeground)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        // 콤보 확인 카드와 **같은 모양**이다. 튜토리얼이 말을 거는 자리는 하나로 보여야
        // 사용자가 "또 그 띠구나" 하고 읽는다.
        .background(Color.accentColor)
        .accessibilityElement(children: .contain)
    }
}

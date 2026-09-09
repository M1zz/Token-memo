//
//  InAppKeyboardHost.swift
//  ClipKeyboard
//
//  앱 안에서 키보드가 글을 넣을 **자리**. 익스텐션의 `KeyboardViewController`가 하는 일을
//  앱 프로세스에서 그대로 한다 - 다만 종착지가 호스트 앱의 텍스트 필드가 아니라
//  우리가 들고 있는 문자열이다.
//
//  ⚠️ 삽입 경로를 새로 만들지 않는다. `KeyboardView`는 예나 지금이나 `.addTextEntry`
//     알림만 쏘고, 그걸 누가 받느냐만 다르다(익스텐션=컨트롤러 / 앱=여기).
//     경로가 갈라지면 "키보드에선 되는데 앱에선 안 되는" 기능이 반드시 생긴다.
//
//  ⚠️ 키보드 사용 통계(`keyboardPasteCount`·비콘)는 **건드리지 않는다.** 앱 안에서 눌러 본 것은
//     키보드를 쓴 게 아니다. 섞으면 "키보드를 얼마나 쓰는가"라는 지표가 의미를 잃는다.
//     문구별 사용 횟수(clipCount)는 올린다 - 그건 실제로 그 문구를 쓴 것이 맞다.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

/// 무대 위에 쌓이는 말풍선 한 개.
///
/// 글만 있는 것이 보통이고, 이미지 단축어를 붙여넣어 보낸 것은 `image`를 갖는다
/// (둘 다 있으면 이미지 아래에 글이 붙는다 - 메시지 앱에서 하는 것과 같은 순서).
struct StageMessage: Identifiable, Equatable {
    enum Side { case incoming, outgoing }
    let id = UUID()
    let side: Side
    let text: String
    #if os(iOS)
    var image: UIImage? = nil
    #endif
}

@MainActor
final class InAppKeyboardHost: ObservableObject, TypingInputProxy {

    // MARK: - 입력창 상태

    /// 지금 입력창에 들어 있는 글.
    @Published private(set) var text: String = ""
    /// 캐럿 위치(문자 인덱스). `text.count`면 맨 뒤.
    @Published private(set) var caret: Int = 0
    /// 무대에 쌓인 말풍선.
    ///
    /// ⚠️ 상대가 건네는 말은 **한 줄이면 된다.** 예전에는 대화의 이유("계좌번호 좀 보내줄래?")를
    ///    한 줄 더 깔았는데, 무대는 매일 여는 첫 화면이라 읽을 것이 두 줄이면 둘 다 안 읽힌다.
    ///    무엇을 하라는 줄 하나만 남긴다.
    @Published private(set) var messages: [StageMessage] = [
        // ⚠️ 길게 누르기는 **눈에 안 보이는 동작**이다. 화면에 버튼을 더 두지 않는 대신
        //    이 줄로 알린다 - 안 알리면 아무도 모르는 기능이 된다.
        .init(side: .incoming,
              text: NSLocalizedString("아래 키보드에서 단축어를 눌러 보세요. 길게 누르면 복사돼요.",
                                      comment: "In-app keyboard stage: sample incoming hint"))
    ]

    #if os(iOS)
    /// 입력창에 붙어 있는 이미지 - 보내면 말풍선으로 올라가고 자리는 비워진다.
    ///
    /// 이미지 단축어는 글처럼 **캐럿 자리에 끼워 넣을 수가 없다.** 그래서 글과 같은 줄에
    /// 두지 않고 입력창 위에 딸린 첨부로 둔다(메시지 앱들이 하는 것과 같은 모양).
    @Published private(set) var attachedImage: UIImage?
    #endif

    /// `KeyboardView`가 구독하는 상태 - X(전체 삭제) 버튼 노출 여부를 여기서 본다.
    let documentState = KeyboardDocumentState()

    private var tokens: [NSObjectProtocol] = []
    /// 콤보 순차 입력이 도는 중인지 - 무대를 떠나면 멈춘다.
    private var comboWorkItems: [DispatchWorkItem] = []

    // MARK: - 생애

    /// 글을 **한 글자씩 흘려 넣을지.**
    ///
    /// 화면에서는 언제나 켠다(움직임 줄이기를 켠 사람에게는 `animatesTyping` 이 알아서 끈다).
    /// 결과만 보면 되는 자리(시험)에서는 꺼서 한 번에 넣는다 - 흐르는 동안 값을 읽으면
    /// 반쯤 들어온 글을 보게 되어 시험이 시간에 흔들린다.
    private let typesOut: Bool

    init(typesOut: Bool = true) {
        self.typesOut = typesOut
        // 앱에는 "전체 접근" 개념이 없다 - 클립보드는 언제나 열려 있다.
        // 이 값을 켜 두지 않으면 KeyboardView가 클립보드 동작을 막고
        // "설정 > 키보드에서 전체 접근을 켜세요" 라는 엉뚱한 안내를 띄운다.
        // 지구본은 앱 안에서 갈 곳이 없으므로 끈다.
        KeyboardCapability.update(hasFullAccess: true, needsInputModeSwitchKey: false)
        subscribe()
    }

    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// 화면을 떠날 때 - 돌고 있던 콤보 순차 입력을 세운다.
    func stop() {
        typingTask?.cancel()
        typingTask = nil
        typingRemainder = []
        typingCompletion = nil
        comboWorkItems.forEach { $0.cancel() }
        comboWorkItems.removeAll()
    }

    private func subscribe() {
        let t1 = NotificationCenter.default.addObserver(
            forName: .addTextEntry, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleAddTextEntry(note) }
        }
        let t2 = NotificationCenter.default.addObserver(
            forName: .templateInputComplete, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleTemplateInputComplete(note) }
        }
        let t3 = NotificationCenter.default.addObserver(
            forName: .addImageEntry, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleAddImageEntry(note) }
        }
        tokens = [t1, t2, t3]
    }

    // MARK: - TypingInputProxy (자판이 두드리는 자리)

    nonisolated func insertText(_ text: String) {
        MainActor.assumeIsolated { insert(text) }
    }

    nonisolated func deleteBackward() {
        MainActor.assumeIsolated {
            // 흐르는 중에 지우면 뒤에서 글자가 계속 밀려 들어와 지운 티가 안 난다.
            flushTyping()
            guard caret > 0 else { return }
            let idx = self.text.index(self.text.startIndex, offsetBy: caret - 1)
            self.text.remove(at: idx)
            caret -= 1
            syncDocumentState()
        }
    }

    nonisolated func insertNewline() {
        MainActor.assumeIsolated { insert("\n") }
    }

    /// 앱 안에는 넘어갈 다음 키보드가 없다. (지구본 키 자체를 숨기므로 불릴 일이 없다)
    nonisolated func advanceToNextInputMode() {}

    /// 같은 이유로 붙일 것이 없다. 앱은 입력 뷰 컨트롤러가 아니라
    /// `handleInputModeList(from:with:)` 자체가 존재하지 않는다.
    nonisolated func attachInputModeSwitch(to button: UIButton) {}

    nonisolated func cursorRight() {
        MainActor.assumeIsolated {
            guard caret < text.count else { return }
            caret += 1
        }
    }

    nonisolated func clearAll() {
        MainActor.assumeIsolated {
            typingTask?.cancel()
            typingTask = nil
            typingRemainder = []
            typingCompletion = nil
            text = ""
            caret = 0
            syncDocumentState()
        }
    }

    // MARK: - 무대 동작

    /// 쓴 글(과 붙여넣은 이미지)을 말풍선으로 올린다.
    ///
    /// 이미지만 붙이고 글은 안 쓴 채로도 보낼 수 있다 - 이미지 단축어를 눌러 본 사람이
    /// 결과를 보려고 굳이 글까지 써야 하는 것은 이유 없는 한 걸음이다.
    func send() {
        flushTyping()   // 반쯤 흐른 글을 말풍선으로 올리지 않는다
        guard canSend else { return }
        #if os(iOS)
        messages.append(.init(side: .outgoing, text: text, image: attachedImage))
        attachedImage = nil
        #else
        messages.append(.init(side: .outgoing, text: text))
        #endif
        clearAll()
        NotificationCenter.postOnMain(name: .stageMessageSent, object: nil)
    }

    /// 보낼 것이 하나라도 있는가 - 보내기 버튼의 활성 조건이자 `send()`의 관문.
    /// (공백만 친 것은 보낼 것이 없는 것으로 본다. 예전에는 버튼만 켜지고 눌러도
    ///  아무 일이 없었다 - 눌리는데 안 되는 버튼은 고장으로 읽힌다)
    var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #if os(iOS)
        return hasText || attachedImage != nil
        #else
        return hasText
        #endif
    }

    #if os(iOS)
    /// 붙여 둔 이미지를 뗀다(첨부 칩의 x).
    func detachImage() {
        attachedImage = nil
    }

    /// 클립보드에 이미지가 있으면 입력창에 붙인다 - 입력창의 붙여넣기 버튼이 부른다.
    ///
    /// ⚠️ `hasImages` 로 **먼저 물어보고** 실제 읽기는 그 다음이다. iOS는 클립보드를 읽을 때마다
    ///    붙여넣기 허용 팝업을 띄울 수 있어, 있는지도 모르는 채 읽으면 이유 없이 물어보게 된다.
    /// - Returns: 붙였으면 true.
    @discardableResult
    func pasteImageFromClipboard() -> Bool {
        guard UIPasteboard.general.hasImages,
              // pasteboard-ok: 입력창의 붙여넣기 버튼을 눌러 부른 자리다
              let image = UIPasteboard.general.image else { return false }
        attachedImage = image
        KeyboardHaptics.stamp()
        return true
    }

    /// 클립보드에 붙일 이미지가 있는가(읽지 않고 확인만).
    var clipboardHasImage: Bool { UIPasteboard.general.hasImages }
    #endif

    // MARK: - 삽입 (내부)

    private func insert(_ chunk: String) {
        let idx = text.index(text.startIndex, offsetBy: min(caret, text.count))
        text.insert(contentsOf: chunk, at: idx)
        caret = min(caret + chunk.count, text.count)
        syncDocumentState()
    }

    /// 넣은 뒤 캐럿을 끝에서 `offsetFromEnd` 만큼 되돌린다(`{커서}` 토큰 처리).
    ///
    /// ⚠️ **값이 입력칸에 들어가는 길은 여기 하나뿐이다.** 그냥 누른 것도, 템플릿 빈칸을
    ///    채우고 온 것도, 잠긴 것을 풀고 온 것도 마지막엔 전부 여기로 모인다.
    private func insertResolved(_ processed: String) {
        let placement = TemplateVariableProcessor.resolveCursor(in: processed)
        typeOut(placement.text) { [weak self] in
            guard let self, placement.needsCursorMove else { return }
            self.caret = max(0, self.caret - placement.offsetFromEnd)
        }
        KeyboardHaptics.stamp()
    }

    // MARK: - 치는 것처럼 넣기

    /// 아직 안 들어간 글자들. 비어 있으면 지금 흐르는 것이 없다는 뜻이다.
    private var typingRemainder: [Character] = []
    /// 다 들어간 뒤에 할 일(캐럿 되돌리기 등).
    private var typingCompletion: (() -> Void)?
    private var typingTask: Task<Void, Never>?

    /// 글자 하나 사이의 쉼(초). 짧은 글은 이 값 그대로, 긴 글은 아래 총 시간에 맞춰 줄어든다.
    private static let typingStep: TimeInterval = 0.03
    /// 아무리 길어도 이 시간 안에 다 들어간다.
    ///
    /// ⚠️ 상한이 없으면 서른 줄짜리 템플릿이 십몇 초를 흐른다. 그건 보여 주는 것이 아니라
    ///    **기다리게 하는 것**이다. 이 연출은 "눌렀더니 대신 쳐 준다"를 한 번 보여주려는
    ///    것이지, 진짜 타자기를 흉내 내려는 것이 아니다.
    private static let typingBudget: TimeInterval = 0.7

    /// 움직임 줄이기를 켠 사람에게는 흐르지 않는다 - 한 번에 들어간다.
    private var animatesTyping: Bool {
        guard typesOut else { return false }
        #if os(iOS)
        return !UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }

    /// 한 글자씩 밀어 넣는다 - **대신 쳐 주는 장면**을 보여준다.
    ///
    /// ⚠️ 왜 한 번에 안 넣나: 이 화면의 값어치는 "긴 걸 안 쳐도 된다"인데, 글이 순간이동하면
    ///    무엇을 안 해도 됐는지가 안 보인다. 흐르는 동안 눈이 그 길이를 읽는다.
    ///    (진짜 익스텐션은 남의 앱 입력칸에 넣는 자리라 이런 연출을 하지 않는다.
    ///     거기서는 빠른 것이 전부다. 이건 **미리보기에서만** 하는 일이다)
    ///
    /// ⚠️ 흐르는 도중에 다음 것이 오면 **앞의 것을 먼저 끝내 놓는다**(`flushTyping`).
    ///    두 개가 겹쳐 흐르면 글자가 서로 끼어들어 문장이 뒤섞인다.
    private func typeOut(_ chunk: String, completion: @escaping () -> Void) {
        flushTyping()
        guard !chunk.isEmpty else { completion(); return }
        guard animatesTyping, chunk.count > 1 else {
            insert(chunk)
            completion()
            return
        }

        typingRemainder = Array(chunk)
        typingCompletion = completion
        let step = min(Self.typingStep, Self.typingBudget / Double(typingRemainder.count))

        typingTask = Task { @MainActor [weak self] in
            while true {
                guard let self, !Task.isCancelled, !self.typingRemainder.isEmpty else { return }
                self.insert(String(self.typingRemainder.removeFirst()))
                if self.typingRemainder.isEmpty { break }
                try? await Task.sleep(for: .seconds(step))
            }
            guard let self, !Task.isCancelled else { return }
            self.typingTask = nil
            let done = self.typingCompletion
            self.typingCompletion = nil
            done?()
        }
    }

    /// 흐르는 중이면 **지금 당장 끝낸다.** 남은 글자를 한 번에 넣는다.
    ///
    /// 보내기·지우기·다음 삽입처럼 "글이 다 들어와 있어야 하는" 자리에서 먼저 부른다.
    /// 반쯤 흐른 글을 말풍선으로 올리면 사용자가 누른 적 없는 문장이 올라간다.
    private func flushTyping() {
        typingTask?.cancel()
        typingTask = nil
        if !typingRemainder.isEmpty {
            insert(String(typingRemainder))
            typingRemainder = []
        }
        let done = typingCompletion
        typingCompletion = nil
        done?()
    }

    private func syncDocumentState() {
        documentState.hasText = !text.isEmpty
    }

    // MARK: - 알림 처리 (KeyboardViewController와 같은 순서)

    private func handleAddTextEntry(_ note: Notification) {
        guard let raw = note.object as? String,
              let memoId = note.userInfo?["memoId"] as? UUID else { return }

        // 콤보 분할 버튼에서 값 하나만 넣는 경우 순차 입력을 건너뛴다.
        let skipCombo = (note.userInfo?["skipCombo"] as? Bool) ?? false
        if !skipCombo, handleComboIfNeeded(text: raw, memoId: memoId) { return }

        let custom = customPlaceholders(in: raw)
        if custom.isEmpty {
            insertResolved(processVariables(in: raw))
            trackUse(memoId: memoId)
        } else {
            // 값을 물어봐야 한다 - 오버레이는 KeyboardView가 띄우고,
            // 다 채우면 `.templateInputComplete` 로 돌아온다.
            NotificationCenter.postOnMain(
                name: .showTemplateInput,
                object: nil,
                userInfo: ["text": raw, "placeholders": custom, "memoId": memoId]
            )
        }
    }

    /// 이미지 단축어를 눌렀다 - 클립보드 복사는 `KeyboardView`가 이미 했고,
    /// 여기서는 그 이미지를 입력창에 붙여 **눈에 보이게** 한다.
    private func handleAddImageEntry(_ note: Notification) {
        #if os(iOS)
        guard let fileName = note.object as? String,
              let image = MemoStore.shared.loadImage(fileName: fileName) else {
            print("⚠️ [InAppKeyboardHost.handleAddImageEntry] 이미지 로드 실패")
            return
        }
        attachedImage = image
        trackUse(memoId: note.userInfo?["memoId"] as? UUID)
        #endif
    }

    private func handleTemplateInputComplete(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info["text"] as? String,
              let inputs = info["inputs"] as? [String: String] else { return }

        var processed = raw
        for (placeholder, value) in inputs {
            processed = processed.replacingOccurrences(of: placeholder, with: value)
        }
        processed = processVariables(in: processed)

        // 템플릿을 문구에 붙여 쓴 경우(base + 템플릿) - 본문 뒤에 이어 붙인다.
        if let baseId = info["baseMemoId"] as? UUID,
           let base = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == baseId }) {
            insertResolved(base.value.isEmpty ? processed : "\(base.value)\n\(processed)")
            trackUse(memoId: baseId)
        } else {
            insertResolved(processed)
            trackUse(memoId: info["memoId"] as? UUID)
        }
    }

    /// 여러 값(콤보) 문구면 값들을 간격을 두고 하나씩 넣는다.
    /// - Returns: 콤보로 처리했으면 true.
    private func handleComboIfNeeded(text raw: String, memoId: UUID) -> Bool {
        guard let memo = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == memoId }),
              !memo.comboValues.isEmpty else { return false }

        let values = SecureMemoCrypto.decryptSteps(memo.comboValues)
        guard !values.isEmpty else { return false }
        // 키가 아직 동기화되지 않아 암호문이 남았다면 그걸 그대로 타이핑하지 않는다.
        if values.contains(where: { SecureMemoCrypto.isEncrypted($0) }) { return true }

        insertCombo(values, interval: memo.comboInterval, index: 0)
        trackUse(memoId: memoId)
        return true
    }

    private func insertCombo(_ values: [String], interval: TimeInterval, index: Int) {
        guard index < values.count else { return }

        if index < values.count - 1 {
            // 중간 단계에서 캐럿을 옮기면 다음 값이 엉뚱한 자리에 들어간다
            // 커서 토큰은 마지막 단계에서만 살린다(익스텐션과 같은 규칙).
            insert(TemplateVariableProcessor.resolveCursor(in: processVariables(in: values[index])).text)
            KeyboardHaptics.mediumTap()
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.insertCombo(values, interval: interval, index: index + 1) }
            }
            comboWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
        } else {
            insertResolved(processVariables(in: values[index]))
        }
    }

    // MARK: - 치환

    /// 사용자가 값을 채워야 하는 변수만 골라낸다(자동 변수 `{날짜}` 등은 제외).
    private func customPlaceholders(in text: String) -> [String] {
        TemplatePlaceholder.customTokens(in: text)
    }

    private func processVariables(in text: String) -> String {
        // 클립보드는 **토큰이 있을 때만** 읽는다. iOS는 읽을 때마다 붙여넣기 프롬프트를 띄울 수 있어
        // 미리 읽어 두면 아무 이유 없이 물어보게 된다.
        var clipboard: String?
        #if os(iOS)
        if TemplateVariableProcessor.containsClipboardToken(text) {
            // pasteboard-ok: {클립보드} 가 든 문구를 눌렀을 때만 읽는다
            clipboard = UIPasteboard.general.string
        }
        #endif
        // 커서 토큰은 남긴다 - insertResolved가 위치 계산에 쓴다.
        return TemplateVariableProcessor.process(text, clipboard: clipboard, keepCursorToken: true)
    }

    /// 문구를 실제로 썼다 - 사용 횟수만 올린다(`.memoUsed` 알림도 여기서 나간다).
    private func trackUse(memoId: UUID?) {
        guard let memoId else { return }
        do {
            try MemoStore.shared.incrementClipCount(for: memoId)
        } catch {
            print("⚠️ [InAppKeyboardHost.trackUse] 사용량 업데이트 실패: \(error)")
        }
    }
}

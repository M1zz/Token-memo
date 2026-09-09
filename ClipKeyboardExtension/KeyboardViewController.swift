//
// KeyboardViewController.swift
// TokenKeyboard
//
// Created by hyunho lee on 2023/05/24.
//

import UIKit
import SwiftUI

typealias KeyboardData = [String: String]
var clipKey: [String] = []
var clipValue: [String] = []
var clipMemoId: [UUID] = []  // 메모 ID 저장
// clipMemos는 앱 무대(InAppKeyboardStage)와 공유하므로 KeyboardMemoFeed.swift로 옮겼다.
var tappedIndex = 2
var memoData: KeyboardData = [:]

class KeyboardViewController: UIInputViewController {
    @IBOutlet var nextKeyboardButton: UIButton!

    private var deleteTimer: Timer?
    private var deleteStartTime: Date?
    private var notificationTokens: [NSObjectProtocol] = []

    /// 넣은 직후 "사용자가 캐럿을 앞으로 옮겨 거기서 쓰는지" 지켜보는 동안의 메모지.
    /// 여기 담긴 것을 `CursorMemory` 가 배운다. 자세한 이유는 그 파일 머리말.
    private struct CaretWatch {
        let memoId: UUID
        /// 토큰이 제거된, 실제로 넣은 글.
        let insertedText: String
        /// 넣은 **직후**의 캐럿 앞 글.
        let beforeAtInsert: String
        /// 캐럿이 앞으로 옮겨 간 거리(아직 거기서 쓰기 전이라 후보다).
        var candidateOffset: Int?
        let startedAt: Date
    }
    private var caretWatch: CaretWatch?

    /// 지켜보는 시간. 이보다 오래 지나면 같은 문장을 고치는 중이라고 보기 어렵다.
    private let caretWatchWindow: TimeInterval = 30

    /// 넣은 글이 **결국 어떤 모양이 됐는지** 보려고 들고 있는 메모지.
    /// 여기서 나온 차이를 `EditPattern` 이 읽는다.
    private struct EditWatch {
        let memoId: UUID
        /// 토큰이 제거된, 실제로 넣은 글.
        let insertedText: String
        /// 넣기 **직전**까지 캐럿 앞에 있던 글. 고쳐진 구간을 잘라내는 왼쪽 울타리.
        let headBeforeInsert: String
        /// 넣은 직후 캐럿 뒤에 있던 글. 오른쪽 울타리.
        let tailAtInsert: String
        let startedAt: Date
    }
    private var editWatch: EditWatch?

    /// 손이 멎고 이만큼 지나면 "다 썼다"고 본다. 남의 앱 보내기 버튼은 볼 수 없어서
    /// 멎은 시간으로 대신한다.
    private let editSettleDelay: TimeInterval = 1.5
    private var editSettleTimer: Timer?

    private let globeKeyboardButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            button.widthAnchor.constraint(equalToConstant: 45).isActive = true
            button.layer.cornerRadius = AppTheme.paperLight.radiusXs  // 키캡 코너 (xs=6, 테마 불변)
            button.setImage(UIImage(systemName: AppSymbol.globe), for: .normal)
            button.tintColor = .black
            button.backgroundColor = .systemGray2
            return button
        }()

    let spaceButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        button.layer.cornerRadius = AppTheme.paperLight.radiusXs  // 키캡 코너 (xs=6, 테마 불변)
        button.setTitle("Space", for: UIControl.State.normal)
        button.titleLabel!.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor.white
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        return button
    }()

    let returnButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.widthAnchor.constraint(equalToConstant: 65).isActive = true
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor.systemBlue
        config.baseForegroundColor = UIColor.white
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        config.title = NSLocalizedString("Return", comment: "Return key")
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .systemFont(ofSize: 13, weight: .medium)
            return updated
        }
        config.cornerStyle = .fixed
        button.layer.cornerRadius = AppTheme.paperLight.radiusXs  // 키캡 코너 (xs=6, 테마 불변)
        button.configuration = config
        return button
    }()

    let textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .roundedRect
        textField.placeholder = "Enter text"
        return textField
    }()

    private func configureNextKeyboardButton() {
        self.nextKeyboardButton = UIButton(type: .system)
        self.nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), for: [])
        self.nextKeyboardButton.sizeToFit()
        self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false

        self.nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        self.view.addSubview(self.nextKeyboardButton)

        self.nextKeyboardButton.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.nextKeyboardButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }

    /// SwiftUI에서 관찰하는 호스트 텍스트 필드 상태 - textDidChange에서 갱신
    private let documentState = KeyboardDocumentState()
    private lazy var keyboardView: KeyboardView = KeyboardView(typingProxy: self, documentState: documentState)
    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 키보드는 앱과 **다른 프로세스**라 앱에서 고른 언어를 스스로 다시 세워야 한다.
        // 화면을 만들기 전에 부른다 - 키 이름이 한 번 그려진 뒤에는 안 바뀐다.
        AppLanguage.applyStored()

        setupHeightConstraint()
        configureNextKeyboardButton()
        loadMemos()
        setupNotificationObservers()
        setupHostingController()  // 화면 전체에 SwiftUI 키보드만 표시

        AppGroup.defaults?
            .set(true, forKey: DefaultsKey.keyboardExtensionDidLoad)

        print("✅ viewDidLoad 완료, fullscreen SwiftUI keyboard")
    }

    /// 키보드 익스텐션 잠금 오버레이.
    /// - 메인 앱 열기 버튼은 clipkeyboard://paywall URL scheme으로 paywall로 직행.
    private func presentKeyboardLockOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.98)

        let lockIcon = UIImageView(image: UIImage(systemName: AppSymbol.lockFill))
        lockIcon.tintColor = .systemBlue
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = NSLocalizedString("Unlock keyboard in ClipKeyboard", comment: "Keyboard locked title")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = NSLocalizedString("Open the main app to upgrade.", comment: "Keyboard locked subtitle")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let openButton = UIButton(type: .system)
        var openConfig = UIButton.Configuration.filled()
        openConfig.baseBackgroundColor = .systemBlue
        openConfig.baseForegroundColor = .white
        openConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
        openConfig.title = NSLocalizedString("Open App", comment: "Open main app button")
        openConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .systemFont(ofSize: 14, weight: .semibold)
            return updated
        }
        openConfig.cornerStyle = .fixed
        openButton.layer.cornerRadius = AppTheme.paperLight.radiusSm  // sm=10, 테마 불변
        openButton.configuration = openConfig
        openButton.addTarget(self, action: #selector(openMainAppPaywall), for: .touchUpInside)
        openButton.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(lockIcon)
        overlay.addSubview(title)
        overlay.addSubview(subtitle)
        overlay.addSubview(openButton)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            lockIcon.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            lockIcon.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 32),
            lockIcon.widthAnchor.constraint(equalToConstant: 32),
            lockIcon.heightAnchor.constraint(equalToConstant: 32),

            title.topAnchor.constraint(equalTo: lockIcon.bottomAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            subtitle.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),

            openButton.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 16),
            openButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])
    }

    @objc private func openMainAppPaywall() {
        guard let url = URL(string: "clipkeyboard://paywall") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            // iOS 18+: use openURL(_:) via extensionContext selector chain fallback
            let selector = sel_registerName("openURL:")
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
        print("⚠️ [Keyboard] Paywall URL scheme 실행 실패")
    }

    // MARK: - viewDidLoad Helpers

    /// 키보드의 키. 회전할 때 상수만 갈아 끼우려고 들고 있는다.
    private var heightConstraint: NSLayoutConstraint?

    /// 높이를 **시스템 키보드와 같게** 세운다.
    ///
    /// 예전에는 `254` 고정이었다. 그 숫자에는 지금 근거가 없다. 주석은 "SwiftUI 영역(200)
    /// + 하단 바(54)" 였는데 그 하단 UIKit 바는 이미 없어졌고(아래 `setupHostingController`),
    /// 남은 건 기기마다 어긋나는 상수 하나뿐이었다. 회전도 보지 않아 가로에서는 시스템
    /// 키보드보다 한참 높았다.
    ///
    /// ⚠️ 우선순위가 핵심이다. `.defaultHigh`(750) 로 두면 iOS 가 **자기 기본 높이로 한 번
    ///    세운 뒤** 우리 값으로 끌어당기고, 그 변화를 애니메이션한다. 키보드가 뜰 때 높이가
    ///    팍 튀어 버그처럼 보이던 것이 이것이다. 999 면 첫 레이아웃부터 우리 값으로 선다.
    ///    (1000 = `.required` 는 시스템이 입력 뷰에 거는 제약과 충돌해 로그를 더럽힌다)
    ///
    ///    그리고 높이가 실제 시스템 키보드와 같아지면 애니메이션할 차이 자체가 사라진다.
    ///    두 증상은 뿌리가 하나였다.
    private func setupHeightConstraint() {
        let constraint = view.heightAnchor.constraint(equalToConstant: desiredHeight)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        heightConstraint = constraint
    }

    /// 지금 화면에서 우리 판이 가질 높이. 앱이 재 둔 시스템 키보드 값이 바탕이 된다.
    /// (없으면 화면 비율로 어림한다. `KeyboardHeightBook` 머리말 참고)
    private var desiredHeight: CGFloat {
        KeyboardHeightBook.height(for: screenSize, content: contentMetrics)
    }

    /// 우리 판이 지금 무엇을 그리는지. 키 높이와 칸 수는 사용자가 설정에서 바꾼다.
    ///
    /// ⚠️ `UserDefaults` 는 키가 없으면 0 을 돌려준다. 그대로 쓰면 격자가 필요로 하는
    ///    높이가 0 이 되어 바닥 계산이 통째로 무너진다. 없을 때는 기본값을 쓴다.
    private var contentMetrics: KeyboardHeightBook.ContentMetrics {
        var metrics = KeyboardHeightBook.ContentMetrics()
        let defaults = AppGroup.defaults
        if let height = defaults?.object(forKey: "keyboardButtonHeight") as? Double, height > 0 {
            metrics.buttonHeight = CGFloat(height)
        }
        if let columns = defaults?.object(forKey: "keyboardColumnCount") as? Int, columns > 0 {
            metrics.columns = columns
        }
        return metrics
    }

    /// 화면 크기. 익스텐션에는 씬이 늦게 붙어 `view.window` 가 비어 있는 순간이 있으므로
    /// 그때는 화면을 직접 본다.
    private var screenSize: CGSize {
        view.window?.windowScene?.screen.bounds.size ?? UIScreen.main.bounds.size
    }

    /// 회전 등으로 화면이 바뀐 뒤 높이를 다시 맞춘다.
    private func applyHeight() {
        let target = desiredHeight
        guard let heightConstraint, heightConstraint.constant != target else { return }
        heightConstraint.constant = target
        view.layoutIfNeeded()
    }

    /// 가로와 세로는 시스템 키보드 높이가 완전히 다르다.
    ///
    /// ⚠️ 회전 **애니메이션 안에서** 바꾼다. 끝난 뒤에 바꾸면 회전이 멎은 다음 한 번 더
    ///    움찔하는데, 그게 정확히 없애려는 그 움직임이다.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.applyHeight()
        })
    }

    /// SwiftUI KeyboardView를 호스팅하고, 하단 bottomView를 생성하여 반환
    /// SwiftUI KeyboardView를 화면 전체에 호스팅. 하단 UIKit 바 제거됨
    /// globe/space/backspace/return은 모두 SwiftUI 키보드 (특히 Type 탭) 안에 통합.
    private func setupHostingController() {
        setupSystemBackdrop()

        let hostingVC = UIHostingController(rootView: keyboardView)
        self.hostingController = hostingVC
        addChild(hostingVC)

        let myKeyboardView = hostingVC.view!
        myKeyboardView.translatesAutoresizingMaskIntoConstraints = false
        myKeyboardView.backgroundColor = .clear
        myKeyboardView.clipsToBounds = true
        view.addSubview(myKeyboardView)
        hostingVC.didMove(toParent: self)
        view.backgroundColor = .clear

        NSLayoutConstraint.activate([
            myKeyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            myKeyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            myKeyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            myKeyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// 시스템 키보드와 **같은 바탕**을 우리 판 뒤에 깐다.
    ///
    /// ⚠️ 왜 우리가 색을 칠하면 안 되나: iOS 26 은 우리 뷰 **바깥에** 지구본·받아쓰기 줄을
    ///    직접 그린다. 그 줄의 바탕은 시스템 키보드 재질(반투명)이라 뒤에 있는 앱 색을
    ///    받아 간다. 우리가 그 위쪽을 불투명한 회색으로 칠하면 두 바탕이 갈려 **이음매가
    ///    한 줄 그어진 것처럼** 보인다. 카톡처럼 배경이 푸른 앱에서 특히 도드라졌다.
    ///
    /// `UIInputView(inputViewStyle: .keyboard)` 은 그 재질을 그대로 그려 주는 유일한 공개 API 다.
    /// 이걸 맨 뒤에 깔고 SwiftUI 는 투명하게 두면, 우리 판과 시스템 줄이 한 장으로 이어진다.
    ///
    /// ⚠️ 사용자가 키보드 배경색을 직접 골랐으면 그 색이 이 위를 덮는다
    ///    (`KeyboardView.backgroundColor`). 고른 사람의 선택이 우선이다.
    private func setupSystemBackdrop() {
        let backdrop = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNotificationObservers() {
        let t1 = NotificationCenter.default.addObserver(forName: Notification.Name.filterChanged, object: nil, queue: nil) { [weak self] _ in
            self?.loadMemos()
        }
        let t2 = NotificationCenter.default.addObserver(forName: Notification.Name.addTextEntry, object: nil, queue: nil) { [weak self] notification in
            self?.handleAddTextEntry(notification)
        }
        let t3 = NotificationCenter.default.addObserver(forName: Notification.Name.templateInputComplete, object: nil, queue: .main) { [weak self] notification in
            self?.handleTemplateInputComplete(notification)
        }
        let t4 = NotificationCenter.default.addObserver(forName: Notification.Name.openMainAppPaywall, object: nil, queue: .main) { [weak self] _ in
            self?.openMainAppPaywall()
        }
        notificationTokens = [t1, t2, t3, t4]
    }

    private func handleAddTextEntry(_ notification: Notification) {
        print("🔔 addTextEntry 알림 수신")
        guard let text = notification.object as? String,
              let userInfo = notification.userInfo,
              let memoId = userInfo["memoId"] as? UUID else {
            print("❌ 텍스트 또는 메모 ID가 없습니다")
            return
        }

        print("📝 텍스트: \(text)")
        print("🆔 메모 ID: \(memoId)")

        // skipCombo=true면(콤보 분할 버튼에서 값 하나만 삽입) 순차 자동입력을 건너뛴다.
        let skipCombo = (userInfo["skipCombo"] as? Bool) ?? false
        if !skipCombo, handleComboMemoIfNeeded(text: text, memoId: memoId) { return }

        let customPlaceholders = extractCustomPlaceholders(from: text)
        print("🔍 발견된 커스텀 플레이스홀더: \(customPlaceholders)")

        if !customPlaceholders.isEmpty {
            print("✅ 템플릿 입력 오버레이 표시")
            NotificationCenter.postOnMain(
                name: Notification.Name.showTemplateInput,
                object: nil,
                userInfo: ["text": text, "placeholders": customPlaceholders, "memoId": memoId]
            )
        } else {
            print("⚡ 자동 변수만 치환해서 바로 입력")
            insertProcessedText(text, memoId: memoId)
            trackKeyboardPaste(memoId: memoId)
        }
    }

    /// Combo 메모(자식 메모 참조)인 경우 자식들의 value를 comboInterval 간격으로 순차 입력.
    /// - Returns: Combo 처리를 했으면 true
    private func handleComboMemoIfNeeded(text: String, memoId: UUID) -> Bool {
        guard let memo = clipMemos.first(where: { $0.id == memoId }), !memo.comboValues.isEmpty else { return false }
        // 보안 콤보 - 단계 값 복호화(PIN 인증은 KeyboardView에서 이미 통과).
        // 키 미동기화로 암호문이 남으면 암호문을 타이핑하지 않도록 중단한다.
        let values = SecureMemoCrypto.decryptSteps(memo.comboValues)
        guard !values.isEmpty else { return false }
        if values.contains(where: { SecureMemoCrypto.isEncrypted($0) }) {
            print("🔒 [handleComboMemoIfNeeded] 보안 키 미동기화 - 콤보 복호화 불가, 입력 중단")
            return true
        }

        print("🔄 Combo 메모 '\(memo.title)' - 자식 \(values.count)개 순차 입력 (간격 \(memo.comboInterval)s)")
        insertComboValuesSequentially(values, interval: memo.comboInterval, index: 0, memoId: memoId)
        trackKeyboardPaste(memoId: memoId)
        return true
    }

    /// 콤보 자식 값들을 interval 간격으로 하나씩 입력(정책 A). 자동변수 치환 포함.
    private func insertComboValuesSequentially(_ values: [String], interval: TimeInterval, index: Int, memoId: UUID? = nil) {
        guard index < values.count else { return }

        if index < values.count - 1 {
            // 중간 단계 - 커서를 옮기면 다음 단계가 엉뚱한 자리에 들어간다.
            // 그래서 마지막 단계에서만 커서 토큰을 살린다.
            let processed = TemplateVariableProcessor.resolveCursor(in: processTemplateVariables(in: values[index])).text
            textDocumentProxy.insertText(processed)
            KeyboardHaptics.mediumTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                self?.insertComboValuesSequentially(values, interval: interval, index: index + 1, memoId: memoId)
            }
        } else {
            // 마지막 항목 - 여기서만 커서 위치를 반영하고 날인으로 마무리.
            insertProcessedText(values[index], memoId: memoId)
        }
    }

    private func handleTemplateInputComplete(_ notification: Notification) {
        print("✅ templateInputComplete 수신")
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String,
              let inputs = userInfo["inputs"] as? [String: String] else { return }

        let memoId = userInfo["memoId"] as? UUID
        let baseMemoId = userInfo["baseMemoId"] as? UUID

        var processedText = text
        print("   원본 텍스트: \(processedText)")

        for (placeholder, value) in inputs {
            print("   [\(placeholder)] -> [\(value)]")
            processedText = processedText.replacingOccurrences(of: placeholder, with: value)
        }

        processedText = processTemplateVariables(in: processedText)

        // v4.0.8: attached 흐름이면 base 메모 본문과 결합 (옵션 X - \n 이어붙이기)
        if let baseId = baseMemoId,
           let baseMemo = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == baseId }) {
            let combined = baseMemo.value.isEmpty ? processedText : "\(baseMemo.value)\n\(processedText)"
            print("🔗 [attachedTemplate] 결합 출력: \(combined)")
            insertResolvedText(combined, memoId: baseId)
            trackKeyboardPaste(memoId: baseId)
        } else {
            print("   최종 텍스트: \(processedText)")
            print("📝 textDocumentProxy.insertText 호출")
            insertResolvedText(processedText, memoId: memoId)
            trackKeyboardPaste(memoId: memoId)
        }
        print("✅ 입력 완료!")
    }

    @objc func spacePressed(button: UIButton) {
        print("⌨️ Space 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).insertText(" ")
    }

    @objc func returnPressed(button: UIButton) {
        print("↩️ Return 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).insertText("\n")
    }

    @objc private func handleLongPress(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            deleteStartTime = Date()
            // 즉시 첫 삭제 실행
            textDocumentProxy.deleteBackward()
            // 타이머 시작 (0.1초마다 삭제, 1초 이후에는 단어 단위로 삭제)
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(self.deleteStartTime ?? Date())
                if elapsed >= 1.0 {
                    self.deleteWordBackward()
                } else {
                    self.textDocumentProxy.deleteBackward()
                }
            }
        } else if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled {
            // 손가락을 떼면 타이머 중지
            deleteTimer?.invalidate()
            deleteTimer = nil
            deleteStartTime = nil
        }
    }

    /// 커서 앞의 공백/줄바꿈과 단어 하나를 한 번에 삭제
    private func deleteWordBackward() {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        var charsToDelete = 0
        var sawNonWhitespace = false
        for character in context.reversed() {
            let isBoundary = character.isWhitespace || character.isNewline
            if sawNonWhitespace && isBoundary {
                break
            }
            if !isBoundary {
                sawNonWhitespace = true
            }
            charsToDelete += 1
        }

        if charsToDelete == 0 {
            charsToDelete = 1
        }

        for _ in 0..<charsToDelete {
            textDocumentProxy.deleteBackward()
        }
    }

    @objc private func backSpacePressed(button: UIButton) {
        print("⬅️ Backspace 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).deleteBackward()
    }

    /// 키보드에서 메모 붙여넣기 시 App Group UserDefaults에 카운트 기록
    /// 메인 앱의 ReviewManager가 이 값을 동기화하여 리뷰 요청 트리거로 사용
    /// memoId가 주어지면 해당 메모의 clipCount + lastUsedAt도 업데이트한다.
    private func trackKeyboardPaste(memoId: UUID? = nil) {
        if let groupDefaults = AppGroup.defaults {
            let count = groupDefaults.integer(forKey: DefaultsKey.keyboardPasteCount) + 1
            groupDefaults.set(count, forKey: DefaultsKey.keyboardPasteCount)
            print("📊 [Keyboard] 붙여넣기 카운트: \(count)")
        }

        if let memoId {
            do {
                try MemoStore.shared.incrementClipCount(for: memoId)
            } catch {
                print("⚠️ [Keyboard] 사용량 업데이트 실패: \(error)")
            }
        }

        // 메모/콤보/템플릿 입력은 host의 textDidChange를 거치지 않을 수 있어 X 버튼 상태를 명시적으로 갱신.
        updateHasTextState()
    }

    deinit {
        deleteTimer?.invalidate()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func viewWillLayoutSubviews() {
        // 이 UIKit 버튼은 SwiftUI 호스팅 뷰에 완전히 가려 어차피 보이지 않는다.
        // 다음 키보드 전환은 KeyboardView의 지구본 버튼(categoryTabRow)이 담당한다.
        // 버튼 자체는 `handleInputModeList` 타깃 때문에 남겨 두고 숨기기만 한다.
        self.nextKeyboardButton.isHidden = true
        super.viewWillLayoutSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // iOS "전체 접근 허용" 상태를 익스텐션 전역에 반영.
        // 여기서 갱신하는 이유: 사용자가 설정에서 토글하면 익스텐션이 재시작되므로
        // 키보드가 뜰 때마다 읽으면 항상 최신이다.
        KeyboardCapability.update(hasFullAccess: hasFullAccess,
                                  needsInputModeSwitchKey: needsInputModeSwitchKey)
        // 등장 **전에** 한 번 재 둔다. 첫 프레임이 이미 제 높이로 그려지게 하는 것이라
        // 남긴다(등장 뒤에 부르는 것과는 성격이 다르다, `viewDidAppear` 참고).
        view.layoutIfNeeded()
        // 새 텍스트 필드에 키보드가 나타날 때마다 한글 컴포저 상태를 초기화.
        // 이전 필드에서 조합 중이던 음절이 새 필드에 딸려오는 버그를 방지한다.
        documentState.composerResetToken += 1
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ⚠️ 여기서 `view.layoutIfNeeded()` 를 부르지 않는다. 등장 애니메이션이 **끝난 뒤**라,
        //    이 시점의 레이아웃 변화는 사용자 눈에 한 번 더 움찔하는 것으로 보인다.
        //    높이는 `viewDidLoad` 에서 이미 옳게 세워지고(999 우선순위), 회전은
        //    `viewWillTransition` 이 회전 애니메이션 안에서 처리한다.
        // 호스트 필드가 이미 텍스트를 가진 채로 키보드가 떴을 때도 X 버튼이 즉시 보이도록 초기 상태 반영
        updateHasTextState()
        // App Group 비콘 - 키보드 사용 timestamp 기록 (메인 앱 launch 시 Analytics로 전송)
        KeyboardBeacon.recordUse()
        // 햅틱 엔진 사전 깨우기 - 첫 키 입력 지연 제거 (빠른 타이핑 시 버벅임 방지)
        KeyboardHaptics.prepare()
    }


    override func textWillChange(_ textInput: UITextInput?) {

    }

    override func textDidChange(_ textInput: UITextInput?) {
        var textColor: UIColor
        let proxy = self.textDocumentProxy
        if proxy.keyboardAppearance == UIKeyboardAppearance.dark {
            textColor = UIColor.white
        } else {
            textColor = UIColor.black
        }
        self.nextKeyboardButton.setTitleColor(textColor, for: [])
        // SwiftUI 관찰 가능한 hasText 상태 갱신 - clearAll(X) 버튼 표시 여부에 사용
        updateHasTextState()
        // 앞으로 옮겨 간 자리에서 글이 바뀌었으면 그 자리를 배운다.
        commitCaretWatchIfTyped()
        // 손이 멎으면 넣은 글이 어떤 모양이 됐는지 본다.
        restartEditSettleTimer()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        // 커서 이동 시에도 텍스트 존재 여부가 바뀔 수 있어 다시 확인
        updateHasTextState()
        // 넣은 글 안쪽으로 캐럿이 갔는지 적어 둔다(아직 배우지는 않는다).
        noteCaretMove()
    }

    private func updateHasTextState() {
        let proxy = self.textDocumentProxy
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        let hasAny = !before.isEmpty || !after.isEmpty
        // 리턴 키의 이름은 호스트가 정한다. 같은 자리에서 함께 읽어 둔다 - 이 함수가
        // 필드가 바뀔 때(viewDidAppear)와 글이 바뀔 때 모두 불리는 유일한 곳이라서다.
        // `UITextInputTraits` 의 선택 요구사항이라 옵셔널로 온다. 안 주면 기본 리턴이다.
        let wantedReturn = proxy.returnKeyType ?? .default
        // @Published 갱신은 메인 스레드에서
        let apply = { [weak self] in
            guard let self else { return }
            if self.documentState.hasText != hasAny { self.documentState.hasText = hasAny }
            if self.documentState.returnKeyType != wantedReturn { self.documentState.returnKeyType = wantedReturn }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func loadMemos() {
        do {
            let allMemos = try MemoStore.shared.load(type: .memo)
            print("📱 [KeyboardViewController.loadMemos] 메모 로드 완료 - 총 \(allMemos.count)개")

            let filtered = filterExcludedMemos(allMemos)
            let userFiltered = applyUserFilter(filtered)
            let sorted = sortMemos(userFiltered)

            populateKeyboardData(sorted)
            buildMemoData(sorted)
        } catch {
            print("❌ Error loading memos: \(error.localizedDescription)")
        }
    }

    /// 키보드에서 표시할 메모 필터 - 보안 메모는 표시하되 탭 시 인증 요구 (KeyboardView에서 처리)
    private func filterExcludedMemos(_ memos: [Memo]) -> [Memo] {
        return memos
    }

    /// 사용자 선택 필터(테마/템플릿/즐겨찾기) 적용
    private func applyUserFilter(_ memos: [Memo]) -> [Memo] {
        if let theme = selectedTheme {
            let result = memos.filter { $0.category == theme }
            print("   🏷️ 테마 필터 적용 (\(theme)) - \(result.count)개")
            return result
        } else if showOnlyTemplates {
            let result = memos.filter { $0.isTemplate }
            print("   🔍 템플릿 필터 적용 - \(result.count)개")
            return result
        } else if showOnlyFavorites {
            let result = memos.filter { $0.isFavorite }
            print("   ⭐ 즐겨찾기 필터 적용 - \(result.count)개")
            return result
        }
        return memos
    }

    /// clipKey/clipValue/clipMemoId/clipMemos 배열 채우기
    private func populateKeyboardData(_ memos: [Memo]) {
        clipKey = []
        clipValue = []
        clipMemoId = []
        clipMemos = []

        print("\n📋 [KeyboardViewController] 불러온 메모 상세 정보:")
        for (index, item) in memos.enumerated() {
            print("   [\(index)] =====================================")
            print("       ID: \(item.id)")
            print("       제목: \(item.title)")
            print("       값: \(item.value)")
            print("       카테고리: \(item.category)")
            print("       즐겨찾기: \(item.isFavorite)")
            print("       템플릿: \(item.isTemplate)")
            print("       보안: \(item.isSecure)")
            print("       수정일: \(item.lastEdited)")
            print("       사용횟수: \(item.clipCount)")
            print("       템플릿 변수: \(item.templateVariables)")
            print("       📦 플레이스홀더 값:")
            if item.placeholderValues.isEmpty {
                print("           (비어있음)")
            } else {
                for (placeholder, values) in item.placeholderValues {
                    print("           \(placeholder): \(values)")
                }
            }
            print("   ========================================\n")

            clipKey.append(item.title)
            clipValue.append(item.value)
            clipMemoId.append(item.id)
            clipMemos.append(item)
        }
        print("✅ [KeyboardViewController] clipMemos 배열에 \(clipMemos.count)개 저장 완료\n")
    }

    /// memoData 딕셔너리 채우기
    private func buildMemoData(_ memos: [Memo]) {
        for item in memos {
            memoData[item.title] = item.value
        }
    }

    /// 정렬 규칙은 앱 무대와 공유한다(KeyboardMemoFeed) - 두 곳에서 순서가 달라지지 않게.
    private func sortMemos(_ memos: [Memo]) -> [Memo] {
        KeyboardMemoFeed.sorted(memos)
    }

    // 템플릿 관련 함수들
    private func extractCustomPlaceholders(from text: String) -> [String] {
        TemplatePlaceholder.customTokens(in: text)
    }

    private func processTemplateVariables(in text: String) -> String {
        // 클립보드는 **토큰이 있을 때만** 읽는다. iOS 16+ 는 읽을 때마다 붙여넣기 프롬프트를
        // 띄우므로 미리 읽어 두면 아무 이유 없이 프롬프트가 뜬다.
        var clipboard: String?
        if TemplateVariableProcessor.containsClipboardToken(text) {
            if KeyboardCapability.hasFullAccess {
                clipboard = UIPasteboard.general.string
            } else {
                // 전체 접근이 없으면 클립보드를 못 읽는다. 조용히 빈칸을 넣으면
                // 사용자는 "왜 아무것도 안 들어왔지"만 알게 되므로 이유를 알려 준다.
                print("⚠️ [processTemplateVariables] 전체 접근 꺼짐 - {clipboard} 치환 불가")
                NotificationCenter.postOnMain(name: .needsFullAccess, object: nil)
            }
        }
        // 커서 토큰은 남긴다 - 바로 아래 insertProcessedText가 위치 계산에 쓴다.
        return TemplateVariableProcessor.process(text, clipboard: clipboard, keepCursorToken: true)
    }

    /// 문구를 실제로 넣는 단 하나의 경로.
    ///
    /// 자동 변수 치환 → 커서 위치 해석 → 삽입 → 캐럿 되돌리기 → 날인 순.
    /// 삽입 지점이 여러 곳(일반·템플릿·attached)이라 여기로 모아 두지 않으면
    /// 커서 토큰이 어떤 경로에서만 동작하는 사태가 난다.
    private func insertProcessedText(_ raw: String, memoId: UUID? = nil) {
        insertResolvedText(processTemplateVariables(in: raw), memoId: memoId)
    }

    /// 치환이 이미 끝난 텍스트를 커서 토큰만 해석해서 넣는다.
    /// (플레이스홀더 입력을 거친 경로는 치환을 자기가 하므로 이쪽으로 들어온다)
    ///
    /// `memoId` 가 있으면 캐럿 자리를 **배우고 써먹는다**(`CursorMemory`).
    /// 토큰이 이미 있으면 배우지도 쓰지도 않는다. 사용자가 직접 정한 자리가 언제나 이긴다.
    private func insertResolvedText(_ processed: String, memoId: UUID? = nil) {
        let resolved = TemplateVariableProcessor.resolveCursor(in: processed)
        let text = resolved.text
        // 넣기 **전**의 캐럿 앞뒤. 나중에 고쳐진 구간을 잘라낼 울타리로 쓴다.
        let headBeforeInsert = textDocumentProxy.documentContextBeforeInput ?? ""

        // 토큰이 없을 때만 배운 자리를 꺼내 쓴다.
        var offsetFromEnd = resolved.offsetFromEnd
        var usedLearned = false
        if resolved.offsetFromEnd == 0,
           let memoId,
           let learned = CursorMemory.offset(for: memoId, textLength: text.count) {
            offsetFromEnd = learned
            usedLearned = true
        }

        textDocumentProxy.insertText(text)
        if offsetFromEnd > 0 {
            // 삽입 직후 캐럿은 문장 끝에 있다 - 정해진 자리까지 되돌린다.
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -offsetFromEnd)
        }
        KeyboardHaptics.stamp()

        beginCaretWatchIfNeeded(memoId: memoId,
                                insertedText: text,
                                hasExplicitToken: resolved.offsetFromEnd > 0,
                                usedLearned: usedLearned)
        beginEditWatchIfNeeded(memoId: memoId,
                               insertedText: text,
                               headBeforeInsert: headBeforeInsert)
    }

    // MARK: - 캐럿 자리 배우기

    /// 넣은 뒤 지켜보기 시작. 이미 자리가 정해진 경우(토큰·학습값)에는 지켜보지 않는다.
    ///
    /// ⚠️ 처음 적용한 순간에만 한 줄 알린다. 조용히 해 주는 게 목적이라 매번 말하지 않고,
    ///    그렇다고 한 번도 안 알리면 사용자가 자기 키보드가 왜 이러는지 모른다.
    private func beginCaretWatchIfNeeded(memoId: UUID?,
                                         insertedText: String,
                                         hasExplicitToken: Bool,
                                         usedLearned: Bool) {
        guard let memoId else { caretWatch = nil; return }

        if usedLearned {
            caretWatch = nil
            if CursorMemory.markNoticedIfFirstTime(for: memoId) {
                NotificationCenter.postOnMain(name: .cursorMemoryApplied,
                                                object: nil,
                                                userInfo: ["memoId": memoId])
            }
            return
        }

        guard !hasExplicitToken, !insertedText.isEmpty else { caretWatch = nil; return }

        caretWatch = CaretWatch(memoId: memoId,
                                insertedText: insertedText,
                                beforeAtInsert: textDocumentProxy.documentContextBeforeInput ?? "",
                                candidateOffset: nil,
                                startedAt: Date())
    }

    /// 캐럿이 옮겨 갔다. 넣은 글 **안쪽**으로 간 것이면 후보로 적어 둔다.
    /// 아직 배우지는 않는다. 거기서 실제로 쓰기 시작해야 뜻이 있는 이동이다.
    private func noteCaretMove() {
        guard var watch = caretWatch else { return }
        guard Date().timeIntervalSince(watch.startedAt) <= caretWatchWindow else {
            caretWatch = nil
            return
        }
        let now = textDocumentProxy.documentContextBeforeInput ?? ""
        guard let offset = CursorMemory.offsetFromCaretMove(insertedText: watch.insertedText,
                                                            beforeContextAtInsert: watch.beforeAtInsert,
                                                            beforeContextNow: now) else { return }
        watch.candidateOffset = offset
        caretWatch = watch
    }

    /// 옮겨 간 자리에서 글이 바뀌었다. 이제야 "거기가 시작점이었다"고 볼 수 있다.
    private func commitCaretWatchIfTyped() {
        guard let watch = caretWatch, let offset = watch.candidateOffset else { return }
        caretWatch = nil
        guard Date().timeIntervalSince(watch.startedAt) <= caretWatchWindow else { return }
        CursorMemory.observe(memoId: watch.memoId,
                             offsetFromEnd: offset,
                             textLength: watch.insertedText.count)
    }

    // MARK: - 고친 자리 알아채기

    /// 넣은 글이 결국 어떤 모양이 되는지 지켜보기 시작.
    /// 이미 물어봤거나 거절한 단축어는 지켜보지 않는다.
    private func beginEditWatchIfNeeded(memoId: UUID?, insertedText: String, headBeforeInsert: String) {
        cancelEditSettleTimer()
        guard let memoId,
              !insertedText.isEmpty,
              insertedText.count <= EditPattern.maxTextLength else { editWatch = nil; return }

        let record = EditPattern.record(for: memoId)
        guard record?.declined != true, record?.asked != true else { editWatch = nil; return }

        editWatch = EditWatch(memoId: memoId,
                              insertedText: insertedText,
                              headBeforeInsert: headBeforeInsert,
                              tailAtInsert: textDocumentProxy.documentContextAfterInput ?? "",
                              startedAt: Date())
    }

    /// 글이 바뀔 때마다 "다 썼나" 재는 시계를 다시 건다.
    /// 남의 앱 보내기 버튼은 볼 수 없어서, 손이 멎은 것으로 대신한다.
    private func restartEditSettleTimer() {
        guard editWatch != nil else { return }
        cancelEditSettleTimer()
        editSettleTimer = Timer.scheduledTimer(withTimeInterval: editSettleDelay, repeats: false) { [weak self] _ in
            self?.evaluateEditWatch()
        }
    }

    private func cancelEditSettleTimer() {
        editSettleTimer?.invalidate()
        editSettleTimer = nil
    }

    /// 손이 멎었다. 넣은 글이 어떤 모양이 됐는지 잘라내 견준다.
    ///
    /// ⚠️ 울타리(앞뒤 글)가 그대로일 때만 본다. 울타리가 흔들렸다는 건 사용자가
    ///    넣은 글 **바깥**까지 손댔다는 뜻이라, 잘라낸 구간이 넣은 글이라고 믿을 수 없다.
    private func evaluateEditWatch() {
        cancelEditSettleTimer()
        guard let watch = editWatch else { return }
        editWatch = nil

        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let whole = before + after

        guard whole.hasPrefix(watch.headBeforeInsert), whole.hasSuffix(watch.tailAtInsert) else { return }
        let middle = String(whole.dropFirst(watch.headBeforeInsert.count).dropLast(watch.tailAtInsert.count))
        guard !middle.isEmpty else { return }

        guard let diff = EditPattern.diff(inserted: watch.insertedText, edited: middle) else { return }
        guard let suggestion = EditPattern.observe(memoId: watch.memoId,
                                                   diff: diff,
                                                   textLength: watch.insertedText.count) else { return }

        EditPattern.markAsked(for: watch.memoId)
        NotificationCenter.postOnMain(name: .editPatternSuggestion,
                                        object: nil,
                                        userInfo: ["memoId": watch.memoId,
                                                   "suggestion": suggestion.rawValue])
    }

}

extension String {
    func textSize() -> CGFloat {
        let font: UIFont = UIFont(name: "Helvetica", size: 15) ?? .systemFont(ofSize: 15)
        return self.size(withAttributes: [NSAttributedString.Key.font: font]).width
    }
}

final class EmptyListView: UIView {

    init() {
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Create the image view
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: AppSymbol.eyes)
        imageView.contentMode = .scaleAspectFit

        // Create the title label
        let titleLabel = UILabel()
        titleLabel.text = "Nothing to Paste"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center

        // Create the body label
        let bodyLabel = UILabel()
        bodyLabel.text = Constants.emptyDescription
        bodyLabel.font = UIFont.systemFont(ofSize: 16)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = UIColor.black.withAlphaComponent(0.7)

        // Create a vertical stack view
        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, bodyLabel])
        stackView.axis = .vertical
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        // Constraints for the stack view
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30)
        ])

        // Constraints for the image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 45),
            imageView.widthAnchor.constraint(equalToConstant: 45)
        ])
    }
}

extension UIView {
    func addKeyboardSubview(_ subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leftAnchor.constraint(equalTo: leftAnchor),
            subview.rightAnchor.constraint(equalTo: rightAnchor),
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - TypingInputProxy

extension KeyboardViewController: TypingInputProxy {
    /// 키보드 host 앱 텍스트 필드에 문자 입력
    /// 자체 입력은 host의 textDidChange를 거치지 않으므로 hasText를 명시적으로 갱신.
    func insertText(_ text: String) {
        print("⌨️ [TypingProxy.insertText] '\(text)': hasInput=\(textDocumentProxy.hasText)")
        textDocumentProxy.insertText(text)
        updateHasTextState()
    }
    /// 한 글자 삭제
    func deleteBackward() {
        print("⌨️ [TypingProxy.deleteBackward]")
        textDocumentProxy.deleteBackward()
        updateHasTextState()
    }
    /// 엔터 입력
    func insertNewline() {
        print("⌨️ [TypingProxy.insertNewline]")
        textDocumentProxy.insertText("\n")
        updateHasTextState()
    }
    /// `advanceToNextInputMode()`는 UIInputViewController에 이미 있어 별도 구현 불요.
    ///
    /// ⚠️ 다만 지구본 키는 그쪽을 쓰지 않는다 - 아래 `attachInputModeSwitch(to:)` 참고.

    /// 지구본 키를 iOS 가 직접 다루게 넘긴다.
    ///
    /// 왜 우리가 처리하면 안 되나: `advanceToNextInputMode()` 는 **글자 키보드만** 돈다.
    /// 이모지 키보드는 그 회전에 끼지 않아서, 다른 키보드를 함께 쓰는 사람이 지구본을
    /// 몇 번을 눌러도 이모지에 닿지 못한다(사용자 제보).
    /// `handleInputModeList(from:with:)` 는 시스템 지구본과 **같은 물건**이라
    /// 탭은 다음 키보드로 넘기고, 길게 누르면 이모지가 들어 있는 목록을 띄운다.
    /// 단 이 동작은 UIControl 의 터치 이벤트를 통째로 받아야 나오므로
    /// `.allTouchEvents` 로 붙인다(일부만 붙이면 길게 누르기가 죽는다).
    func attachInputModeSwitch(to button: UIButton) {
        button.addTarget(self,
                         action: #selector(handleInputModeList(from:with:)),
                         for: .allTouchEvents)
    }

    func cursorRight() {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
    }
    func clearAll() {
        guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else { return }
        for _ in before { textDocumentProxy.deleteBackward() }
        updateHasTextState()
    }
}

// MARK: - 키 클릭음

/// iOS에 "이 입력 뷰는 키 클릭음을 낸다"고 알린다.
///
/// 이걸 채택하지 않으면 `UIDevice.current.playInputClick()` 을 아무리 호출해도
/// **조용히 무시된다.** 반대로 채택했다고 항상 울리는 것도 아니다
/// 실제 재생 여부는 사용자의 **설정 > 사운드 및 햅틱 > 키보드 클릭음** 이 정한다.
/// 우리가 켜고 끄는 게 아니라 사용자가 이미 정해 둔 취향을 따르는 구조다.
extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

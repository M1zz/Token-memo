//
//  KeyboardViewController.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/05/24.
//

import UIKit

typealias KeyboardData = [String:String]
var displayKeyboardData: KeyboardData = [:]
var clipboardData: KeyboardData = [:]
var tokenMemoData: KeyboardData = [:]

class KeyboardViewController: UIInputViewController {
    
    @IBOutlet var nextKeyboardButton: UIButton!
    private let flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 0
        return layout
    }()
    
    private lazy var customCollectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.isScrollEnabled = true
        view.showsHorizontalScrollIndicator = true
        view.showsVerticalScrollIndicator = false
        view.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.contentInset = .zero
        view.backgroundColor = .systemGray5
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    let backButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.black.cgColor
        button.setImage(UIImage(systemName: "delete.backward"), for: .normal)
        button.tintColor = .black
        button.backgroundColor = .systemGray2
        button.setTitleColor(.black, for: .normal)
        return button
    }()
    
    let spaceButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(equalToConstant: "Space".textSize() + 20).isActive = true
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.black.cgColor
        button.setTitle("Space", for: UIControl.State.normal)
        button.titleLabel!.font = .systemFont(ofSize: 12)
        button.backgroundColor = UIColor.white
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        button.addTarget(KeyboardViewController.self, action: #selector(spacePressed), for: .touchUpInside)
        return button
    }()
    
    let returnButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(equalToConstant: "Return".textSize() + 20).isActive = true
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.black.cgColor
        button.setTitle("Return", for: UIControl.State.normal)
        button.titleLabel!.font = .systemFont(ofSize: 12)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(UIColor.white, for: UIControl.State.normal)
        button.addTarget(KeyboardViewController.self, action: #selector(returnPressed), for: .touchUpInside)
        return button
    }()
    
    let addButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.black.cgColor
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .black
        button.backgroundColor = .systemGray2
        button.setTitleColor(.black, for: .normal)
        return button
    }()
    
    let textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .roundedRect
        textField.placeholder = "Enter text"
        return textField
    }()
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNextKeyboardButton()
        
        do {
            let temp = try MemoStore.shared.load(type: .tokenMemo)
            var tempDic: [String:String] = [:]
            for item in temp {
                tempDic[item.title] = item.value
                tokenMemoData[item.title] = item.value
            }
            
//            let temp2 = try MemoStore.shared.load(type: .clipboardMemo)
            var tempDic2: [String:String] = [:]
//            for item in temp2 {
//                tempDic2[item.title] = item.value
//                clipboardData[item.title] = item.value
//            }
            
            displayKeyboardData = tempDic
        } catch {
            fatalError(error.localizedDescription)
        }
        
        view.addSubview(customCollectionView)
        let bottomView = UIView(frame: CGRect.init(x: 0, y: 0, width: 320, height: 30))
        view.addSubview(bottomView)
        
        customCollectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        customCollectionView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        customCollectionView.bottomAnchor.constraint(equalTo: bottomView.topAnchor).isActive = true
        customCollectionView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        customCollectionView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        customCollectionView.register(CollectionViewCell.classForCoder(), forCellWithReuseIdentifier: "cellIdentifier")
        customCollectionView.dataSource = self
        customCollectionView.delegate = self
        
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.topAnchor.constraint(equalTo: customCollectionView.bottomAnchor).isActive = true
        bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        bottomView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        bottomView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        bottomView.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        bottomView.addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor).isActive = true
        addButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        addButton.addTarget(self, action: #selector(openAppPressed), for: .touchUpInside)
        
        bottomView.addSubview(spaceButton)
        spaceButton.translatesAutoresizingMaskIntoConstraints = false
        spaceButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor).isActive = true
        spaceButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        spaceButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        spaceButton.addTarget(self, action: #selector(spacePressed), for: .touchUpInside)
        
        bottomView.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.leadingAnchor.constraint(equalTo: spaceButton.trailingAnchor).isActive = true
        backButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        backButton.addTarget(self, action: #selector(backSpacePressed), for: .touchUpInside)
        
        bottomView.addSubview(returnButton)
        returnButton.translatesAutoresizingMaskIntoConstraints = false
        returnButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor).isActive = true
        returnButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor).isActive = true
        returnButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        returnButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.numberOfTouchesRequired = 1
        longPress.allowableMovement = 0.5
        backButton.addGestureRecognizer(longPress)
    }
    
    @objc func spacePressed(button: UIButton) {
        (textDocumentProxy as UIKeyInput).insertText(" ")
    }
    
    @objc func returnPressed(button: UIButton) {
        (textDocumentProxy as UIKeyInput).insertText("\n")
    }
    
    @objc private func handleLongPress(_ gestureRecognizer: UIGestureRecognizer) {
        textDocumentProxy.deleteBackward()
    }
    
    @objc private func backSpacePressed(button: UIButton) {
        (textDocumentProxy as UIKeyInput).deleteBackward()
    }
    
    @objc func openURL(_ url: URL) {
        return
    }

    @objc private func openAppPressed(button: UIButton) {
        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: URL(string: "tokenMemo://com.Ysoup.TokenMemo")!)
                return
            }
            responder = responder?.next
        }
    }
    
    override func viewWillLayoutSubviews() {
        self.nextKeyboardButton.isHidden = !self.needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
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
    }
}

extension KeyboardViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayKeyboardData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        var tempKeys:[String] = []
        for key in displayKeyboardData.keys {
            tempKeys.append(key)
        }
        
        guard let cell = customCollectionView.dequeueReusableCell(withReuseIdentifier: "cellIdentifier", for: indexPath) as? CollectionViewCell else {
            return CollectionViewCell()
        }
        cell.setTitle(tempKeys[indexPath.row])
        cell.delegate = self
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var tempKeys:[String] = []
        for key in displayKeyboardData.keys {
            tempKeys.append(key)
        }
        
        let label = UILabel(frame: .zero)
        label.text = tempKeys[indexPath.row]
        label.sizeToFit()
        
        if label.frame.width > 150 {
            return CGSize(width: 150, height: 40)
        } else {
            return CGSize(width: label.frame.width + 20, height: 40)
        }
    }
}

extension KeyboardViewController: TextInput {
    func tapped(text: String) {
        let proxy = textDocumentProxy as UIKeyInput
        proxy.insertText(text)
    }
}

extension String {
    func textSize() -> CGFloat {
        return self.size(withAttributes: [NSAttributedString.Key.font: UIFont(name: "Helvetica", size: 15)]).width
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
        imageView.image = UIImage(systemName: "eyes")
        imageView.contentMode = .scaleAspectFit
        
        // Create the title label
        let titleLabel = UILabel()
        titleLabel.text = "Nothing to Paste"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center
        
        // Create the body label
        let bodyLabel = UILabel()
        bodyLabel.text = "You can tap the '+' button to add a phrase or any common text that you want to easily access from iMessages, Mail or other apps"
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

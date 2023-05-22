//
//  KeyboardViewController.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/05/22.
//

import UIKit

var keyboardData:[String:String] = ["계좌번호":"12341234", "집주소":"포항시"]
class KeyboardViewController: UIInputViewController {

    @IBOutlet var nextKeyboardButton: UIButton!
    private let layout: UICollectionViewFlowLayout = {
        let guideline = UICollectionViewFlowLayout()
//        guideline.scrollDirection = .vertical
        guideline.minimumLineSpacing = 50
        guideline.minimumInteritemSpacing = 0
        return guideline
    }()
    
    private lazy var customCollectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        view.isScrollEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = true
        view.scrollIndicatorInsets = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 4)
        view.contentInset = .zero
        view.backgroundColor = .systemGray5
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
    private func configNextKeyboardButton() {
        // Perform custom UI setup here
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
        
        do {
            let temp = try MemoStore.shared.load()
            var tempDic: [String: String] = [:]
            for item in temp {
                tempDic[item.title] = item.value
            }
            keyboardData = tempDic
        } catch {
            fatalError(error.localizedDescription)
        }
        
        configNextKeyboardButton()
        
        // customViewStart
        customCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(customCollectionView)
        let row = UIView(frame: CGRect.init(x: 0, y: 0, width: 320, height: 30))
        self.view.addSubview(row)
        row.backgroundColor = UIColor.blue

        customCollectionView.anchor(top: view.topAnchor, left: view.leftAnchor, bottom: row.topAnchor, right: view.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingRight: 0)
        customCollectionView.anchor(height: 200)
        customCollectionView.register(CollectionViewCell.classForCoder(), forCellWithReuseIdentifier: "cellIdentifier")
        customCollectionView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        collectionViewDelegate()

        row.translatesAutoresizingMaskIntoConstraints = false
        //categoryRow.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = .systemGray5
        row.anchor(top: customCollectionView.bottomAnchor, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0)
        row.anchor(height: 50)

        let backButton = createBackButton(name: "<=")

        row.addSubview(backButton)
        backButton.centerY(inView: row)
        backButton.centerX(inView: row)
    }
    
    private func collectionViewDelegate() {
        customCollectionView.delegate = self
        customCollectionView.dataSource = self
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
        return 1//keyboardData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        var tempKeys:[String] = []
        for key in keyboardData.keys {
            tempKeys.append(key)
        }
        
        guard let cell = customCollectionView.dequeueReusableCell(withReuseIdentifier: "cellIdentifier", for: indexPath) as? CollectionViewCell else {return CollectionViewCell()}
        cell.delegate = self
        cell.title = tempKeys
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.frame.width
        let size = CGSize(width: width, height: 50)
        return size
    }
    
    func textSize(text: String) -> CGFloat {
        return (text as NSString).size(withAttributes: [NSAttributedString.Key.font: UIFont(name: "Helvetica", size: 17)!]).width
    }
    
    @objc func backSpacePressed(button: UIButton) {
        (textDocumentProxy as UIKeyInput).deleteBackward()
    }
    
    private func createBackButton(name: String) -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        button.widthAnchor.constraint(equalToConstant: textSize(text: name) + 22).isActive = true
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.black.cgColor
//        button.setTitle(name, for: UIControl.State.normal)
        button.setImage(UIImage(systemName: "delete.backward"), for: UIControl.State.normal)
        button.backgroundColor = UIColor.systemGray2
        button.tintColor = UIColor.black
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        button.addTarget(self, action: #selector(backSpacePressed), for: .touchUpInside)
        return button
    }
}

extension KeyboardViewController: TextInput {
    func tapped(text: String) {
        let proxy = textDocumentProxy as UIKeyInput
        proxy.insertText(text)
    }
}

protocol TextInput {
    func tapped(text: String)
}



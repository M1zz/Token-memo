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
    
    let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["memo list", "clip board"])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        return control
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
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
    private func configureNextKeyboardButton() {
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
        configureNextKeyboardButton()
        
        do {
            let temp = try MemoStore.shared.load(type: .tokenMemo)
            var tempDic: [String:String] = [:]
            for item in temp {
                tempDic[item.title] = item.value
                tokenMemoData[item.title] = item.value
            }
            
            let temp2 = try MemoStore.shared.load(type: .clipboardMemo)
            var tempDic2: [String:String] = [:]
            for item in temp2 {
                tempDic2[item.title] = item.value
                clipboardData[item.title] = item.value
            }
            
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
        
        bottomView.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor).isActive = true
        backButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        backButton.addTarget(self, action: #selector(backSpacePressed), for: .touchUpInside)
        
        bottomView.addSubview(segmentedControl)
        segmentedControl.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor).isActive = true
        segmentedControl.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        segmentedControl.trailingAnchor.constraint(equalTo: backButton.leadingAnchor).isActive = true
        segmentedControl.addTarget(self, action: #selector(didChangeValue(segment:)), for: .valueChanged)
    }
    
    @objc private func didChangeValue(segment: UISegmentedControl) {
        if let key = UIPasteboard.general.string  {
            clipboardData[key] = key
        }
        
        if segmentedControl.selectedSegmentIndex == 0 {
            displayKeyboardData = tokenMemoData
        } else {
            displayKeyboardData = clipboardData
        }
        customCollectionView.reloadData()
    }
    
    @objc private func backSpacePressed(button: UIButton) {
        (textDocumentProxy as UIKeyInput).deleteBackward()
    }
    
    override func viewWillLayoutSubviews() {
        self.nextKeyboardButton.isHidden = !self.needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
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
        var tempKeys2:[String] = []
        if segmentedControl.selectedSegmentIndex == 0 {
            for key in displayKeyboardData.keys {
                tempKeys.append(key)
            }
            //keyBoardData = keyBoardMemoData
        } else {
            for key in clipboardData.keys {
                tempKeys2.append(key)
            }
        }
        
        
        guard let cell = customCollectionView.dequeueReusableCell(withReuseIdentifier: "cellIdentifier", for: indexPath) as? CollectionViewCell else {
            return CollectionViewCell()
        }
        if segmentedControl.selectedSegmentIndex == 0 {
            cell.setTitle(tempKeys[indexPath.row])
        } else {
            cell.setTitle(tempKeys2[indexPath.row])
        }
        
        cell.delegate = self
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var tempKeys:[String] = []
        
        if segmentedControl.selectedSegmentIndex == 0 {
            for key in displayKeyboardData.keys {
                tempKeys.append(key)
            }
        } else {
            for key in clipboardData.keys {
                tempKeys.append(key)
            }
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

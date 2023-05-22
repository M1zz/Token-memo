import UIKit

var keyboardData:[String:String] = ["계좌번호":"12341234", "집주소":"포항시"]
class KeyboardViewController: BaseInputViewController {
    
    @IBOutlet var nextKeyboardButton: UIButton!

    private var data: [String] = []

    private let collectionViewFlowLayout = UICollectionViewFlowLayout()
        .builder()
        .minimumLineSpacing(5)
        .minimumInteritemSpacing(5)
        .sectionInset(UIEdgeInsets(top: 20, left: 10, bottom: 0, right: 10))
        .estimatedItemSize(UICollectionViewFlowLayout.automaticSize)
        .build()
    
    private lazy var customCollectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewFlowLayout)
        .builder()
        .isScrollEnabled(true)
        .showsVerticalScrollIndicator(false)
        .showsHorizontalScrollIndicator(true)
        .scrollIndicatorInsets(.zero)
        .contentInset(.zero)
        .backgroundColor(.systemGray5)
        .clipsToBounds(false)
        .with {
            $0.register(
                CollectionViewCell.self,
                forCellWithReuseIdentifier: CollectionViewCell.reuseIdentifier
            )
        }
        .build()
    /// Row View
    private let row = UIView()
        .builder()
        .backgroundColor(.systemGray5)
        .build()
    /// Back Button
    private let backButton = UIButton()
        .builder()
        .backgroundColor(.systemGray2)
        .tintColor(.black)
        .with {
            $0.layer.cornerRadius = 8
            $0.setImage(UIImage(systemName: "delete.backward"), for: UIControl.State.normal)
        }
        .build()
    // MARK: - Method
    /// Set delegate
    override func setDelegate() {
        customCollectionView.dataSource = self
        customCollectionView.delegate = self
    }
    /// Set Up
    override func setUp() {
        configNextKeyboardButton()
    }
    /// add subviews
    override func addView() {
        view.addSubViews(customCollectionView, row)
        row.addSubview(backButton)
    }
    /// set Layout
    override func setLayout() {
        customCollectionView.anchor(
            top: view.topAnchor,
            leading: view.leadingAnchor,
            trailing: view.trailingAnchor,
            height: 200
        )
        row.anchor(
            top: customCollectionView.bottomAnchor,
            leading: view.leadingAnchor,
            bottom: view.bottomAnchor,
            trailing: view.trailingAnchor,
            height: 50
        )
        backButton.center(inView: row)
        backButton.anchor(width: 36, height: 36)
    }
    /// bind data
    override func bind() {
        do {
            let temp = try MemoStore.shared.load()
            var tempDic: [String: String] = [:]
            for item in temp {
                tempDic[item.title] = item.value
            }
            keyboardData = tempDic
            keyboardData.keys.forEach {
                data.append($0)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

// MARK: - Extensions
/// Default Keyboard Extension Setting
extension KeyboardViewController {
    override func viewWillLayoutSubviews() {
        self.nextKeyboardButton.isHidden = !self.needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {}
    
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
}

/// CollectionView Datasource
extension KeyboardViewController: UICollectionViewDataSource {
    /// Cell Count
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data.count
    }
    /// Cell Setting
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? CollectionViewCell else { return UICollectionViewCell() }
        cell.bind(data[indexPath.row])
        return cell
    }
}
/// CollectionView Delegate Flow Layout
extension KeyboardViewController: UICollectionViewDelegateFlowLayout {
    /// Cell Did Select
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let proxy = textDocumentProxy as UIKeyInput
        proxy.insertText(data[indexPath.row])
    }
    /// CollectionView Cell Size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: .zero, height: 40)
    }
}

import UIKit

class BaseCollectionViewCell<T>: UICollectionViewCell, Reusable {
    /// 화면 정보를 가져옴
    let bound = UIWindow().bounds.size
    /// model로 지정된 타입을 저장하고 바인딩 함
    var model: T? {
        didSet { if let model = model { bind(model) } }
    }
    /// 초기화
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
        addView()
        setLayout()
    }
    /// Required init 사용 안함
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /// Layout Subviews
    override func layoutSubviews() {
        super.layoutSubviews()
        setLayoutSubviews()
    }
    
    // MARK: Method
    /// SetUp CollectionViewCell
    func setUp() {}
    /// Add SubViews
    func addView() {}
    /// Set Layout
    func setLayout() {}
    /// Set Layout Subviews
    func setLayoutSubviews() {}
    /// Bind Data
    func bind(_ model: T) {}
}

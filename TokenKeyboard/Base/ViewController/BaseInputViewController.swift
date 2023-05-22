import UIKit

class BaseInputViewController: UIInputViewController {
    // MARK: - Property
    /// Receive full screen size value
    let bound = UIWindow().bounds.size
    
    // MARK: - LifeCycle
    /// ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        setDelegate()
        setUp()
        addView()
        setLayout()
        bind()
    }
    /// View Did Layout Subviews
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setLayoutSubviews()
    }
    
    // MARK: - Method
    func setDelegate() {}
    /// SetUp ViewController
    func setUp() {}
    /// Add SubViews
    func addView() {}
    /// Set Layout
    func setLayout() {}
    /// Set Layout Subviews
    func setLayoutSubviews() {}
    /// Bind Action
    func bind() {}
}

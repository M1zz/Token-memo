import UIKit

extension UIView {
    /// Multiple Views can be added at once.
    func addSubViews(_ subView: UIView...) {
        subView.forEach(addSubview(_:))
    }
}

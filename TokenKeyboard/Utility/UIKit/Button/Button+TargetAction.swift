import UIKit

extension UIButton {
    /// Target Closure Type
    typealias ButtonTargetClosure = (UIButton) -> Void

    /// Button Closure Wrapper
    private class ButtonClosureWrapper: NSObject {
        let closure: ButtonTargetClosure
        init(_ closure: @escaping ButtonTargetClosure) {
            self.closure = closure
        }
    }
    /// Associated Keys
    private struct AssociatedKeys {
        static var targetClosure = "targetClosure"
    }

    /// target Closure type Property
    private var targetClosure: ButtonTargetClosure? {
        get {
            guard let closureWrapper = objc_getAssociatedObject(self, &AssociatedKeys.targetClosure) as? ButtonClosureWrapper else { return nil }
            return closureWrapper.closure
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self,
                                     &AssociatedKeys.targetClosure,
                                     ButtonClosureWrapper(newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// Run Action Closer internally
    @objc func actionClosure() {
        guard let targetClosure = targetClosure else { return }
        targetClosure(self)
    }
    /// Function to use addTarget
    func addTarget(for event: UIButton.Event, closure: @escaping ButtonTargetClosure) {
        targetClosure = closure
        addTarget(self, action: #selector(UIButton.actionClosure), for: event)
    }
}

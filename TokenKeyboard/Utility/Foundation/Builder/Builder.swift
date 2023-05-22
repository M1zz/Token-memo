/// https://github.com/pelagornis/Builder
import Foundation
import UIKit

/// Protocol required to support builder patterns.
public protocol BuilderCompatible {
    associatedtype Base
    func builder() -> Builder<Base>
}

extension BuilderCompatible {
    public func builder() -> Builder<Self> {
        Builder(self)
    }
}

extension UIEdgeInsets: BuilderCompatible {}
extension UIOffset: BuilderCompatible {}
extension UIRectEdge: BuilderCompatible {}

extension Array: BuilderCompatible {}
extension Dictionary: BuilderCompatible {}
extension Set: BuilderCompatible {}
extension JSONDecoder: BuilderCompatible {}
extension JSONEncoder: BuilderCompatible {}
extension NSObject: BuilderCompatible {}

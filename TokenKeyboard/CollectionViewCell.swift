import UIKit

/// Class 성능 향상을 위한 Final
final class CollectionViewCell: BaseCollectionViewCell<String> {
    // MARK: - Property
    private let memberNameLabel = UILabel()
        .builder()
        .textColor(.black)
        .with {
            $0.sizeToFit()
        }
        .build()
    
    // MARK: - Method
    override func setUp() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 20
    }
    override func addView() {
        contentView.addSubview(memberNameLabel)
    }
    override func setLayout() {
        memberNameLabel.anchor(
            leading: contentView.leadingAnchor,
            trailing: contentView.trailingAnchor,
            paddingLeading: 15,
            paddingTrailing: 15
        )
        memberNameLabel.centerY(inView: contentView)
    }
    
    /// Bind
    override func bind(_ model: String) {
        memberNameLabel.text = model
    }
}

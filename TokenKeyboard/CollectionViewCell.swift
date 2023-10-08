//
//  CollectionViewCell.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/05/31.
//

import UIKit

protocol TextInput {
    func tapped(text: String)
}

class CollectionViewCell: UICollectionViewCell {
    
    var delegate: TextInput?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = .white
        label.textColor = .black
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.layer.borderWidth = 1.0
        label.layer.borderColor = UIColor.black.cgColor
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCell))
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = contentView.bounds
    }
    
    func setTitle(_ title: String) {
        titleLabel.text = title
    }
    
    @objc func didTapCell() {
        
        if let index = clipKey.firstIndex(of: titleLabel.text!) {
            let tappedText = clipValue[index]
            delegate?.tapped(text: tappedText)
        }
    }
}

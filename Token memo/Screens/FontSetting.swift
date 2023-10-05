//
//  FontSetting.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/07.
//

import SwiftUI

enum FontSize: CGFloat {
    case small = 16
    case medium = 20
    case large = 24
}


struct FontSetting: View {
    
    @State private var fontSize: CGFloat = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
    
    var body: some View {
        VStack {
            Text("이 사이즈로 내용이 보입니다.")
                .font(.system(size: fontSize))
                .padding()
            
            Slider(value: Binding(
                get: {
                    self.fontSize
                },
                set: {
                    self.fontSize = $0
                    saveFontSize()
                }
            ), in: 10...40, step: 2)
            .padding()
            .padding()
        }
    }
    
    func saveFontSize() {
        UserDefaults.standard.set(fontSize, forKey: "fontSize")
    }
}

struct FontSetting_Previews: PreviewProvider {
    static var previews: some View {
        FontSetting()
    }
}

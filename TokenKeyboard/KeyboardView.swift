//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI

struct KeyboardView: View {
//    var hashTagArray: [String] = ["#Lorem", "#Ipsum", "#dolor", "#consectetur", "#adipiscing", "#elit", "#Nam", "#semper", "#sit", "#amet", "#ut", "#eleifend", "#Cras"]
    
    private var gridItemLayout = [GridItem(.adaptive(minimum: 100))]
    
    var body: some View {
        ScrollView{
            LazyVGrid(columns: gridItemLayout , spacing: 5)  {
                ForEach(clipKey.indices, id:\.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 1, y: 2)
                        HStack {
                            Button {
                                UIImpactFeedbackGenerator().impactOccurred()
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addTextEntry"), object: clipValue[i])
                            } label: {
                                Text(clipKey[i])
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .padding([.top, .bottom], 12)
                                    .padding([.leading, .trailing])
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: UIScreen.main.bounds.size.width)
    }
}

#Preview {
    KeyboardView()
}

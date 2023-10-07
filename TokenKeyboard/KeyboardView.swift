//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI

struct KeyboardView: View {
    
    private var gridItemLayout = [GridItem(.adaptive(minimum: 130))]
    
    var body: some View {
        ZStack {
            Color("KeyboardBackground").ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: gridItemLayout , spacing: 5)  {
                    ForEach(clipKey.indices, id:\.self) { i in
                        
                        HStack {
                            Button {
                                UIImpactFeedbackGenerator().impactOccurred()
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addTextEntry"), object: clipValue[i])
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundColor(Color("KeyColor"))
                                        .shadow(color: Color.black.opacity(0.5), radius: 1, y: 2)
                                    Text(clipKey[i])
                                        .foregroundStyle(Color(uiColor: .label))
                                        .lineLimit(1)
                                        .padding([.top, .bottom], 12)
                                        .padding([.leading, .trailing])
                                        .bold()
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
}

#Preview {
    KeyboardView()
}

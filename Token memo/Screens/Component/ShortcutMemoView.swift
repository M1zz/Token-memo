//
//  ShortcutMemoView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/04.
//

import SwiftUI

struct ShortcutMemoView: View {
    
    @Binding var keyword: String
    @Binding var value: String
    @Binding var tokenMemos:[Memo]
    @Binding var originalData:[Memo]
    @Binding var showShortcutSheet: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .foregroundColor(Color(UIColor.systemBackground))
            HStack {
                VStack {
                    HStack {
                        Text(Constants.addNewToken)
                            .padding(.vertical, 5)
                            .font(.title3)
                            .bold()
                        Spacer()
                    }
                    HStack {
                        Text(value)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer()
                        
                    }
                }
                
                Button {
                    showShortcutSheet.toggle()
                } label: {
                    Image(systemName: "x.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                        .padding(.horizontal)
                        .foregroundColor(.red)
                        
                }
                
                NavigationLink {
                    MemoAdd(insertedValue: value)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                
                    
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                showShortcutSheet = false
            }
        }
        .frame(maxHeight: 150)
        .padding()
        //.presentationDetents([.height(200)])
    }
}

struct ShortcutMemoView_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutMemoView(keyword: .constant("testKeyword"),
                         value: .constant("testValue"),
                         tokenMemos: .constant(Memo.dummyData),
                         originalData: .constant(Memo.dummyData),
                         showShortcutSheet: .constant(true))
    }
}

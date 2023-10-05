//
//  SettingView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI
import StoreKit

struct SettingView: View {
    
    @Environment(\.requestReview) var requestReview
    
    var body: some View {
        List {
            NavigationLink(destination: CopyTutorialView()) {
                Text("복사 사용방법 튜토리얼")
            }
            
            NavigationLink(destination: KeyboardTutorialView()) {
                Text("키보드 사용방법 튜토리얼")
            }
            
            NavigationLink(destination: FontSetting()) {
                Text("앱 내 폰트 크기 변경")
            }

            NavigationLink(destination: CopyPasteView()) {
                Text("붙여넣기 알림이 귀찮으신가요?")
            }
            
            NavigationLink(destination: ReviewWriteView()) {
                Text("리뷰 및 평점 매기기")
            }
        }
    }
}

struct CopyPasteView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL.init(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
}

struct ReviewWriteView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: "https://apps.apple.com/app/id1543660502?action=write-review") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
}



struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

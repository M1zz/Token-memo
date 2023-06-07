//
//  SettingView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI

struct SettingView: View {
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
            
            Button {
                if let url = URL.init(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            } label: {
                Text("붙여넣기 알림이 귀찮으신가요?")
            }
        }
    }
}



struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

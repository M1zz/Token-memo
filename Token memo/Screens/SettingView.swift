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
            NavigationLink(destination: TutorialView()) {
                Text("클립키보드 사용방법")
            }
            
            NavigationLink(destination: KeyboardTutorialView()) {
                Text("FAQ")
            }
            
            NavigationLink(destination: FontSetting()) {
                Text("앱 내 폰트 크기 변경")
            }

            NavigationLink(destination: CopyPasteView()) {
                Text("붙여넣기 알림 켜기/끄기")
            }
            
            NavigationLink(destination: ReviewWriteView()) {
                Text("리뷰 및 평점 매기기")
            }
            
            NavigationLink(destination: ContactView()) {
                Text("개발자에게 연락하기")
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

struct TutorialView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: "https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4?pvs=4") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
}

struct ContactView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Send Email") {
                
            }
            .onAppear(perform: {
                dismiss()

                EmailController.shared.sendEmail(subject: "클립 키보드에 관해 문의드릴 것이 있습니다", body: "안녕하세요 저는 클립키보드의 사용자입니다.", to: "clipkeyboard@gmail.com")
            })
        }
    }
}

import MessageUI
class EmailController: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailController()
    private override init() { }
    
    func sendEmail(subject:String, body:String, to:String){
        // Check if the device is able to send emails
        if !MFMailComposeViewController.canSendMail() {
           print("This device cannot send emails.")
           return
        }
        // Create the email composer
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients([to])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        EmailController.getRootViewController()?.present(mailComposer, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        EmailController.getRootViewController()?.dismiss(animated: true, completion: nil)
    }
    
    static func getRootViewController() -> UIViewController? {
        // In SwiftUI 2.0
        UIApplication.shared.windows.first?.rootViewController
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

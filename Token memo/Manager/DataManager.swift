//
//  DataManager.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/15.
//

import SwiftUI
import Foundation

/// Manager handling the text entries
class DataManager: ObservableObject {
    
    /// Dynamic properties that the UI will react to
    @Published var editingEntry: String = ""
    @Published var textEntries = [String]() {
        didSet { saveTextEntries() }
    }
    
    @Published var didShowOnboarding: Bool = UserDefaults.standard.bool(forKey: "onboarding") {
        didSet {
            UserDefaults.standard.setValue(didShowOnboarding, forKey: "onboarding")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var didRemoveAds: Bool = UserDefaults.standard.bool(forKey: "didRemoveAds") {
        didSet {
            UserDefaults.standard.setValue(didRemoveAds, forKey: "didRemoveAds")
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Fetch saved entries
    init() {
        textEntries = UserDefaults(suiteName: AppConfig.appGroup)!.stringArray(forKey: "entries") ?? [String]()
    }
    
    /// Save text entries to `UserDefaults`
    private func saveTextEntries() {
        UserDefaults(suiteName: AppConfig.appGroup)!.setValue(textEntries, forKey: "entries")
        UserDefaults(suiteName: AppConfig.appGroup)!.synchronize()
    }
}

/// Generic configurations for the app
class AppConfig {

    // MARK: - App Group
    static let appGroup = "group.com.Ysoup.TokenMemo"
    
    /// Custom keyboard background color
    static let keyboardColor = Color(#colorLiteral(red: 0.8392156863, green: 0.8470588235, blue: 0.8745098039, alpha: 1))
    static let keyboardTabColor = Color(#colorLiteral(red: 0.6980392157, green: 0.7137254902, blue: 0.7647058824, alpha: 1))
    
    /// Your email for support
    static let emailSupport = "leeo@kakao.com"
}

//
//  dualcam_proApp.swift
//  dualcam-pro
//
//  Created by Kamal Mirzayev on 4/19/26.
//

import SwiftUI

@main
struct dualcam_proApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    hasSeenOnboarding = true
                }
                .transition(.opacity)
            }
        }
    }
}

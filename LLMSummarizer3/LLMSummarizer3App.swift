//
//  LLMSummarizer3App.swift
//  LLMSummarizer3
//
//  Created by 大志田洋輝 on 2025/09/07.
//

import SwiftUI
import SwiftData

@main
struct LLMSummarizer3App: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(settings)
                .environmentObject(env)
        }
        .modelContainer(for: SummaryItem.self)
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

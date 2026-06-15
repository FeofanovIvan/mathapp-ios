//
//  MainView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .home

    // ⬇️ меняем дефолт и дальше используем три значения:
    // "База ЕГЭ" | "Профиль ЕГЭ" | "ОГЭ"
    // было: "База"
    @AppStorage("selectedProfile") private var selectedProfile: String = ""


    @State private var currentTitle: String = "ЕГЭ математика"
    @State private var showSubscriptionScreen = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.white)

        let selectedColor = UIColor(Color.green)
        let selectedAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: selectedColor]

        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Верхняя панель
                ZStack {
                    // ЦЕНТР — заголовок
                    Text(currentTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    // ЛЕВО — меню профиля
                    HStack {
                        Menu {
                            Button("База ЕГЭ")     { selectedProfile = "База" }
                            Button("Профиль ЕГЭ")  { selectedProfile = "Профиль" }
                            Divider()
                            Button("ОГЭ")          { selectedProfile = "ОГЭ" }
                        } label: {
                            Text(selectedProfile)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                                .frame(maxWidth: 140, alignment: .leading)
                        }
                        Spacer()
                    }

                    // ПРАВО — просто декор, без нажатия
                    HStack {
                        Spacer()
                        ZStack {
                            Image(systemName: "crown.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.yellow)

                            RibbonView()
                                .offset(x: -15, y: -15)
                        }
                        .padding(.trailing, 16)
                    }
                }

                .padding()
                .background(Color(red: 0.12, green: 0.18, blue: 0.35))

                TabView(selection: $selectedTab) {
                    // ⬇️ если твой HomeView уже умеет работать со строкой — ок:
                    HomeView(selectedOption: selectedProfile, updateTitle: { title in
                        self.currentTitle = title
                    })
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Дом")
                    }
                    .tag(Tab.home)

                    NewsView()
                        .tabItem {
                            Image(systemName: "newspaper.fill")
                            Text("Новости")
                        }
                        .tag(Tab.news)

                    SettingsView(updateTitle: { title in
                        self.currentTitle = title
                    })
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Настройки")
                    }
                    .tag(Tab.settings)
                }
                .onChange(of: selectedTab) { oldValue, newValue in
                    currentTitle = getTitle(for: newValue, selectedProfile: selectedProfile)
                }
                .onChange(of: selectedProfile) { oldValue, newValue in
                    currentTitle = getTitle(for: selectedTab, selectedProfile: newValue)
                }

                .onAppear {
                    // первичная установка заголовка из сохранённого выбора
                    currentTitle = getTitle(for: selectedTab, selectedProfile: selectedProfile)

                }
            }
            .navigationBarHidden(true)
        }
    }

    struct RibbonView: View {
        var body: some View {
            Text("Акция")
                .font(.caption2).bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .rotationEffect(.degrees(-30))
                .shadow(radius: 2)
        }
    }

    // ⬇️ Обновили сигнатуру, чтобы учитывать выбранный трек
    func getTitle(for tab: Tab, selectedProfile: String) -> String {
        switch tab {
        case .home:
            // Если выбран ОГЭ — другой заголовок
            return selectedProfile == "ОГЭ" ? "ОГЭ математика" : "ЕГЭ математика"
        case .news:
            return "Новости"
        case .settings:
            return "Настройки"
        }
    }
}

enum Tab { case home, news, settings }

//
//  RulesScreen.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI
import WebKit

// MARK: - WebView для отображения HTML-файла и измерения «сырой» высоты
struct WebView: UIViewRepresentable {
    let fileName: String
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "html") {
            uiView.load(URLRequest(url: url))
        } else {
            // Если файла нет — очищаем высоту, чтобы не занимать место
            DispatchQueue.main.async { contentHeight = 1 }
            print("⚠️ HTML '\(fileName).html' не найден в Bundle")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(heightBinding: $contentHeight)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var contentHeight: CGFloat

        init(heightBinding: Binding<CGFloat>) {
            _contentHeight = heightBinding
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? Double {
                    DispatchQueue.main.async {
                        self.contentHeight = CGFloat(height)
                    }
                } else {
                    print("❌ Не удалось получить scrollHeight:", error?.localizedDescription ?? "")
                }
            }
        }
    }
}

// MARK: - Основной экран с правилами (ЕГЭ/ОГЭ)
struct RulesScreen: View {
    @Environment(\.presentationMode) var presentationMode
    var updateTitle: (String) -> Void

    @AppStorage("selectedProfile") private var selectedProfile: String = "База" // "База" | "Профиль" | "ОГЭ"

    @State private var contentHeight: CGFloat = 1

    // Выбор ресурсов в зависимости от трека
    private var isOGE: Bool { selectedProfile == "ОГЭ" }

    private var fileName: String { isOGE ? "rules_oge" : "rules" }
    private var headerTitle: String { isOGE ? "Правила ОГЭ" : "Правила ЕГЭ" }
    private var rootTitleOnBack: String { isOGE ? "ОГЭ математика" : "ЕГЭ математика" }

    // Картинки бланков: для ОГЭ — blanc_1/blanc_2 (Assets), для ЕГЭ остаются list1/list2
    private var blank1Name: String { isOGE ? "blanc_1" : "list1" }
    private var blank2Name: String { isOGE ? "blanc_2" : "list2" }
    private var blank1Title: String { isOGE ? "Бланк ОГЭ 1" : "Бланк 1" }
    private var blank2Title: String { isOGE ? "Бланк ОГЭ 2" : "Бланк 2" }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone

            // Немного различная «подрезка» высоты для разных устройств/ориентации
            let scaleFactor: CGFloat = isPhone
                ? (isLandscape ? 0.7 : 0.37)
                : (isLandscape ? 1.2 : 1.0)

            VStack(spacing: 0) {
                // Верхняя панель
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        updateTitle(rootTitleOnBack)
                    } label: {
                        Image(systemName: "arrow.backward")
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text(headerTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Spacer().frame(width: 60)
                }
                .padding()
                .background(Color(red: 0.12, green: 0.18, blue: 0.35))

                // Контент
                ScrollView {
                    VStack(spacing: 20) {
                        WebView(fileName: fileName, contentHeight: $contentHeight)
                            .frame(height: max(1, contentHeight))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                            // перезагрузка WebView при смене ориентации/трека
                            .id(isLandscape.hashValue ^ fileName.hashValue)

                        // Бланки
                        VStack(spacing: 16) {
                            Text(blank1Title)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            ZoomableStaticImage(imageName: blank1Name)
                                .frame(maxWidth: .infinity)

                            Text(blank2Title)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            ZoomableStaticImage(imageName: blank2Name)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color.white)
                }
            }
            .onAppear {
                updateTitle(headerTitle)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Картинка с масштабированием
struct ZoomableStaticImage: View {
    let imageName: String
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in scale = lastScale * value }
                    .onEnded { _ in lastScale = scale }
            )
            .cornerRadius(10)
            .shadow(radius: 5)
    }
}

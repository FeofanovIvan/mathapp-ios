//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 04/04/25.
//

import SwiftUI
import WebKit

class JSLogHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("📩 JS лог: \(message.body)")
    }
}

struct LoggingWebView: UIViewRepresentable {
    let htmlFileName: String

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(JSLogHandler(), name: "log") // 👈 подключаем log

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)

        if let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") {
            let request = URLRequest(url: url)
            webView.load(request)
            print("✅ HTML найден: \(url)")
        } else {
            print("❌ HTML файл не найден: \(htmlFileName).html")
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

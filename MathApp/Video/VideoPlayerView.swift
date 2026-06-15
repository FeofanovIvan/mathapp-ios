//
//  VideoPlayerView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 31/03/25.
//

import SwiftUI
import WebKit

struct VideoPlayerView: View {
    let videoUrl: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.white)
                        .padding()
                }

                Spacer()

                Text("Видео")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
                Spacer().frame(width: 60)
            }
            .padding()
            .background(Color(red: 0.12, green: 0.18, blue: 0.35))

            // Веб-плеер
            WebVideoView(embedUrl: videoUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)

    }
}

struct WebVideoView: UIViewRepresentable {
    let embedUrl: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let iframeHTML = """
        <html>
            <head>
                <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0">
                <style> body { margin: 0; padding: 0; } </style>
            </head>
            <body>
                <iframe width="100%" height="100%" src="\(embedUrl)" frameborder="0" allowfullscreen></iframe>
            </body>
        </html>
        """
        webView.loadHTMLString(iframeHTML, baseURL: nil)
    }
}

//
//  ReferenceDetailView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 31/03/25.
//
import SwiftUI
import WebKit
import CoreData

struct ReferenceDetailView: View {
    let blockID: Int64
    let selectedProfile: String   // "База" | "Профиль" | "ОГЭ"

    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = "Справочник"
    @State private var htmlContent: String = "Загрузка..."

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.white)
                        .padding()
                }

                Spacer()

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
                Spacer().frame(width: 60)
            }
            .padding()
            .background(Color(red: 0.12, green: 0.18, blue: 0.35))

            WebContentView(html: htmlContent)
                .onAppear {
                    loadContent()
                }
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
    }

    private func loadContent() {
        // Правильный контекст: ОГЭ → ogeContext, ЕГЭ (База/Профиль) → firebaseContext
        let context: NSManagedObjectContext = {
            if selectedProfile == "ОГЭ" {
                return PersistenceController.shared.ogeContext
            } else {
                return PersistenceController.shared.firebaseContext
            }
        }()

        let request: NSFetchRequest<QuestionBlockEntity> = QuestionBlockEntity.fetchRequest()
        request.predicate = NSPredicate(format: "blockID == %d", blockID)

        do {
            if let block = try context.fetch(request).first {
                title = block.name ?? "Справочник"
                htmlContent = block.referenceMaterial ?? "Нет содержимого"
            } else {
                htmlContent = "Материал не найден"
            }
        } catch {
            print("❌ Ошибка загрузки справочника: \(error.localizedDescription)")
            htmlContent = "Ошибка загрузки материала"
        }
    }
}
struct WebContentView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

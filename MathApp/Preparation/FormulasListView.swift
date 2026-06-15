//
//  FormulasListView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 02/04/25.
//
import SwiftUI
import WebKit
import CoreData

struct FormulasListView: View {
    let blockID: Int64

    @Environment(\.presentationMode) var presentationMode
    @State private var formulas: [FormulaEntity] = []

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
                Text("Формулы")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Spacer().frame(width: 60)
            }
            .padding()
            .background(Color(red: 0.12, green: 0.18, blue: 0.35))

            // Основной контент
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                if formulas.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Формулы для этого блока не найдены.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
                } else {
                    FormulaTableView(formulas: formulas)
                }
            }

        }
        .onAppear(perform: loadFormulas)
        .navigationBarHidden(true)
    }

    func loadFormulas() {
        let context = PersistenceController.shared.firebaseContext
        let request: NSFetchRequest<FormulaEntity> = FormulaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "block.blockID == %d", blockID)

        do {
            formulas = try context.fetch(request)
        } catch {
            print("❌ Ошибка загрузки формул: \(error)")
        }
    }

}


import SwiftUI
import WebKit

struct FormulaTableView: UIViewRepresentable {
    let formulas: [FormulaEntity]

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = true
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.loadHTMLString(generateHTML(), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(generateHTML(), baseURL: nil)
    }

    private func generateHTML() -> String {
        let rows = formulas.map { formula in
            let name = formula.name ?? ""
            let latex = formula.formula ?? ""
            return """
            <tr>
                <td style="padding: 12px 10px; font-weight: 600; font-size: 50px; vertical-align: top; color: #1E3050; width: 40%;">
                    \(name)
                </td>
                <td style="padding: 12px 10px; color: #1E3050;">
                    \\[\(latex)\\]
                </td>
            </tr>
            """
        }.joined()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    font-family: -apple-system, sans-serif;
                    font-size: 50px;
                    padding: 16px;
                    margin: 0;
                    background-color: white;
                }
                table {
                    width: 100%;
                    border-collapse: separate;
                    border-spacing: 0 10px;
                }
                tr:nth-child(even) {
                    background-color: #f2f4f8;
                }
                tr:nth-child(odd) {
                    background-color: #ffffff;
                }
                td {
                    border-radius: 8px;
                    vertical-align: middle;
                }
            </style>
        </head>
        <body>
            <table>
                \(rows)
            </table>
        </body>
        </html>
        """
    }
}


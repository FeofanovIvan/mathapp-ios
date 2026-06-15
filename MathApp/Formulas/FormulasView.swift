//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI
import WebKit
import CoreData

struct FormulasView: View {
    @Environment(\.presentationMode) var presentationMode
    var updateTitle: (String) -> Void

    // ✅ читаем выбранный трек
    @AppStorage("selectedProfile") private var selectedProfile: String = "База"

    // ✅ выбираем нужный Core Data контекст
    private var dataContext: NSManagedObjectContext {
        if selectedProfile == "ОГЭ" {
            return PersistenceController.shared.ogeContext     // вторая БД
        } else {
            return PersistenceController.shared.firebaseContext // ЕГЭ (База/Профиль)
        }
    }

    @State private var formulas: [FormulaEntity] = []
    @State private var correctFormulaID: Int64?
    @State private var selectedFormulaID: Int64? = nil
    @State private var isAnswerChecked = false
    @State private var showFeedback = false
    @State private var isAnswerCorrect = false
    @State private var bounce = false
    @State private var titleHeight: CGFloat = 40
    @State private var totalAttempts: Int = 0
    @State private var correctAnswers: Int = 0
    @State private var correctStreak: Int = 0
    @State private var rewardMessage: String?
    @State private var rewardSubtext: String?
    @State private var showRewardBanner = false
    @State private var animatePercent = false
    @State private var lastPercentValue: Int = 0

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                ZStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                            // ✅ правильный заголовок при возврате
                            updateTitle(selectedProfile == "ОГЭ" ? "ОГЭ математика" : "ЕГЭ математика")
                        }) {
                            Image(systemName: "arrow.backward")
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }

                    Text("Формулы")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack {
                        Spacer()
                        if totalAttempts > 0 {
                            let percent = Int((Double(correctAnswers) / Double(totalAttempts)) * 100)
                            Text("\(percent)%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(percent < 25 ? .red : .yellow)
                                .padding(.trailing, 16)
                                .scaleEffect(animatePercent ? 2.0 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: animatePercent)
                        }
                    }
                }
                .padding()
                .background(Color(red: 0.12, green: 0.18, blue: 0.35))

                // Контент
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let question = formulas.first(where: { $0.formulaID == correctFormulaID })?.name {
                            FormulaTitleView(latexTitle: question, height: $titleHeight)
                                .frame(height: titleHeight)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Выберите правильную формулу:")
                                .font(.headline)
                                .padding(.bottom, 8)

                            ForEach(formulas, id: \.formulaID) { formula in
                                Button(action: {
                                    if !isAnswerChecked { selectedFormulaID = formula.formulaID }
                                }) {
                                    HStack {
                                        WebContentView(html: generateMathHtml(from: formula.formula ?? ""))
                                            .frame(height: 60)

                                        if isAnswerChecked {
                                            if formula.formulaID == correctFormulaID {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                            } else if formula.formulaID == selectedFormulaID {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(borderColor(for: formula), lineWidth: 2)
                                    )
                                    .cornerRadius(10)
                                    .shadow(radius: isAnswerChecked ? 2 : 0)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 3)
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding()
                }

                // Кнопки
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3)) {
                            isAnswerChecked = true
                            isAnswerCorrect = selectedFormulaID == correctFormulaID
                            showFeedback = true
                            bounce.toggle()

                            if let selectedID = selectedFormulaID {
                                updateFormulaStats(for: selectedID, isCorrect: isAnswerCorrect)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { showFeedback = false }
                        }
                    }) {
                        Label("ПРОВЕРИТЬ", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedFormulaID != nil ? Color(red: 0.12, green: 0.18, blue: 0.35) : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(selectedFormulaID == nil || isAnswerChecked)
                    .opacity((selectedFormulaID != nil && !isAnswerChecked) ? 1 : 0.6)

                    Button("СЛЕДУЮЩИЙ") {
                        isAnswerChecked = false
                        selectedFormulaID = nil
                        loadQuestion()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 0)
            }
            .zIndex(0)

            // Фидбек
            if showFeedback {
                Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    Text(isAnswerCorrect ? "✅ Правильно!" : "❌ Неправильно")
                        .font(.title2)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isAnswerCorrect ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .scaleEffect(bounce ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.3, blendDuration: 0.2), value: bounce)
                        .animation(.easeInOut(duration: 0.3), value: showFeedback)
                    Spacer()
                }
                .transition(.scale)
                .zIndex(1)

                if showRewardBanner, let title = rewardMessage {
                    VStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(title).font(.title2).bold().foregroundColor(.white)
                            if let sub = rewardSubtext {
                                Text(sub).font(.subheadline).foregroundColor(.white.opacity(0.85))
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.95))
                        .cornerRadius(16)
                        .shadow(radius: 10)
                        .padding(.bottom, 150)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut, value: showRewardBanner)
                    }
                    .zIndex(2)
                }
            }
        }
        .onAppear {
            updateTitle("Формулы")
            loadOverallStats()
            loadQuestion()
        }
        .navigationBarHidden(true)
        .onDisappear {
            totalAttempts = 0
            correctAnswers = 0
            correctStreak = 0
        }

    }
    func loadOverallStats() {
        let context = PersistenceController.shared.localContext
        let request: NSFetchRequest<FormulaStats> = FormulaStats.fetchRequest()

        do {
            let stats = try context.fetch(request)
            let totalCorrect = stats.reduce(0) { $0 + Int($1.correctCount) }
            let totalIncorrect = stats.reduce(0) { $0 + Int($1.incorrectCount) }

            correctAnswers = totalCorrect
            totalAttempts = totalCorrect + totalIncorrect

            print("📥 Загрузка общей статистики: ✅ \(correctAnswers), 🔁 Всего: \(totalAttempts)")

        } catch {
            print("❌ Ошибка загрузки статистики: \(error.localizedDescription)")
        }
    }

    func updateFormulaStats(for formulaID: Int64, isCorrect: Bool) {
        let context = PersistenceController.shared.localContext
        let request: NSFetchRequest<FormulaStats> = FormulaStats.fetchRequest()
        request.predicate = NSPredicate(format: "formulaID == %d", formulaID)

        do {
            let results = try context.fetch(request)
            let stats = results.first ?? FormulaStats(context: context)

            if results.isEmpty {
                stats.formulaID = formulaID
                stats.correctCount = 0
                stats.incorrectCount = 0
            }

            if isCorrect {
                stats.correctCount += 1
                correctAnswers += 1
                correctStreak += 1
                checkStreakMilestone()
            } else {
                stats.incorrectCount += 1
                correctStreak = 0
            }

            totalAttempts += 1
            try context.save()

            let accuracy = Int((Double(correctAnswers) / Double(totalAttempts)) * 100)

            print("""
            📊 Формула ID: \(formulaID)
            ✅ Правильно: \(stats.correctCount)
            ❌ Неправильно: \(stats.incorrectCount)
            🔁 Серия подряд: \(correctStreak)
            🎯 Точность: \(accuracy)% (\(correctAnswers)/\(totalAttempts))
            """)
            
        } catch {
            print("❌ Ошибка при обновлении статистики: \(error.localizedDescription)")
        }
        let newPercent = Int((Double(correctAnswers) / Double(totalAttempts)) * 100)

        if newPercent != lastPercentValue {
            lastPercentValue = newPercent
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                animatePercent = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animatePercent = false
            }
        }

    }

    func checkStreakMilestone() {
        switch correctStreak {
        case 5:
            rewardMessage = "🎯 Отличное начало!"
            rewardSubtext = "5 правильных подряд"
        case 10:
            rewardMessage = "🔥 Так держать!"
            rewardSubtext = "10 правильных подряд"
        case 20:
            rewardMessage = "🌟 Ты супер!"
            rewardSubtext = "20 правильных подряд"
        case 35:
            rewardMessage = "🚀 Невероятно!"
            rewardSubtext = "35 правильных подряд"
        case 50:
            rewardMessage = "🧠 Ты гений!"
            rewardSubtext = "50 правильных подряд"
        default:
            return
        }

        // Показать баннер
        withAnimation(.easeOut(duration: 0.4)) {
            showRewardBanner = true
        }

        // Скрыть баннер через 4 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeIn(duration: 0.4)) {
                showRewardBanner = false
            }
        }
    }



    func generateMathHtml(from latex: String) -> String {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let fontSize = isPad ? "18px" : "50px"

        return """
        <!DOCTYPE html>
        <html lang="ru">
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    background-color: transparent;
                    margin: 0;
                    padding: 0;
                    font-size: \(fontSize);
                    line-height: 1.4;
                    text-align: center;
                    color: #1E3050;
                    font-weight: bold;
                }
            </style>
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
        </head>
        <body>
            <p>\\(\(latex)\\)</p>
        </body>
        </html>
        """
    }


    func loadQuestion() {
        let request: NSFetchRequest<FormulaEntity> = FormulaEntity.fetchRequest()

        do {
            var allFormulas = try dataContext.fetch(request)   // 👈 тут dataContext
            guard allFormulas.count >= 4 else {
                print("⚠️ В выбранной БД формул меньше 4 — вопрос не собрать.")
                formulas = allFormulas
                correctFormulaID = allFormulas.first?.formulaID
                return
            }

            // правильная
            let correct = allFormulas.randomElement()!
            correctFormulaID = correct.formulaID

            // убираем правильную
            allFormulas.removeAll { $0.formulaID == correct.formulaID }

            // 3 неправильных
            let incorrect = allFormulas.shuffled().prefix(3)

            // итог
            formulas = ([correct] + incorrect).shuffled()
        } catch {
            print("❌ Ошибка загрузки формул: \(error.localizedDescription)")
        }
    }



    func borderColor(for formula: FormulaEntity) -> Color {
        if isAnswerChecked {
            if formula.formulaID == correctFormulaID {
                return .green.opacity(0.8)
            } else if formula.formulaID == selectedFormulaID {
                return .red.opacity(0.8)
            } else {
                return .gray.opacity(0.2)
            }
        } else {
            if formula.formulaID == selectedFormulaID {
                return .yellow.opacity(0.6)
            } else {
                return .gray.opacity(0.2)
            }
        }
    }


}
struct FormulaWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

struct FormulaTitleView: UIViewRepresentable {
    let latexTitle: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = wrapHtml(latexTitle)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: FormulaTitleView

        init(_ parent: FormulaTitleView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 🧠 Вычисляем фактическую высоту контента
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = height
                    }
                }
            }
        }
    }

    private func wrapHtml(_ latex: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/3.2.2/es5/tex-mml-chtml.js" async></script>
            <style>
                body {
                    font-family: -apple-system, sans-serif;
                    font-size: 18px;
                    padding: 8px;
                    margin: 0;
                }
                img, svg {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
            \(latex)
        </body>
        </html>
        """
    }
}


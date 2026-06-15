//
//  ExamView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI
import WebKit
import CoreData


struct ExamView: View {
    @State private var selectedTab: ExamTab = .task
    @State private var isMenuOpen: Bool = false
    @State private var showDraftCanvas: Bool = false
    @StateObject private var canvasState = DrawingCanvasState()
    @Environment(\.dismiss) private var dismiss
    @State private var totalSeconds: Int = 3 * 3600 + 55 * 60// 3 часа 55 минут
    @State private var examEnded = false
    @StateObject private var keyboardCoordinator = MathKeyboardCoordinator()
    @State private var keyboardWebView = WKWebView()
    @State private var latexPreview: String = ""
    @State private var webViewHeight: CGFloat = 1
    @State private var keyboardHeight: CGFloat = 0
    @State private var showInstructionPopup = false
    @State private var previousTabBeforeDraft: ExamTab = .task
    @State private var selectedTaskID: Int64? = nil
    @State private var taskTextHeight: CGFloat = 1
    @State private var drawingHeight: CGFloat = 1
    @AppStorage("selectedProfile") var selectedProfile: String = "База"
    @State private var examQuestions: [ExamQuestionEntity] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var currentExamSession: ExamSessionEntity?
    @State private var showResumePrompt: Bool = false
    @State private var showAnswerSavedPopup = false
    @State private var showFinishExamPrompt = false
    @State private var examTimer: Timer?
    @State private var showExitConfirmation = false
    @State private var showResultSummary = false
    @State private var answerResults: [(number: Int, user: String, correct: String, isCorrect: Bool)] = []
    @Environment(\.verticalSizeClass) private var vSizeClass


 


    


    var formattedTime: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        ZStack {
            // Основной контент
            VStack(spacing: 0) {
                // Верхняя панель
                HStack {
                    Button(action: {
                        withAnimation {
                            isMenuOpen.toggle()
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                            .padding(5)
                    }

                    Spacer()

                    // Вкладки
                    HStack(spacing: 15) {
                        ForEach(ExamTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                            }) {
                                VStack {
                                    Text(tab.rawValue)
                                        .font(.headline)
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .foregroundColor(selectedTab == tab ? .green : .gray)
                                    Rectangle()
                                        .frame(height: 2)
                                        .foregroundColor(selectedTab == tab ? .green : .clear)
                                }
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.system(size: 12, weight: .bold))

                        Text(formattedTime.dropLast(3)) // только часы:минуты
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.orange)
                            .transition(.scale)
                            .id(formattedTime) // заставляет пересоздавать при изменении
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .animation(.easeInOut(duration: 0.8), value: formattedTime)



                }
                .padding(.horizontal, 5)
                .padding(.vertical, 5)
                .background(Color.white)

                // Контент вкладок
                ZStack {
                    if selectedTab == .task {
                        if examQuestions.indices.contains(currentQuestionIndex) {
                            let question = examQuestions[currentQuestionIndex]

                            ScrollView {
                                VStack(spacing: 16) {
                                    TaskMathWebView(content: question.questionText ?? "", height: $taskTextHeight)
                                        .frame(height: taskTextHeight)

                                    if let drawing = question.drawingHtml, !drawing.isEmpty {
                                        TaskMathWebView(content: drawing, height: $drawingHeight)
                                            .frame(height: drawingHeight)
                                    }
                                }
                                .padding()

                            }
                        } else {
                            Text("Выберите вопрос в меню")
                                .padding()
                        }
                    } else if selectedTab == .answer {
                        GeometryReader { geometry in
                            let isLandscape = geometry.size.width > geometry.size.height
                            let isPad = UIDevice.current.userInterfaceIdiom == .pad
                            let keyboardWidth = geometry.size.width * 0.45

                            if isLandscape && !isPad {
                                HStack(spacing: 0) {
                                    // 🔹 Левая часть — scrollable контент
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 16) {
                                            HStack {
                                                Text("Введите ответ ниже:")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)

                                                Spacer()

                                                Button(action: {
                                                    guard examQuestions.indices.contains(currentQuestionIndex) else { return }
                                                    let currentQuestion = examQuestions[currentQuestionIndex]
                                                    currentQuestion.userAnswer = latexPreview
                                                    currentQuestion.isCorrect = false

                                                    do {
                                                        try PersistenceController.shared.localContext.save()
                                                        print("✅ Ответ сохранен: \(latexPreview)")
                                                        keyboardCoordinator.clearAllInput()
                                                        showAnswerSavedPopup = true
                                                        goToNextUnanswered()
                                                    } catch {
                                                        print("❌ Ошибка при сохранении ответа: \(error)")
                                                    }
                                                }) {
                                                    Text("ОТВЕТИТЬ")
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.green)
                                                        .cornerRadius(6)
                                                }
                                            }
                                            .padding(.top, 16)
                                            .padding(.horizontal)

                                            KeyboardPreviewWebView(content: latexPreview, height: $webViewHeight)
                                                .frame(height: webViewHeight)
                                                .padding(.horizontal)

                                            HStack {
                                                Spacer()
                                                VStack(spacing: 12) {
                                                    Button(action: {
                                                        withAnimation {
                                                            showInstructionPopup = true
                                                        }
                                                    }) {
                                                        Image(systemName: "list.bullet.rectangle")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 30, height: 30)
                                                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                                            .padding(10)
                                                            .background(Color.white)
                                                            .clipShape(Circle())
                                                            .shadow(radius: 4)
                                                    }

                                                    Button(action: {
                                                        previousTabBeforeDraft = selectedTab
                                                        showDraftCanvas = true
                                                    }) {
                                                        Image(systemName: "pencil.tip")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 30, height: 30)
                                                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                                            .padding(10)
                                                            .background(Color.white)
                                                            .clipShape(Circle())
                                                            .shadow(radius: 4)
                                                    }
                                                }
                                                .padding(.trailing)
                                            }

                                            MathKeyboardView(coordinator: keyboardCoordinator, webView: keyboardWebView)
                                                .frame(height: 0)

                                            Spacer()
                                        }
                                        .frame(width: geometry.size.width - keyboardWidth)
                                    }

                        
                                    // 🔹 Правая часть — клавиатура + кнопки в ОДНУ ПОЛОСУ
                                    VStack(spacing: 8) {
                                        // Клавиатура
                                        CustomKeyboard(
                                            coordinator: keyboardCoordinator,
                                            containerWidth: keyboardWidth
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding(.top, 8)
                                        .padding(.horizontal, 8)

                                        // Кнопки в одну полосу
                                        HStack(spacing: 8) {
                                            // ❌ ЗАВЕРШИТЬ
                                            Button(action: {
                                                showExitConfirmation = true
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "xmark.circle")
                                                    Text("ЗАВЕРШИТЬ")
                                                        .fontWeight(.semibold)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.7)
                                                }
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity) // ← равная ширина
                                                .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                                                .cornerRadius(12)
                                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                            }

                                            // ▶️ ПРОДОЛЖИТЬ
                                            Button(action: {
                                                if selectedTab == .task {
                                                    selectedTab = .answer
                                                } else if selectedTab == .answer {
                                                    if let nextUnanswered = examQuestions.firstIndex(where: { $0.userAnswer == nil && $0 != examQuestions[currentQuestionIndex] }) {
                                                        currentQuestionIndex = nextUnanswered
                                                        selectedTaskID = examQuestions[nextUnanswered].taskID
                                                        selectedTab = .task
                                                    } else if currentQuestionIndex + 1 < examQuestions.count {
                                                        currentQuestionIndex += 1
                                                        selectedTaskID = examQuestions[currentQuestionIndex].taskID
                                                        selectedTab = .task
                                                    } else {
                                                        print("📌 Все вопросы просмотрены")
                                                    }
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "play.fill")
                                                    Text("ПРОДОЛЖИТЬ")
                                                        .fontWeight(.semibold)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.7)
                                                }
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity) // ← равная ширина
                                                .background(Color.green)
                                                .cornerRadius(12)
                                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.bottom, 8)
                                    }
                                    .frame(width: keyboardWidth)
                                    .background(Color.white)
                                    .clipped()

                                }
                            } else {
                                // Портретная ориентация — остаётся как раньше
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Введите ответ ниже:")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)

                                        Spacer()

                                        Button(action: {
                                            guard examQuestions.indices.contains(currentQuestionIndex) else { return }
                                            let currentQuestion = examQuestions[currentQuestionIndex]
                                            currentQuestion.userAnswer = latexPreview
                                            currentQuestion.isCorrect = false

                                            do {
                                                try PersistenceController.shared.localContext.save()
                                                print("✅ Ответ сохранен: \(latexPreview)")
                                                keyboardCoordinator.clearAllInput()
                                                showAnswerSavedPopup = true
                                                goToNextUnanswered()
                                            } catch {
                                                print("❌ Ошибка при сохранении ответа: \(error)")
                                            }
                                        }) {
                                            Text("ОТВЕТИТЬ")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 12)
                                                .background(Color.green)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 16)

                                    KeyboardPreviewWebView(content: latexPreview, height: $webViewHeight)
                                        .frame(height: webViewHeight)
                                        .padding(.horizontal)

                                    Spacer()

                                    HStack {
                                        Spacer()
                                        VStack {
                                            Button(action: {
                                                withAnimation {
                                                    showInstructionPopup = true
                                                }
                                            }) {
                                                Image(systemName: "list.bullet.rectangle")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 30, height: 30)
                                                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                                    .padding(10)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                                    .shadow(radius: 4)
                                            }

                                            Button(action: {
                                                previousTabBeforeDraft = selectedTab
                                                showDraftCanvas = true
                                            }) {
                                                Image(systemName: "pencil.tip")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 30, height: 30)
                                                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                                    .padding(10)
                                                    .background(Color.white)
                                                    .clipShape(Circle())
                                                    .shadow(radius: 4)
                                            }
                                        }
                                        .padding()
                                    }

                                    MathKeyboardView(coordinator: keyboardCoordinator, webView: keyboardWebView)
                                        .frame(height: 0)

                                    CustomKeyboard(coordinator: keyboardCoordinator)
                                        .padding(.bottom, keyboardHeight + 5)
                                }
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                                withAnimation {
                                    self.keyboardHeight = keyboardFrame.height
                                }
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                            withAnimation {
                                self.keyboardHeight = 0
                            }
                        }
                    }

                    
                    if showResumePrompt {
                        ZStack {
                            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                            VStack(spacing: 20) {
                                Text("У вас уже начатый экзамен")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)

                                Text("Вы хотите продолжить его?")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 20) {
                                    Button("Нет") {
                                        showResumePrompt = false

                                        verifyAndSaveAllAnswers {
                                            if let session = currentExamSession {
                                                session.isCompleted = true
                                                try? PersistenceController.shared.localContext.save()
                                            }
                                            currentExamSession = nil
                                            examQuestions = []
                                            selectedTaskID = nil
                                            startNewExam()
                                        }
                                    }
                                    .foregroundColor(.red)

                                    Button("Да") {
                                        if let questions = currentExamSession?.questions?.allObjects as? [ExamQuestionEntity] {
                                            examQuestions = questions.sorted { $0.orderIndex < $1.orderIndex }

                                            // 🔍 Ищем первый неотвеченный вопрос
                                            if let firstUnanswered = examQuestions.firstIndex(where: { $0.userAnswer == nil }) {
                                                currentQuestionIndex = firstUnanswered
                                                selectedTaskID = examQuestions[firstUnanswered].taskID
                                            } else {
                                                currentQuestionIndex = 0
                                                selectedTaskID = examQuestions.first?.taskID
                                            }
                                        }
                                        showResumePrompt = false
                                    }

                                    .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            .padding(.horizontal, 24)
                        }
                        .zIndex(3)
                    }

                    // Всплывающее окно инструкции
                    if showInstructionPopup {
                        ZStack {
                            Color.black.opacity(0.3)
                                .edgesIgnoringSafeArea(.all)
                                .onTapGesture {
                                    withAnimation {
                                        showInstructionPopup = false
                                    }
                                }

                            InstructionPopupExamView(show: $showInstructionPopup)
                                .transition(.scale)
                                .zIndex(2)
                        }
                        .zIndex(2) // 👈 очень важно, чтобы перекрыть всё остальное
                    }
                    if showAnswerSavedPopup {
                        ZStack {
                            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                            VStack(spacing: 20) {
                                Text("✅ Ответ сохранён")
                                    .font(.headline)
                                    .padding()

                                Button("Ок") {
                                    withAnimation {
                                        showAnswerSavedPopup = false
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            .padding(.horizontal, 24)
                        }
                        .zIndex(5)
                    }
                    if showFinishExamPrompt {
                        ZStack {
                            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                            VStack(spacing: 20) {
                                Text("🎉 Вы ответили на все вопросы!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Хотите завершить экзамен и проверить результат?")
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 20) {
                                    Button("Нет") {
                                        showFinishExamPrompt = false
                                    }
                                    .foregroundColor(.red)

                                    Button("Да") {
                                        verifyAndSaveAllAnswers {
                                            currentExamSession?.isCompleted = true
                                            try? PersistenceController.shared.localContext.save()
                                            showFinishExamPrompt = false
                                            showResultSummary = true
                                        }
                                    }
                                    .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            .padding(.horizontal, 24)
                        }
                        .zIndex(6)
                    }
                    if showExitConfirmation {
                        ZStack {
                            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                            VStack(spacing: 20) {
                                Text("Хотите завершить экзамен?")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 20) {
                                    Button("Завершить") {
                                        verifyAndSaveAllAnswers {
                                            currentExamSession?.isCompleted = true
                                            try? PersistenceController.shared.localContext.save()

                                            answerResults = examQuestions.enumerated().map { (index, question) in
                                                (
                                                    number: index + 1,
                                                    user: question.userAnswer ?? "—",
                                                    correct: question.correctAnswer ?? "—",
                                                    isCorrect: question.isCorrect
                                                )
                                            }

                                            showExitConfirmation = false
                                            showResultSummary = true
                                        }
                                    }
                                    .foregroundColor(.red)


                                    Button("Сохранить и выйти") {
                                        dismiss()
                                    }
                                    .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            .padding(.horizontal, 24)
                        }
                        .zIndex(10)
                    }


                    // Черновик не вставляется сюда!
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

                // Кнопки внизу
                let isPhoneLandscape = UIDevice.current.userInterfaceIdiom == .phone && vSizeClass == .compact
                let hideBottomBar = (selectedTab == .answer && isPhoneLandscape)

                if !hideBottomBar {
                    HStack(spacing: 10) {
                        // ❌ ЗАВЕРШИТЬ
                        Button(action: {
                            showExitConfirmation = true // вместо dismiss()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("ЗАВЕРШИТЬ")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        
                        // ▶️ ПРОДОЛЖИТЬ
                        Button(action: {
                            if selectedTab == .task {
                                // 1️⃣ Переключаемся на вкладку "ОТВЕТ"
                                selectedTab = .answer
                            } else if selectedTab == .answer {
                                // 2️⃣ Ищем следующий неотвеченный вопрос
                                if let nextUnanswered = examQuestions.firstIndex(where: { $0.userAnswer == nil && $0 != examQuestions[currentQuestionIndex] }) {
                                    currentQuestionIndex = nextUnanswered
                                    selectedTaskID = examQuestions[nextUnanswered].taskID
                                    selectedTab = .task
                                } else if currentQuestionIndex + 1 < examQuestions.count {
                                    // 3️⃣ Переход к следующему вопросу
                                    currentQuestionIndex += 1
                                    selectedTaskID = examQuestions[currentQuestionIndex].taskID
                                    selectedTab = .task
                                } else {
                                    // 4️⃣ Все вопросы отвечены и мы на последнем — остаёмся
                                    print("📌 Все вопросы просмотрены")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("ПРОДОЛЖИТЬ")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        
                    }
                    .padding()
                    .background(Color.clear)
                    
                }

            }
            .disabled(isMenuOpen)

           
            if isMenuOpen {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(examQuestions.indices, id: \.self) { index in
                                    let question = examQuestions[index]

                                    Button {
                                        selectedTaskID = question.taskID
                                        currentQuestionIndex = index
                                        selectedTab = .task
                                        withAnimation { isMenuOpen = false }
                                    } label: {
                                        HStack {
                                            Text("Вопрос \(index + 1)")
                                                .foregroundColor(currentQuestionIndex == index
                                                                 ? Color.green
                                                                 : Color(red: 0.12, green: 0.18, blue: 0.35))

                                            Spacer()

                                            if question.userAnswer != nil {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .frame(width: 250)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 2, y: 0)
                    .transition(.move(edge: .leading))

                    Rectangle()
                        .foregroundColor(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                isMenuOpen = false
                            }
                        }
                }
            }

            if showResultSummary {
                ZStack {
                    Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                    VStack(spacing: 16) {
                        Text("📊 Ваш результат:")
                            .font(.title2).bold()
                        if let session = currentExamSession {
                            Text("Правильных ответов: \(session.correctAnswersCount) из \(examQuestions.count)")
                                .font(.headline)
                                .foregroundColor(.green)
                        }


                        ResultWebView(results: answerResults)
                                        .frame(height: 350)
                                        .cornerRadius(12)

                        HStack(spacing: 20) {
                            Button(action: {
                                showResultSummary = false
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.backward.circle.fill")
                                    Text("Выйти")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }

                            Button(action: {
                                showResultSummary = false   // ⛔ Закрываем окно результатов
                                examEnded = false           // 🔁 Сбрасываем флаг завершения

                                startNewExam()              // 🎯 Новый экзамен

                                // ⏮️ Возврат к первому вопросу и вкладке "ЗАДАНИЕ"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let first = examQuestions.first {
                                        selectedTaskID = first.taskID
                                        currentQuestionIndex = 0
                                        selectedTab = .task
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text("Новый")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }

                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 24)
                }
                .zIndex(10)
            }



            // ВРЕМЯ ВЫШЛО — поверх всего
            if examEnded {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        // 🔔 Заголовок
                        Text("⏰ Время вышло!")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 10)
                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                        // 📊 Подробный результат
                            Text("📊 Ваш результат:")
                                .font(.title2).bold()
                            if let session = currentExamSession {
                                Text("Правильных ответов: \(session.correctAnswersCount) из \(examQuestions.count)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }


                            ResultWebView(results: answerResults)
                                            .frame(height: 350)
                                            .cornerRadius(12)

                            HStack(spacing: 20) {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.backward.circle.fill")
                                    Text("Выйти")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }

                            Button(action: {
                                showResultSummary = false   // ⛔ Закрываем окно результатов
                                examEnded = false           // 🔁 Сбрасываем флаг завершения

                                startNewExam()              // 🎯 Новый экзамен

                                // ⏮️ Возврат к первому вопросу и вкладке "ЗАДАНИЕ"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let first = examQuestions.first {
                                        selectedTaskID = first.taskID
                                        currentQuestionIndex = 0
                                        selectedTab = .task
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text("Новый")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }

                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 24)
                }
                .zIndex(15)
            }

        }


        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showDraftCanvas, onDismiss: {
            selectedTab = previousTabBeforeDraft
        }) {

            NavigationView {
                VStack {
                    TaskDrawingView(canvasState: canvasState)
                        .navigationBarTitle("Черновик", displayMode: .inline)
                        .navigationBarItems(trailing:
                            Button(action: {
                                showDraftCanvas = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        )
                }
            }
        }
        .onAppear {
            let context = PersistenceController.shared.localContext

            if currentExamSession == nil {
                if let existingSession = fetchOngoingExamSession(context: context) {
                    currentExamSession = existingSession
                    showResumePrompt = true

                    // 🕒 Загружаем таймер из сессии
                    totalSeconds = Int(existingSession.remainingTime)
                } else {
                    startNewExam()
                }
            }

            startExamTimer()
            


            keyboardCoordinator.onLatexUpdate = { updatedLatex in
                latexPreview = updatedLatex
            }
            
        }

        .onDisappear {
            examTimer?.invalidate()
            canvasState.clear()
        }
    }
    
    private func startExamTimer() {
        examTimer?.invalidate() // остановим если уже запущен

        examTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if totalSeconds > 0 {
                totalSeconds -= 1
                currentExamSession?.remainingTime = Int64(totalSeconds)
                try? PersistenceController.shared.localContext.save()
            } else {
                examEnded = true
                timer.invalidate()
            }
        }
    }

    private func goToNextUnanswered() {
        let total = examQuestions.count
        var nextIndex = currentQuestionIndex + 1

        for _ in 0..<total {
            if nextIndex >= total {
                nextIndex = 0 // зацикливаемся
            }

            if examQuestions[nextIndex].userAnswer == nil {
                currentQuestionIndex = nextIndex
                selectedTaskID = examQuestions[nextIndex].taskID
                selectedTab = .task
                return
            }

            nextIndex += 1
        }

        // Если не найдено неотвеченных — показать завершение
        showFinishExamPrompt = true
    }

    private func verifyAndSaveAllAnswers(completion: @escaping () -> Void) {
        let context = PersistenceController.shared.localContext
        var index = 0
        var correctCount = 0
        var localResults: [(number: Int, user: String, correct: String, isCorrect: Bool)] = []

        func verifyNext() {
            guard index < examQuestions.count else {
                currentExamSession?.correctAnswersCount = Int16(correctCount)
                try? context.save()
                answerResults = localResults // ⬅️ вот здесь финальный assign
                print("✅ Все ответы проверены. Правильных: \(correctCount)")
                completion()
                return
            }

            let question = examQuestions[index]
            index += 1

            guard let user = question.userAnswer, !user.isEmpty else {
                print("⏭ Пропущен вопрос \(index): нет ответа")
                verifyNext()
                return
            }

            let comparer = HiddenCompareWebView(
                userAnswer: user,
                correctAnswer: question.correctAnswer ?? ""
            ) { isCorrect in
                question.isCorrect = isCorrect
                if isCorrect { correctCount += 1 }
                localResults.append((number: index, user: user, correct: question.correctAnswer ?? "", isCorrect: isCorrect))

                print("📌 Ответ на вопрос \(index): \(isCorrect ? "✔️ Правильный" : "❌ Неправильный")")
                verifyNext()
            }

            DispatchQueue.main.async {
                let window = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first

                let hosting = UIHostingController(rootView: comparer)
                hosting.view.isHidden = true
                window?.rootViewController?.view.addSubview(hosting.view)
            }
        }

        verifyNext()
    }



            // ✅ Вставляй сюда, под `body`, но всё ещё внутри `ExamView`
    private func startNewExam() {
        // let context = PersistenceController.shared.localContext
        if let newSession = createNewExamSession(profile: selectedProfile) {
            currentExamSession = newSession
            totalSeconds = 3 * 3600 + 55 * 60 // 🕒 сбрасываем таймер
            startExamTimer() // 🔁 запускаем новый
            if let questions = newSession.questions?.allObjects as? [ExamQuestionEntity] {
                examQuestions = questions.sorted { $0.orderIndex < $1.orderIndex }
                selectedTaskID = examQuestions.first?.taskID
            }
        }
    }
}
        
// Перечисление для вкладок
enum ExamTab: String, CaseIterable {
    case task = "ЗАДАНИЕ"
    case answer = "ОТВЕТ"
}

struct DraftCanvasWrapper: View {
    var canvasState: DrawingCanvasState
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                TaskDrawingView(canvasState: canvasState)
            }
            .navigationBarTitle("Черновик", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            )
        }
        
    }
}






struct AnswerInputView: View {
    @State private var answerText: String = "" // Поле для ввода текста

    var body: some View {
        VStack(spacing: 10) {
            // Поле ввода и кнопка "Подтвердить" в верхней части
            HStack {
                TextField("Введите ответ", text: $answerText, axis: .vertical)
                    .padding()
                    .font(.body)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    .lineLimit(nil) // Позволяет полю ввода расширяться
                    .multilineTextAlignment(.leading)

                Button(action: {
                    print("Ответ подтвержден: \(answerText)")
                }) {
                    Text("сохранить")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                        .cornerRadius(8)
                        .frame(minWidth: 60)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Spacer() // Отделяет поле ввода от клавиатуры

          
        }
        .background(Color.white)
    }
}
struct InstructionPopupExamView: View {
    @Binding var show: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Кнопка закрытия
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        show = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.pink)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Формат записей ответов:")
                        .font(.headline)

                    Group {
                        Text("• В пунктах заданий где требуется доказательство ответ не проверяется.")
                        Text("• В заданиях с несколькими ответами, каждый ответ записывайте в круглых скобках.")
                        Text("  Пример: (ответ 1)(ответ 2)")
                        Text("• В заданиях где есть несколько пунктов, ответ на каждый пункт записывайте в круглых скобках в соответствии с последовательностью пунктов.")
                        Text("  Пример: Пункт: а) б) в) Ответ: (ответ а)(ответ б)(ответ в)")
                        Text("• В ответах с интервалами необходимо использовать формат неравенств.")
                        Text("  Пример: (x₁;x₂)∪[x₃;x₄] должен быть записан как:")
                        Text("  x₁ < x < x₂ ∪ x₃ ≤ x ≤ x₄")
                    }

                    Text("Краткое руководство по использованию математической клавиатуры:")
                        .font(.headline)

                    Group {
                        Text("• Перемещение курсора происходит с помощью клавиши ⏎ (например, из числителя в знаменатель или из основания логарифма в подлогарифмическое выражение).")
                        Text("• Символы ≥ и ≤ создаются при последовательном вводе символов >= или <=.")
                        Text("• Кнопка CE очищает всё.")
                        Text("• Кнопка ⌫ удаляет последний символ.")
                    }
                }
                .font(.system(size: 15))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: 380, maxHeight: 400)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
}

import CoreData
import SwiftUI

func fetchRandomQuestionFromBlock(_ blockID: Int, dataContext: NSManagedObjectContext) -> TaskEntity? {
    let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "block.blockID == %d", blockID)
    do {
        let all = try dataContext.fetch(fetchRequest)
        return all.randomElement()
    } catch {
        print("❌ Ошибка выборки задач для блока \(blockID): \(error)")
        return nil
    }
}


func createNewExamSession(profile: String) -> ExamSessionEntity? {
    let localContext = PersistenceController.shared.localContext

    // ✅ выбираем источник задач по профилю
    let dataContext: NSManagedObjectContext
    let blocksRange: ClosedRange<Int>
    switch profile {
    case "ОГЭ":
        dataContext = PersistenceController.shared.ogeContext
        blocksRange = 1...25
    case "Профиль":
        dataContext = PersistenceController.shared.firebaseContext
        blocksRange = 22...40
    default: // "База"
        dataContext = PersistenceController.shared.firebaseContext
        blocksRange = 1...21
    }

    let session = ExamSessionEntity(context: localContext)
    session.id = UUID()
    session.date = Date()
    session.profileType = profile
    session.correctAnswersCount = 0
    session.isCompleted = false
    session.remainingTime = 3 * 3600 + 55 * 60

    var order: Int16 = 1
    for block in blocksRange {
        if let question = fetchRandomQuestionFromBlock(block, dataContext: dataContext) {
            let examQuestion = ExamQuestionEntity(context: localContext)
            examQuestion.id = UUID()
            examQuestion.blockID = Int16(block)
            examQuestion.taskID = question.taskID
            examQuestion.questionText = question.taskText ?? ""
            examQuestion.drawingHtml = question.drawingLink ?? ""
            examQuestion.correctAnswer = question.answer ?? ""
            examQuestion.userAnswer = nil
            examQuestion.isCorrect = false
            examQuestion.orderIndex = order
            order += 1

            session.addToQuestions(examQuestion)
        } else {
            print("⚠️ Не найден вопрос для блока \(block) (профиль: \(profile))")
        }
    }

    do {
        try localContext.save()
        print("✅ Экзамен создан (\(profile)): \(blocksRange.count) вопросов.")
        return session
    } catch {
        print("❌ Ошибка сохранения экзамена: \(error)")
        return nil
    }
}

func fetchOngoingExamSession(context: NSManagedObjectContext) -> ExamSessionEntity? {
    let request: NSFetchRequest<ExamSessionEntity> = ExamSessionEntity.fetchRequest()
    request.predicate = NSPredicate(format: "isCompleted == NO")

    do {
        return try context.fetch(request).first
    } catch {
        print("❌ Ошибка при поиске незавершённой сессии: \(error)")
        return nil
    }
}



struct ResultWebView: UIViewRepresentable {
    let results: [(number: Int, user: String, correct: String, isCorrect: Bool)]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("📩 JS LOG: \(message.body)")
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "logger")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = buildResultHTML(from: results)
        webView.loadHTMLString(html, baseURL: nil)
    }
}

func buildResultHTML(from results: [(number: Int, user: String, correct: String, isCorrect: Bool)]) -> String {
    let header = """
    <tr>
        <th style="font-size: 20px;">№</th>
        <th style="font-size: 20px;">Ответ</th>
        <th style="font-size: 20px;">Правильно</th>
    </tr>
    """

    let rows = results.map { result -> String in
        let userLatex = cleanLatex(result.user).replacingOccurrences(of: "\\", with: "\\\\")
        let mathjsCorrect = result.correct
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: ".")
        
        let userColor = result.isCorrect ? "" : "style='background-color: #ffe5e5'"
        let correctColor = result.isCorrect ? "style='background-color: #e5ffe5'" : ""

        return """
        <tr>
            <td style="font-size: 20px;">\(result.number)</td>
            <td \(userColor)><span id="user\(result.number)" style="font-size: 300%;"></span></td>
            <td \(correctColor)><span id="correct\(result.number)" style="font-size: 300%;"></span></td>
        </tr>
        
        <script>
            console.log("➡️ Вопрос №\(result.number): начало рендеринга");

            console.log("🔹 Пользовательский LaTeX: \(userLatex)");
            document.getElementById('user\(result.number)').innerHTML = katex.renderToString("\(userLatex)", { throwOnError: false });

            console.log("🔹 Math.js вход (правильный ответ): \(mathjsCorrect)");
            try {
                const correctExpr\(result.number) = math.parse("\(mathjsCorrect)").toTex();
                console.log("✅ Math.js → LaTeX: ", correctExpr\(result.number));

                document.getElementById('correct\(result.number)').innerHTML = katex.renderToString(correctExpr\(result.number), { throwOnError: false });
                console.log("🎯 KaTeX рендер завершён для вопроса №\(result.number)");
            } catch (e) {
                console.error("❌ Ошибка при парсинге или рендере вопроса №\(result.number):", e);
            }
        </script>

        """
    }.joined()

    return """
    <html>
    <head>
    <meta charset="UTF-8">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.css">
    <script src="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/mathjs/9.4.4/math.min.js"></script>

    <script>
    (function interceptLogs() {
        const originalLog = console.log;
        const originalErr = console.error;

        console.log = function(...args) {
            window.webkit.messageHandlers.logger.postMessage(args.join(" "));
            originalLog.apply(console, args);
        };
        console.error = function(...args) {
            window.webkit.messageHandlers.logger.postMessage("🔴 " + args.join(" "));
            originalErr.apply(console, args);
        };
    })();
    </script>

    </head>
    <body style="font-family: -apple-system, sans-serif; margin: 10px;">
    <table border="1" cellpadding="12" cellspacing="0" style="width:100%; border-collapse: collapse; text-align: left;">
    \(header)
    \(rows)
    </table>
    </body>
    </html>
    """

}

func cleanLatex(_ input: String) -> String {
    return input.replacingOccurrences(of: "\\lceil", with: "")
}



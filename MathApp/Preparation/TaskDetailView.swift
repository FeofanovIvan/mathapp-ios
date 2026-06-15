//
//  TaskDetailView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 16/01/25.
//

import SwiftUI
import CoreData
// TestCase.swift
import Foundation
import WebKit



struct TestCase {
    let userLatex: String
    let correctLatex: String
    let expectedResult: Bool
}

// seed data
let testCases: [TestCase] = [
    TestCase(
        userLatex: "(\\frac{-1-\\sqrt[]{5}}{2}<x<\\frac{1}{3})\\cup (x>\\frac{\\sqrt[]{5}-1}{2})\\lceil",
        correctLatex: "((-1-sqrt(5))/2<x<1/3)or(x>((sqrt(5)-1)/2))",
        expectedResult: true
    ),
    TestCase(userLatex: "1<log_{3}(5)<2\\lceil",
             correctLatex: "1<log(5,3)<2",
             expectedResult: true),
    TestCase(userLatex: "2sin^{2}x+10sinx+2=sinx+7\\lceil",
             correctLatex: "2 * (sin(x))^2 + 10 * sin(x) + 2 = sin(x) + 7",
             expectedResult: true),
    TestCase(userLatex: "2sinx^{2}+10sinx+2=sinx+7\\lceil",
             correctLatex: "2 * sin(x)^2 + 10 * sin(x) + 2 = sin(x) + 7",
             expectedResult: true),
    TestCase(userLatex: "(x\\leq \\frac{1}{3})\\cup (x\\geq \\frac{1}{2})\\lceil",
             correctLatex: "(x<=1/3)or(x>=1/2)",
             expectedResult: true),
    TestCase(userLatex: "720*0.5=30\\lceil",
             correctLatex: "720*0.5",
             expectedResult: true),
    TestCase(userLatex: "\\frac{3 \\sqrt{7}}{2}",
             correctLatex: "(3 * sqrt(7)) / 2",
             expectedResult: true),
    TestCase(userLatex: "0<x<\\frac{5}{6}\\lceil",
             correctLatex: "(0<x<5/6)",
             expectedResult: true),
    TestCase(userLatex: "a+b+c",
             correctLatex: "a+b+c",
             expectedResult: true),
    TestCase(userLatex: "\\frac{\\pi}{6}+2a\\pi\\lceil",
             correctLatex: "pi/6+2*a*pi",
             expectedResult: true),
    TestCase(userLatex: "(\\cos(\\frac{\\pi}{4})+2)*3b=2\\sin(\\frac{\\pi}{4})\\lceil",
             correctLatex: "(cos(pi/4)+2)*3*b=2*sin(pi/4)",
             expectedResult: true),
    TestCase(userLatex: "log_{8}(\\frac{x+a}{x-a})=log_{8}(\\frac{2a}{x-a})\\lceil",
             correctLatex: "log((x+a)/(x-a),8)=log((2a)/(x-a),8)",
             expectedResult: true),

    // (опционально) из блока "Дополнительные вариации" в Kotlin
    TestCase(userLatex: "(log_{5}(\\frac{\\sqrt[]{3}-1}{2})\\leq x<0)\\cup (0<x\\leq log_{5}(\\frac{\\sqrt[]{13}-1}{2}))\\lceil",
             correctLatex: "(log((sqrt(3)-1)/2, 5)<=x<0)or(0<x<=log((sqrt(13)-1)/2, 5))",
             expectedResult: true)
]





struct TaskDetailView: View {
    let taskName: String
    let taskIndex: Int
    let selectedProfile: String     // ⬅️ добавили

    @State private var selectedTab: TaskTab = .task
    @State private var isMenuOpen: Bool = false
    @State private var showDraftCanvas: Bool = false
    @StateObject private var canvasState = DrawingCanvasState()
    @State private var isRunningTests = false
    @State private var currentTestIndex: Int? = nil

    // ⬇️ НЕ полагаемся на Environment MOC, т.к. он у вас = firebaseContext и не подходит для ОГЭ
    private var dataContext: NSManagedObjectContext {
        selectedProfile == "ОГЭ"
        ? PersistenceController.shared.ogeContext
        : PersistenceController.shared.firebaseContext
    }

    @State private var taskEntities: [TaskEntity] = []
    @State private var selectedTaskID: Int64?

    @State private var taskTextHeight: CGFloat = 1
    @State private var drawingHeight: CGFloat = 1

    @StateObject private var keyboardCoordinator = MathKeyboardCoordinator()
    @State private var keyboardWebView = WKWebView()
    @State private var showHintPopup = false

    @State private var firstStepText: String = ""
    @State private var completedTaskIDs: Set<Int64> = []
    @State private var previousTabBeforeDraft: TaskTab? = nil
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.dismiss) private var dismiss



    var body: some View {
            ZStack {
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

                        HStack(spacing: 15) {
                            ForEach(TaskTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    if tab == .draft {
                                        previousTabBeforeDraft = selectedTab // ✅ сохраняем текущую вкладку
                                        showDraftCanvas = true
                                    } else {
                                        selectedTab = tab
                                    }
                                }) {

                                    VStack {
                                        Text(tab.rawValue)
                                            .font(.headline)
                                            .foregroundColor(selectedTab == tab ? .green : .gray)
                                        Rectangle()
                                            .frame(height: 2)
                                            .foregroundColor(selectedTab == tab ? .green : .clear)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)


                // Контент вкладки
                ZStack {
                    if showHintPopup, let hint = currentTaskHint {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation {
                                    showHintPopup = false
                                }
                            }

                        HintPopupView(show: $showHintPopup, latexContent: hint)
                            .transition(.scale)
                            .zIndex(2)
                    }

                    if selectedTab == .task {
                        if let selectedTaskID = selectedTaskID,
                           let task = taskEntities.first(where: { $0.taskID == selectedTaskID }) {
                            ScrollView {
                                VStack(spacing: 16) {
                                    // Задание
                                    TaskMathWebView(content: task.taskText ?? "", height: $taskTextHeight)
                                        .frame(height: taskTextHeight)

                                    // Чертеж, если есть
                                    if let drawing = task.drawingLink, !drawing.isEmpty {
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
                        answerTabView
                    }


                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)



                    // Нижняя панель с кнопками
                    let isPhoneLandscape = UIDevice.current.userInterfaceIdiom == .phone && vSizeClass == .compact
                    let hideBottomBar = (selectedTab == .answer && isPhoneLandscape)

                    if !hideBottomBar {
                        HStack(spacing: 30) {
                    Button(action: {
                        canvasState.clear() // Очистить рисовалку перед выходом (если нужно)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }

                    Button(action: {
                        withAnimation {
                            showHintPopup = true
                        }
                    }) {
                        Image(systemName: "lightbulb.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color.yellow)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }

                    Button(action: {
                        handleContinueAction()
                    }) {
                        Image(systemName: "play.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
                .padding()
                .background(Color.clear)
            }
                }
            .allowsHitTesting(!isMenuOpen)
            .onAppear {
                if let taskID = selectedTaskID {
                    loadFirstStepText(taskID: taskID)   // ⬅️ без параметра контекста
                }
                loadTasks()
                  loadCompletedTasks()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectFirstIncompleteTask()
                }
                // if !isRunningTests {
                // runTest(at: 0)

                //isRunningTests = true
                //  }

            }
            .onReceive(NotificationCenter.default.publisher(for: .taskCompleted)) { notification in
                if let taskID = notification.object as? Int64 {
                    print("🔔 Завершено задание с ID: \(taskID)")
                    loadCompletedTasks()
                }
            }


            .onChange(of: selectedTaskID) {
                if let taskID = selectedTaskID {
                    loadFirstStepText(taskID: taskID)   // ⬅️ без параметра контекста
                }
                
            }

            // Боковое меню
            if isMenuOpen {
                sideMenu
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showDraftCanvas, onDismiss: {
            if let previous = previousTabBeforeDraft {
                selectedTab = previous
            }
            previousTabBeforeDraft = nil
        }) {

            TaskDraftCanvasWrapper(canvasState: canvasState) {
                showDraftCanvas = false
            }
        }
        .onDisappear {
            canvasState.clear()
            
        }

    }
    private var answerTabView: some View {
        if let selectedTask = taskEntities.first(where: { $0.taskID == selectedTaskID }),
           let steps = selectedTask.steps?.compactMap({ $0 as? StepEntity }),
           let firstStep = steps.first {

            return AnyView(
                TaskAnswerInputView(
                    coordinator: keyboardCoordinator,
                    webView: keyboardWebView,
                    step: firstStep,
                    // ⬇️ прокидываем реальные действия родителя
                    onClose: {
                        canvasState.clear()
                        dismiss()
                    },
                    onShowHint: {
                        withAnimation { showHintPopup = true }
                    },
                    onContinue: {
                        handleContinueAction()
                    }
                )
                .id(selectedTaskID)
            )
        } else {
            return AnyView(Text("Шаг не найден"))
        }
    }


  
    private func handleContinueAction() {
        if selectedTab == .task {
            selectedTab = .answer
        } else if selectedTab == .answer {
            guard let currentIndex = taskEntities.firstIndex(where: { $0.taskID == selectedTaskID }) else {
                return
            }

            // Переход к следующему НЕрешённому вопросу
            if let nextIncomplete = taskEntities[(currentIndex + 1)...].first(where: { !completedTaskIDs.contains($0.taskID) }) {
                selectedTaskID = nextIncomplete.taskID
                selectedTab = .task
                print("➡️ Переход к следующему НЕрешённому вопросу: \(nextIncomplete.taskID)")
            }
            // Иначе просто к следующему
            else if currentIndex + 1 < taskEntities.count {
                selectedTaskID = taskEntities[currentIndex + 1].taskID
                selectedTab = .task
                print("➡️ Переход к следующему вопросу: \(taskEntities[currentIndex + 1].taskID)")
            }
            // Если текущий последний — перейти к первому
            else if let first = taskEntities.first {
                selectedTaskID = first.taskID
                selectedTab = .task
                print("🔁 Переход к первому вопросу: \(first.taskID)")
            }
        }
    }


    private func loadCompletedTasks() {
        let context = PersistenceController.shared.localContext
        let request: NSFetchRequest<UserStepProgress> = UserStepProgress.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == YES")

        do {
            let results = try context.fetch(request)
            let taskIDs = results.map { $0.taskID }
            completedTaskIDs = Set(taskIDs)
        } catch {
            print("❌ Ошибка загрузки завершённых задач: \(error.localizedDescription)")
        }
    }
        
    private func selectFirstIncompleteTask() {
            let incompleteTask = taskEntities.first(where: { !completedTaskIDs.contains($0.taskID) })

            if let task = incompleteTask {
                selectedTaskID = task.taskID
                print("🔄 Перешли к первому незавершённому заданию: \(task.taskID)")
        } else if let first = taskEntities.first {
                // Все задания завершены — откроем первое заново
                selectedTaskID = first.taskID
                print("🔁 Все задания завершены. Показываем первое: \(first.taskID)")
        } else {
                print("⚠️ Нет доступных заданий")
        }
    }
        

    private func loadFirstStepText(taskID: Int64) {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "taskID == %d", taskID)
        request.fetchLimit = 1

        if let task = try? dataContext.fetch(request).first,     // ⬅️ dataContext
           let steps = task.steps?.array as? [StepEntity],
           let firstStep = steps.sorted(by: { $0.stepID < $1.stepID }).first {
            firstStepText = firstStep.stepText ?? ""
        }
    }
    private var currentTaskHint: String? {
        guard let taskID = selectedTaskID else { return nil }
        return taskEntities.first(where: { $0.taskID == taskID })?.hint
    }
    
    // MARK: - Боковое меню
    private var sideMenu: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(taskName)
                        .font(.headline)
                        .padding()
                        .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                    Divider()

                    ForEach(taskEntities.indices, id: \.self) { index in
                        let task = taskEntities[index]
                        let isCompleted = completedTaskIDs.contains(task.taskID)

                        Button(action: {
                            selectedTaskID = task.taskID
                            isMenuOpen = false
                        }) {
                            HStack {
                                Text("Вопрос \(index + 1)")
                                    .foregroundColor(isCompleted ? .green : Color(red: 0.12, green: 0.18, blue: 0.35))
                                    .fontWeight(isCompleted ? .bold : .regular)

                                Spacer()

                                if selectedTaskID == task.taskID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                        }
                    }
                }
                    
                    Spacer()
            
            }
            .frame(width: 250)
            .background(Color.white)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 2, y: 0)


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

    // MARK: - Загрузка задач
    private func loadTasks() {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "block.blockID == %d", taskIndex)

        do {
            taskEntities = try dataContext.fetch(fetchRequest) // ⬅️ контекст по профилю
            selectedTaskID = taskEntities.first?.taskID
        } catch {
            print("❌ Ошибка при загрузке задач: \(error.localizedDescription)")
        }
    }
}
struct TaskDraftCanvasWrapper: View {
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


import SwiftUI
import WebKit

struct TaskMathWebView: UIViewRepresentable {
    let content: String
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
        let html = wrapHtml(content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: TaskMathWebView

        init(parent: TaskMathWebView) {
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

    private func wrapHtml(_ content: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/3.2.2/es5/tex-mml-chtml.js" async></script>
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                }
                body {
                    font-family: -apple-system, sans-serif;
                    font-size: 18px;
                    padding: 8px;
                    /* вертикальный скролл оставляем у страницы */
                    overflow-y: auto;
                    /* а горизонтальный отдаём вложенным контейнерам */
                    overflow-x: hidden;
                    -webkit-overflow-scrolling: touch;
                }
                /* контейнер для горизонтального скролла таблицы */
                .hscroll {
                    width: 100%;
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                }
                /* Делаем таблицу шире контента, чтобы появился горизонтальный скролл */
                table {
                    border-collapse: collapse;
                    /* Если таблица шире экрана — пусть будет “контентной” ширины */
                    width: max-content;
                    min-width: 100%;
                }
                th, td {
                    border: 1px solid #000;
                    padding: 6px;
                    /* Чтобы колонки не ломались и реально уезжали за край */
                    white-space: nowrap;
                }
                img, svg { max-width: 100%; height: auto; }
            </style>
            <script>
                // Оборачиваем все таблицы в .hscroll автоматически
                document.addEventListener('DOMContentLoaded', function() {
                    document.querySelectorAll('table').forEach(function(tbl) {
                        if (!tbl.parentElement || !tbl.parentElement.classList.contains('hscroll')) {
                            const wrap = document.createElement('div');
                            wrap.className = 'hscroll';
                            tbl.parentNode.insertBefore(wrap, tbl);
                            wrap.appendChild(tbl);
                        }
                    });
                });
            </script>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }

}


// MARK: - Перечисление вкладок
enum TaskTab: String, CaseIterable {
    case task = "ЗАДАНИЕ"
    case answer = "РЕШЕНИЕ"
    case draft = "ЧЕРНОВИК"
}


import SwiftUI
import WebKit
import CoreData

struct TaskAnswerInputView: View {
    let coordinator: MathKeyboardCoordinator
    let webView: WKWebView
    let step: StepEntity
    
    // ⬇️ новые колбэки
    let onClose: () -> Void
    let onShowHint: () -> Void
    let onContinue: () -> Void
    init(
        coordinator: MathKeyboardCoordinator,
        webView: WKWebView,
        step: StepEntity,
        onClose: @escaping () -> Void = {},
        onShowHint: @escaping () -> Void = {},
        onContinue: @escaping () -> Void = {}
    ) {
        self.coordinator = coordinator
        self.webView = webView
        self.step = step
        self.onClose = onClose
        self.onShowHint = onShowHint
        self.onContinue = onContinue
    }

    @State private var webViewHeight: CGFloat = 1
    @State private var keyboardHeight: CGFloat = 0
    @State private var latexPreview: String = ""
    @State private var showInstructionPopup = false
    @State private var stepWebViewHeight: CGFloat = 1
    @State private var showHiddenWeb = false
    @State private var userLatex: String = ""
    @State private var showResultToast = false
    @State private var isAnswerCorrect = false
    @State private var completedSteps: [StepEntity] = []
    @State private var currentStepIndex: Int = 0
    @State private var allSteps: [StepEntity] = []
    @State private var savedAnswers: [String] = []
    @State private var completedHeights: [CGFloat] = []
    @State private var taskCompleted = false


    @Environment(\.managedObjectContext) private var context

    private var currentStep: StepEntity? {
        guard currentStepIndex < allSteps.count else { return nil }
        return allSteps[currentStepIndex]
    }

    func showResult(_ correct: Bool) {
        isAnswerCorrect = correct
        withAnimation {
            showResultToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showResultToast = false
            }
        }
    }
    @ViewBuilder
    private var taskAnswerContent: some View {
        VStack(spacing: 16) {
            ForEach(Array(completedSteps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 12) {
                    StepWebView(
                        content: step.stepText ?? "",
                        height: Binding(get: {
                            if index < completedHeights.count {
                                return completedHeights[index]
                            } else {
                                return 1
                            }
                        }, set: { newHeight in
                            if index < completedHeights.count {
                                completedHeights[index] = newHeight
                            } else {
                                completedHeights.append(newHeight)
                            }
                        })
                    )
                    .frame(height: index < completedHeights.count ? completedHeights[index] : 1)
                    .padding(.top, 8)

                    Text("Ответ:")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    KeyboardPreviewWebView(content: savedAnswers[index], height: .constant(40))
                        .frame(height: 40)
                }
                .padding(.horizontal)
            }

            if let currentStep = currentStep {
                StepWebView(content: currentStep.stepText ?? "", height: $stepWebViewHeight)
                    .frame(height: stepWebViewHeight)
                    .padding(.top, 16)
                    .padding(.horizontal)

                HStack {
                    Text("Введите ответ ниже:")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Spacer()
                    Button(action: {
                        userLatex = latexPreview
                        showHiddenWeb = true
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

                KeyboardPreviewWebView(content: latexPreview, height: $webViewHeight)
                    .frame(height: webViewHeight)

                MathKeyboardView(coordinator: coordinator, webView: webView)
                    .frame(height: 0)

                Spacer(minLength: 20)
            } else {
                VStack(spacing: 16) {
                    Text("🎉 Задача решена!")
                        .font(.title2)
                        .padding()

                    Button(action: resetProgress) {
                        Text("🔁 Попробовать ещё раз")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let keyboardWidth = geometry.size.width * 0.45
            Group {
                if isLandscape && !isPad {
                    // ✅ Горизонтальный layout — только на iPhone
                    HStack(spacing: 0) {
                        ScrollView {
                            taskAnswerContent
                        }
                        .frame(width: geometry.size.width - keyboardWidth)
                        
                        VStack(spacing: -12) {
                            // Клавиатура — занимает всё сверху
                            CustomKeyboard(coordinator: coordinator, containerWidth: keyboardWidth)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()

                            // Кнопки — вместе с клавиатурой в правой колонке
                            HStack(spacing: 30) {
                                Button(action: {
                                    onClose()  // ⬅️ вместо canvasState/dismiss напрямую
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable().scaledToFit().frame(width: 25, height: 25)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .shadow(radius: 3)
                                }

                                Button(action: {
                                    onShowHint() // ⬅️ покажем Hint у родителя
                                }) {
                                    Image(systemName: "lightbulb.fill")
                                        .resizable().scaledToFit().frame(width: 40, height: 35)
                                        .foregroundColor(.yellow)
                                        .padding()
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }

                                Button(action: {
                                    onContinue() // ⬅️ логика "Продолжить" родителя
                                }) {
                                    Image(systemName: "play.fill")
                                        .resizable().scaledToFit().frame(width: 25, height: 25)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.green)
                                        .clipShape(Circle())
                                        .shadow(radius: 3)
                                }
                            }

                            .padding(.bottom, )
                        }
                        .frame(width: keyboardWidth)
                        .background(Color.white)
                        .clipped()
                    }
                } else {
                    // ✅ Вертикальный layout — портрет или iPad
                    VStack(spacing: 0) {
                        // 🔹 СКРОЛЛ-КОНТЕНТ (всё содержимое шага + ответ)
                        ScrollView {
                            taskAnswerContent
                        }



                        // 🔹 КНОПКА и КЛАВИАТУРА (внизу!)
                        VStack(spacing: 10) {
                            HStack {
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
                                        .padding()
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)

                            CustomKeyboard(coordinator: coordinator)
                        }
                        .padding(.bottom, keyboardHeight + 10)
                        .background(Color.white)
                    }
                }

            }
            .edgesIgnoringSafeArea(.bottom)
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
            
            .onAppear {
                
                coordinator.onLatexUpdate = { latex in
                    latexPreview = latex
                }
                if let stepsSet = step.task?.steps as? NSOrderedSet {
                    allSteps = stepsSet
                        .compactMap { $0 as? StepEntity }
                        .sorted { $0.stepID < $1.stepID }

                       // Загрузка прогресса из MathApp
                       loadUserProgress(for: step.task?.taskID ?? 0)
                   }
            }
            
            .overlay(overlayViews)
        }
    }
    private func resetProgress() {
        guard let taskID = step.task?.taskID else { return }

        let context = PersistenceController.shared.localContext
        let request: NSFetchRequest<NSFetchRequestResult> = UserStepProgress.fetchRequest()
        request.predicate = NSPredicate(format: "taskID == %d", taskID)

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            try context.save()
            print("🧹 Прогресс очищен для taskID \(taskID)")

            // Сброс UI
            completedSteps = []
            savedAnswers = []
            currentStepIndex = 0
            taskCompleted = false
            latexPreview = ""
            coordinator.clearAllInput()

            // ⏱ Обновить боковое меню
            NotificationCenter.default.post(name: .taskCompleted, object: taskID)

        } catch {
            print("❌ Ошибка при очистке прогресса: \(error.localizedDescription)")
        }
    }

    private func loadUserProgress(for taskID: Int64) {
        let context = PersistenceController.shared.localContext // ✅ Используем локальный контекст

        let request: NSFetchRequest<UserStepProgress> = UserStepProgress.fetchRequest()
        request.predicate = NSPredicate(format: "taskID == %d", taskID)

        do {
            let results = try context.fetch(request)
            let sorted = results.sorted { $0.stepID < $1.stepID }

            for entry in sorted where entry.isCorrect {
                if let step = allSteps.first(where: { $0.stepID == entry.stepID }) {
                    completedSteps.append(step)
                    savedAnswers.append(entry.userAnswer ?? "")
                    currentStepIndex += 1
                }
            }

            if results.contains(where: { $0.isCompleted }) {
                taskCompleted = true
            }

            print("✅ Прогресс успешно загружен: \(completedSteps.count) шагов")
        } catch {
            print("❌ Ошибка при загрузке прогресса: \(error.localizedDescription)")
        }
    }


    @ViewBuilder
    private var overlayViews: some View {
        if showResultToast {
            ZStack {
                       Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)
                       VStack {
                           Spacer()
                           Text(taskCompleted ? "🎉 Задача решена!" : (isAnswerCorrect ? "✅ Правильно!" : "❌ Неправильно"))
                               .font(.headline)
                               .padding()
                               .background(
                                   taskCompleted
                                       ? Color.blue
                                       : (isAnswerCorrect ? Color.green : Color.red)
                               )
                               .foregroundColor(.white)
                               .cornerRadius(12)
                               .shadow(radius: 10)
                               .transition(.scale)
                           Spacer()
                }
            }
        }

        if showInstructionPopup {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { withAnimation { showInstructionPopup = false } }

            InstructionPopupView(show: $showInstructionPopup)
                .transition(.scale)
                .zIndex(1)
        }

        if showHiddenWeb, let step = currentStep {
            HiddenCompareWebView(
                userAnswer: userLatex,
                correctAnswer: step.stepAction ?? "",
                onResult: { isCorrect in
                    print("📥 Ответ пользователя: \(userLatex)")
                    print("📘 Правильный ответ: \(step.stepAction ?? "")")
                    print(isCorrect ? "🎉 Совпадают!" : "❌ Не совпадают.")
                    showResult(isCorrect)
                    showHiddenWeb = false

                    if isCorrect {
                        let cleanedAnswer = userLatex.replacingOccurrences(of: "\\lceil", with: "")
                        completedSteps.append(step)
                        savedAnswers.append(cleanedAnswer)

                        // ✅ Используем локальный контекст из MathApp
                        let context = PersistenceController.shared.localContext

                        let newProgress = UserStepProgress(context: context)
                        newProgress.taskID = step.task?.taskID ?? 0
                        newProgress.stepID = step.stepID
                        newProgress.userAnswer = cleanedAnswer
                        newProgress.isCorrect = true
                        newProgress.timestamp = Date()

                        do {
                            try context.save()
                            print("✅ Прогресс шага сохранён")
                        } catch {
                            print("❌ Ошибка при сохранении прогресса: \(error.localizedDescription)")
                        }

                        if currentStepIndex + 1 < allSteps.count {
                            currentStepIndex += 1
                            latexPreview = ""
                            coordinator.clearAllInput()
                        } else {
                            // Все шаги завершены
                            taskCompleted = true
                            showResult(true)
                            currentStepIndex += 1
                            latexPreview = ""
                            coordinator.clearAllInput()
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: .taskCompleted, object: step.task?.taskID)
                            }


                            // ✅ Отмечаем завершение задания
                            let finalProgress = UserStepProgress(context: context)
                            finalProgress.taskID = step.task?.taskID ?? 0
                            finalProgress.stepID = step.stepID
                            finalProgress.userAnswer = cleanedAnswer
                            finalProgress.isCorrect = true
                            finalProgress.isCompleted = true
                            finalProgress.timestamp = Date()

                            do {
                                try context.save()
                                print("🎉 Задание отмечено как завершённое")
                            } catch {
                                print("❌ Ошибка при сохранении завершения: \(error.localizedDescription)")
                            }
                        }
                    }

                }
            )
            .frame(width: 0, height: 0)
        }
    }
}
struct StepWebView: UIViewRepresentable {
    let content: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(buildHTML(from: content), baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(buildHTML(from: content), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: StepWebView

        init(_ parent: StepWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = height
                    }
                }
            }
        }
    }

    private func buildHTML(from latex: String) -> String {
        // Если не нужна спец-экранизация — можно оставить как есть:
        let escaped = latex // .replacingOccurrences(of: ...)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="color-scheme" content="light dark">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                html, body { margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, sans-serif;
                    font-size: 16px;
                    padding: 10px;
                    overflow-y: auto;
                    overflow-x: hidden; /* горизонтальный скролл отдаём вложенным контейнерам */
                    -webkit-overflow-scrolling: touch;
                }
                /* Контейнер с горизонтальным скроллом */
                .hscroll {
                    width: 100%;
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                }
                /* Таблица как «контентной» ширины, чтобы реально уходила за край */
                table {
                    border-collapse: collapse;
                    width: max-content;
                    min-width: 100%;
                }
                th, td {
                    border: 1px solid #000;
                    padding: 6px;
                    white-space: nowrap; /* чтобы колонки не переносились */
                }
                /* Чтобы svg/картинки красиво вписывались */
                img, svg { max-width: 100%; height: auto; }
            </style>
            <script>
                // Оборачиваем все таблицы в .hscroll автоматически
                document.addEventListener('DOMContentLoaded', function() {
                    document.querySelectorAll('table').forEach(function(tbl) {
                        if (!tbl.parentElement || !tbl.parentElement.classList.contains('hscroll')) {
                            const wrap = document.createElement('div');
                            wrap.className = 'hscroll';
                            tbl.parentNode.insertBefore(wrap, tbl);
                            wrap.appendChild(tbl);
                        }
                    });
                });
            </script>
        </head>
        <body>
            \(escaped)
            <script>MathJax.typesetPromise();</script>
        </body>
        </html>
        """
    }

}

import SwiftUI
import WebKit

struct KeyboardPreviewWebView: UIViewRepresentable {
    let content: String
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
        let html = wrapHtml(content)
        webView.loadHTMLString(html, baseURL: nil)

        // Подождём немного, чтобы дать MathJax отрендерить всё
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.height = height
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: KeyboardPreviewWebView
        init(parent: KeyboardPreviewWebView) {
            self.parent = parent
        }
    }

    private func wrapHtml(_ content: String) -> String {
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "")
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>Math Preview</title>
            <link href="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.css" rel="stylesheet">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.13.0/dist/katex.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/mathjs/9.4.4/math.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/decimal.js/10.3.1/decimal.min.js"></script>
            <style>
                body {
                    font-size: 50px;
                    text-align: center;
                    margin: 0;
                    padding: 10px;
                }
                        #mathRender {
                            border: 2px solid transparent;
                            border-bottom: 2px solid #00ff00;
                            padding: 5px;
                            background-color: transparent;
                            min-height: 20px;
                            display: flex;
                        }
            </style>
        </head>
        <body>
            <div id="mathRender"></div>

            <script>
                function renderMath() {
                    const latex = '\(escapedContent)';
                    try {
                        katex.render(latex, document.getElementById('mathRender'), {
                            throwOnError: false
                        });
                    } catch (e) {
                        document.getElementById('mathRender').innerText = 'Ошибка рендера';
                    }
                }

                renderMath();
            </script>
        </body>
        </html>
        """
    }

}



struct InstructionPopupView: View {
    @Binding var show: Bool

    var body: some View {
        VStack(spacing: 2) {
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

            // Заголовок
            Text("Краткое руководство по использованию математической клавиатуры:")
                .font(.headline)
                .multilineTextAlignment(.leading)
                .lineLimit(nil) // 👈 разрешаем неограниченное количество строк
                .fixedSize(horizontal: false, vertical: true) // 👈 разрешаем перенос по ширине
                .frame(maxWidth: .infinity, alignment: .leading)

                       VStack(alignment: .leading, spacing: 12) {
                           Text("• Перемещение курсора происходит с помощью клавиши ⏎ (например, из числителя в знаменатель или основания логарифма в подлогарифмическое выражение).")
                           Text("• Символы ≥ и ≤ создаются при последовательном вводе символов >= или <=.")
                           Text("• Кнопка CE очищает всё.")
                           Text("• Кнопка ⌫ удаляет последний символ.")
                       }
                       .font(.system(size: 15))
                       .multilineTextAlignment(.leading)
                       .fixedSize(horizontal: false, vertical: true)
                       .frame(maxWidth: .infinity, alignment: .leading)

                       Spacer()
                   }
                   .padding(20)
                   .frame(maxWidth: 360, maxHeight: 340)
                   .background(Color.white)
                   .cornerRadius(16)
                   .shadow(radius: 10)
                   .padding()
               }
           }
struct HintPopupView: View {
    @Binding var show: Bool
    let latexContent: String

    var body: some View {
        GeometryReader { geo in
            // адаптивные ограничения
            let maxW = min(geo.size.width * 0.8, 520)   // не шире 80% экрана, максимум ~520
            let maxH = min(geo.size.height * 0.8, 480)  // не выше 80% экрана, максимум ~480
            let headerH: CGFloat = 56                   // примерная высота хедера с крестиком
            let webH = max(200, maxH - headerH - 24)    // оставляем место под контент (минимум 200)

            VStack(spacing: 0) {
                // Хедер с кнопкой закрытия
                HStack {
                    Spacer()
                    Button {
                        withAnimation { show = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.pink)
                            .padding(12)
                    }
                }
                .frame(height: headerH)

                // Контент (скролл внутри)
                HintWebView(latex: latexContent)
                    .frame(height: webH)
                    .cornerRadius(12)
                    .clipped()
            }
            .frame(width: maxW, height: maxH) // ← ключевая строка: ограничили размеры попапа
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(16)
            .frame(width: geo.size.width, height: geo.size.height) // центрируем в экране
        }
    }
}

struct HintWebView: UIViewRepresentable {
    let latex: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = true // ✅ скроллируемый внутри
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = wrapHtml(latex)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func wrapHtml(_ content: String) -> String {
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
                    overflow-y: auto;
                    -webkit-overflow-scrolling: touch;
                }
                img, svg {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
}

import SwiftUI
import WebKit

struct HiddenCompareWebView: UIViewRepresentable {
    let userAnswer: String
    let correctAnswer: String
    let onResult: (Bool) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "logger")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isHidden = true
        return webView

    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = buildHTML(userAnswer: userAnswer, correctAnswer: correctAnswer)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }


    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onResult: (Bool) -> Void

        init(onResult: @escaping (Bool) -> Void) {
            self.onResult = onResult
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("processComparison()") { result, error in
                if let isEqual = result as? Bool {
                    self.onResult(isEqual)
                } else {
                    self.onResult(false)
                }
            }
        }

        // 👇 Вот тут получаем console.log из JS
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print(message.body)
        }
    }


    private func buildHTML(userAnswer: String, correctAnswer: String) -> String {
        let escapedUserAnswer = userAnswer.replacingOccurrences(of: "\\", with: "\\\\")
        let escapedCorrectAnswer = correctAnswer.replacingOccurrences(of: "\\", with: "\\\\")

        return """
        <!DOCTYPE html>
        <html>
           <head>
              <meta charset=\"UTF-8\">
              <script src=\"https://cdnjs.cloudflare.com/ajax/libs/mathjs/9.4.4/math.min.js\"></script>
              <script src=\"https://cdnjs.cloudflare.com/ajax/libs/decimal.js/10.3.1/decimal.min.js\"></script>
              <script>
                 // Перехват console.log и console.error
                 (function() {
                     const originalLog = console.log;
                     const originalError = console.error;
                 
                     console.log = function(...args) {
                         window.webkit.messageHandlers.logger.postMessage("📗 LOG: " + args.join(" "));
                         originalLog.apply(console, args);
                     };
                 
                     console.error = function(...args) {
                         window.webkit.messageHandlers.logger.postMessage("❌ ERROR: " + args.join(" "));
                         originalError.apply(console, args);
                     };
                 })();
              </script>
              <script>
                 console.log("🟢 WebView загружен");
              </script>
              <script>
                 const userLatex = `\(escapedUserAnswer)`;
                 const correctLatex = `\(escapedCorrectAnswer)`;
                 
                 function latexToMathjs(latex) {
                 console.log("Преобразование LaTeX в math.js формат:", latex);
                 
                 let mathjsExpr = removeCursor(latex);
                 console.log("После removeCursor: ", mathjsExpr);
                 
                 
                 // Правильно:
                 mathjsExpr = replaceFrac(mathjsExpr);
                 console.log("После обработки всех frac: ", mathjsExpr);
                 // c) разворачиваем все корни \\sqrt[n]{…} и \\sqrt[]{…}
                 mathjsExpr = replaceSqrtAll(mathjsExpr);
                 console.log("После обработки всех \\sqrt:", mathjsExpr);
                 
                 mathjsExpr = mathjsExpr.replace(/\\\\left/g, '');
                 mathjsExpr = mathjsExpr.replace(/\\\\right/g, '');
                 
                 // Теперь спокойно обрабатываем '≤', '≥' и их сокращённые варианты
                 mathjsExpr = mathjsExpr.replace(/\\\\geq/g, '>=');
                 mathjsExpr = mathjsExpr.replace(/\\\\leq/g, '<=');
                 // чуть сузим 'ge'/'le', чтобы не трогать, если за ними идут буквы
                 mathjsExpr = mathjsExpr.replace(/\\\\le/g, '<=');
                 mathjsExpr = mathjsExpr.replace(/\\\\ge/g, '>=');
                 
                 mathjsExpr = mathjsExpr.replace(/\\sqrt\\[\\]\\{([^}]+)\\}/g, 'sqrt($1)');
                 
                 
                 mathjsExpr = mathjsExpr.replace(/\\\\sqrt\\[([^\\]]+)\\]\\{([^}]+)\\}/g, 'nthRoot($2, $1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\log_\\\\\\{([^}]+)\\\\\\}\\{([^}]+)\\\\\\}/g, 'log($2, $1)');
                 mathjsExpr = replaceLogBaseParens(mathjsExpr); 

                 mathjsExpr = replaceLogBase(mathjsExpr);

                 mathjsExpr = mathjsExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\^\\{([^}]+)\\}(\\d+)\\^\\\\circ/g, '$1($3 * pi / 180)^($2)');
                 mathjsExpr = mathjsExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)(\\d+)\\^\\\\circ/g, '$1($2 * pi / 180)');
                 mathjsExpr = mathjsExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\^\\{([^}]+)\\}(\\d+)/g, '$1($3)^($2)');
                 mathjsExpr = mathjsExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)(\\d+)/g, '$1($2)');
                 
                 mathjsExpr = mathjsExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\^\\{(\\d+)\\}\\((\\w)\\)/g, '$1($3)^($2)');
                 mathjsExpr = mathjsExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\^\\{(\\d+)\\}(\\w)/g, '$1($3)^($2)');
                 
                 mathjsExpr = mathjsExpr.replace(/\\\\cdot/g, '*');
                 
                 
                 mathjsExpr = mathjsExpr.replace(/(\\d+)\\\\circ/g, '($1 * pi / 180)');
                 mathjsExpr = mathjsExpr.replace(/\\\\tan\\(([^)]+)\\)/g, 'tan($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\cot\\(([^)]+)\\)/g, 'cot($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\arcsin\\(([^)]+)\\)/g, 'asin($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\arccos\\(([^)]+)\\)/g, 'acos($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\arctan\\(([^)]+)\\)/g, 'atan($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\arccot\\(([^)]+)\\)/g, 'acot($1)');
                 
                 mathjsExpr = mathjsExpr.replace(/(\\d+)\\^\\{([^\\)]+)\\)/g, '$1^($2)');
                 
                 mathjsExpr = mathjsExpr.replace(/\\\\ln\\(([^)]+)\\)/g, 'log($1)');
                 
                 mathjsExpr = mathjsExpr.replace(/\\\\sin\\(([^)]+)\\)/g, 'sin($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\cos\\(([^)]+)\\)/g, 'cos($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\tan\\(([^)]+)\\)/g, 'tan($1)');
                 mathjsExpr = mathjsExpr.replace(/\\\\pi/g, 'pi');
                 mathjsExpr = mathjsExpr.replace(/\\\\e/g, 'e');
                 mathjsExpr = mathjsExpr.replace(/\\\\left/g, '');
                 mathjsExpr = mathjsExpr.replace(/\\\\right/g, '');
                 mathjsExpr = mathjsExpr.replace(/\\\\\\{/g, '(');
                 mathjsExpr = mathjsExpr.replace(/\\\\\\}/g, ')');
                 mathjsExpr = mathjsExpr.replace(/\\^\\{([^}]+)\\}/g, '^($1)');
                 
                 mathjsExpr = mathjsExpr.replace(/times/g, '*');
                 
                 // Заменяем числа перед переменными на формат умножения
                 mathjsExpr = mathjsExpr.replace(/(\\d)([xyabc])/g, '$1*$2');
                 
                 mathjsExpr = mathjsExpr.replace(/\\{/g, '(');
                 mathjsExpr = mathjsExpr.replace(/\\}/g, ')');
                 mathjsExpr = mathjsExpr.replace(/\\\\/g, '');
                 
                 mathjsExpr = mathjsExpr.replace(/\\bcup\\b/g, 'or');

                 mathjsExpr = mathjsExpr.replace(/(\\d+)\\^circ/g, '($1 * pi / 180)');

                 console.log("Преобразованное выражение после замены градусов: ", mathjsExpr);
                 return mathjsExpr;
                 }
                 // Найти соответствующую закрывающую ')', учитывая вложенность
                 function findMatchingParen(str, openPos) {
                   let depth = 0;
                   for (let i = openPos; i < str.length; i++) {
                     const ch = str[i];
                     if (ch === '(') depth++;
                     else if (ch === ')') {
                       depth--;
                       if (depth === 0) return i;
                     }
                   }
                   return -1; // не нашли
                 }

                 // Заменить \\log_{base}(\\left( ... \\right)) и \\log_{base}(...)
                 // на log(ARG, base) (формат math.js)
                 function replaceLogBaseParens(s) {
                   // \\log_{...} (возможны пробелы, опционально \\left)
                   const re = /\\log_\\{([^}]+)\\}\\s*(?:\\\\left\\s*)?\\(/g;
                   let out = '';
                   let last = 0;
                   let m;

                   while ((m = re.exec(s)) !== null) {
                     const base = m[1];
                     const openParenIdx = re.lastIndex - 1; // позиция '('
                     const closeParenIdx = findMatchingParen(s, openParenIdx);
                     if (closeParenIdx < 0) break; // оборвать, если скобки битые

                     const arg = s.slice(openParenIdx + 1, closeParenIdx);
                     out += s.slice(last, m.index) + `log(${arg}, ${base})`;
                     last = closeParenIdx + 1;
                   }
                   out += s.slice(last);
                   return out;
                 }

                 function replaceDegrees(expr) {
                 // Ищем первое вхождение “число^\\circ”
                 const regex = /(\\d+)\\^\\circ/;
                 let match;
                 // Пока есть совпадение — меняем и ищем дальше
                 while ((match = regex.exec(expr)) !== null) {
                 const [full, num] = match;
                 expr = expr.replace(full, `(${num} * pi / 180)`);
                 }
                 return expr;
                 }
                 
                 
                 function replaceLogBase(expr) {
                 // шаблон для поиска одного вхождения
                 const regex = /\\log_\\{([^}]+)\\}\\{([^}]+)\\}/;
                 let match;
                 // пока есть совпадения — заменяем и ищем дальше
                 while ((match = regex.exec(expr)) !== null) {
                 const [full, base, arg] = match;
                 expr = expr.replace(full, `log(${arg},${base})`);
                 }
                 return expr;
                 }
                 
                 // рекурсивная замена \\frac{a}{b}
                 function replaceFrac(s) {
                 
                 const tag = '\\\\frac';
                 const i = s.indexOf(tag);
                 if (i === -1) return s;
                 
                 // дальше без изменений:
                 const numStart = s.indexOf('{', i + tag.length);
                 const numEnd   = findMatchingBrace(s, numStart);
                 const num      = s.slice(numStart + 1, numEnd);
                 
                 const denStart = s.indexOf('{', numEnd + 1);
                 const denEnd   = findMatchingBrace(s, denStart);
                 const den      = s.slice(denStart + 1, denEnd);
                 
                 const replaced = '(' + replaceFrac(num) + ')/(' + replaceFrac(den) + ')';
                 const before   = s.slice(0, i);
                 const after    = s.slice(denEnd + 1);
                 
                 return replaceFrac(before + replaced + after);
                 }
                 // 2) Рекурсивно заменяем все 
                 function replaceSqrtIndexed(s) {
                 const tag = '\\sqrt[';  
                 let i = s.indexOf(tag);
                 while (i !== -1) {
                 const idxStart = i + tag.length;
                 const idxEnd   = s.indexOf(']', idxStart);
                 if (idxEnd < 0) break;
                 
                 const index = s.slice(idxStart, idxEnd);
                 // Пропускаем пустой индекс: это пустой-корень, не indexed
                 if (index === '') {
                 i = s.indexOf(tag, idxEnd + 1);
                 continue;
                 }
                 
                 // К `{` после `]`
                 const braceStart = s.indexOf('{', idxEnd);
                 if (braceStart < 0) break;
                 const braceEnd = findMatchingBrace(s, braceStart);
                 if (braceEnd < 0) break;
                 
                 const content = s.slice(braceStart + 1, braceEnd);
                 // рекурсивно обрабатываем возможные вложенные sqrt внутри и в индексе
                 const newIndex   = replaceSqrtAll(index);
                 const newContent = replaceSqrtAll(content);
                 
                 const replaced = `nthRoot(${newContent}, ${newIndex})`;
                 s = s.slice(0, i) + replaced + s.slice(braceEnd + 1);
                 
                 // ищем следующий
                 i = s.indexOf(tag, i + replaced.length);
                 }
                 return s;
                 }
                 
                 // 3) Рекурсивно заменяем все \\sqrt[]{…}
                 function replaceSqrtEmpty(s) {
                 const tag = '\\sqrt[]';  
                 let i = s.indexOf(tag);
                 while (i !== -1) {
                 const braceStart = s.indexOf('{', i + tag.length);
                 if (braceStart < 0) break;
                 const braceEnd = findMatchingBrace(s, braceStart);
                 if (braceEnd < 0) break;
                 
                 const content = s.slice(braceStart + 1, braceEnd);
                 const newContent = replaceSqrtAll(content);
                 
                 const replaced = `sqrt(${newContent})`;
                 s = s.slice(0, i) + replaced + s.slice(braceEnd + 1);
                 
                 i = s.indexOf(tag, i + replaced.length);
                 }
                 return s;
                 }
                 
                 // 4) Точка входа: indexed → empty
                 function replaceSqrtAll(s) {
                 return replaceSqrtEmpty(replaceSqrtIndexed(s));
                 }
                 function findMatchingBrace(str, pos) {
                 let depth = 0;
                 for (let j = pos; j < str.length; j++) {
                 if (str[j] === '{') depth++;
                 else if (str[j] === '}') {
                 depth--;
                 if (depth === 0) return j;
                 }
                 }
                 return -1;
                 }
                 
                 function removeCursor(latex) {
                 console.log("Удаление курсора из выражения: ", latex);
                 return latex.replace(/\\\\lceil/g, '');
                 return latex.replace(/\\lceil/g, '');
                 }
                 
                 function compareMathInputWithData(userLatex, correctLatex) {
                             console.log("Сравнение пользовательского ввода с ожидаемым ответом");
                             console.log("Исходный пользовательский ввод:", userLatex);
                             console.log("Ожидаемый ответ (из stepAction):", correctLatex);
                 
                             // Правильное удаление всех пробельных символов:
                             const userInput = latexToMathjs(userLatex).replace(/\\s+/g, '');
                             const actionData = latexToMathjs(correctLatex).replace(/\\s+/g, '').replace(/times/g, '*');
                 
                 
                             console.log("Обработанный пользовательский ввод:", userInput);
                             console.log("Обработанные данные действия:", actionData);
                              
                             const inequalitySigns = ['<=','>=','<', '>', '='];
                 
                             if (hasVariables(userInput) || hasVariables(actionData)) {
                 console.log("Обнаружены переменные. Замена переменных на 1 и вычисление.");
                 const simplifiedUserInput = replaceVariablesWithOne(userInput);
                 const simplifiedActionData = replaceVariablesWithOne(actionData);
                 
                 console.log("Упрощенный пользовательский ввод:", simplifiedUserInput);
                 console.log("Упрощенные данные действия:", simplifiedActionData);
                 
                 try {
                 // Шаг 1: Проверка наличия 'or' — если есть, разбиваем на сегменты
                 const userSegments = simplifiedUserInput.includes("or") ? simplifiedUserInput.split("or").map(s => stripOuterParens(s)) : [simplifiedUserInput];
                 const actionSegments = simplifiedActionData.includes("or") ? simplifiedActionData.split("or").map(s => stripOuterParens(s)) : [simplifiedActionData];
                 
                 if (userSegments.length !== actionSegments.length) {
                 console.log("❌ Разное количество сегментов после split('or')");
                 return false;
                 }
                 
                 // Шаг 2: Проверка каждого сегмента отдельно
                 for (let i = 0; i < userSegments.length; i++) {
                 const userSegment = userSegments[i];
                 const actionSegment = actionSegments[i];
                 
                 // Ищем знак неравенства или равенства
                 const userSign = inequalitySigns.find(sign => userSegment.includes(sign));
                 const actionSign = inequalitySigns.find(sign => actionSegment.includes(sign));
                 
                 if (!userSign || !actionSign || userSign !== actionSign) {
                         console.log("❌ Несовпадающие или отсутствующие операторы:", userSign, actionSign);

                         try {
                             const valUser = roundToDecimalPlace(evaluateExpression(userSegment), 3);
                             const valAction = roundToDecimalPlace(evaluateExpression(actionSegment), 3);

                             const isEqual = valUser === valAction;
                             console.log("📏 Сравнение выражений без оператора:");
                             console.log(`🔹 ${userSegment} → ${valUser}`);
                             console.log(`🔸 ${actionSegment} → ${valAction}`);
                             console.log(`⚖️ Равенство: ${isEqual}`);

                             if (!isEqual) return false;
                             else continue; // переходим к следующему сегменту
                         } catch (innerErr) {
                             console.error("❌ Ошибка при сравнении без оператора:", innerErr);
                             return false;
                         }
                     }
                 
                 const userParts = splitInequality(userSegment);
                 const actionParts = splitInequality(actionSegment);

                 const userSigns = extractInequalityOperators(userSegment);
                 const actionSigns = extractInequalityOperators(actionSegment);

                 if (userParts.length !== actionParts.length) {
                     console.log("❌ Разное количество частей после split:", userParts, actionParts);
                     return false;
                 }

                 if (userSigns.length !== actionSigns.length) {
                     console.log("❌ Разное количество операторов:", userSigns, actionSigns);
                     return false;
                 }

                 
                 // Шаг 3: Вычисление значений каждой части
                 const resultsUser = userParts.map(p => roundToDecimalPlace(evaluateExpression(p), 3));
                 const resultsAction = actionParts.map(p => roundToDecimalPlace(evaluateExpression(p), 3));
                 
                 for (let i = 0; i < resultsUser.length; i++) {
                     const userVal = resultsUser[i];
                     const correctVal = resultsAction[i];

                     const match =
                             (userVal === correctVal) ||
                             (Number.isNaN(userVal) && Number.isNaN(correctVal)) ||
                             (Math.abs(userVal) === Infinity && Math.abs(correctVal) === Infinity);

                     console.log(`📘 Часть ${i + 1} пользователя: ${userParts[i]} → ${userVal}`);
                     console.log(`📗 Часть ${i + 1} эталона: ${actionParts[i]} → ${correctVal}`);
                     console.log(`📏 Сравнение: ${userVal} === ${correctVal} → ${match}`);

                     if (!match) {
                         console.log("❌ Значения не совпадают.");
                         return false;
                     }

                     if (userSigns[i] !== actionSigns[i]) {
                         console.log(`❌ Несовпадающие знаки между частями: ${userSigns[i]} ≠ ${actionSigns[i]}`);
                         return false;
                     }
                 }

                 }
                 
                 // Все сегменты прошли проверку
                 return true;
                 
                 } catch (e) {
                 console.error("❌ Ошибка при сравнении сегментов с переменными:", e);
                 return false;
                 }
                 }
                 
                            // Если переменных нет — сравнение без замены
                            try {
                                const userInequality = inequalitySigns.find(sign => userInput.includes(sign));
                                const actionInequality = inequalitySigns.find(sign => actionData.includes(sign));
                                // 🔍 Случай: эталон содержит уравнение (a=b), а пользователь дал только результат
                                if (!userInput.includes('=') && actionData.includes('=')) {
                                    const [lhs, rhs] = actionData.split('=');
                                    const lhsVal = roundToDecimalPlace(evaluateExpression(lhs), 3);
                                    const rhsVal = roundToDecimalPlace(evaluateExpression(rhs), 3);
                                    const userVal = roundToDecimalPlace(evaluateExpression(userInput), 3);

                                    const isValid = lhsVal === rhsVal && userVal === lhsVal;

                                    console.log("📘 Проверка обратного случая: результат вместо уравнения");
                                    console.log(`📘 Эталон левое: ${lhs} → ${lhsVal}`);
                                    console.log(`📘 Эталон правое: ${rhs} → ${rhsVal}`);
                                    console.log(`📗 Ввод пользователя: ${userInput} → ${userVal}`);
                                    console.log(`📏 Сравнение: ${lhsVal} == ${rhsVal} && == ${userVal} → ${isValid}`);

                                    return isValid;
                                }


                                // 🔍 Случай: пользователь ввёл уравнение, а эталон — выражение (например: "2+2=4" vs "2+2")
                                if (!actionInequality && userInput.includes('=') && !actionData.includes('=')) {
                                    const [lhs, rhs] = userInput.split('=');

                                    const lhsVal = roundToDecimalPlace(evaluateExpression(lhs), 3);
                                    const rhsVal = roundToDecimalPlace(evaluateExpression(rhs), 3);
                                    const correctVal = roundToDecimalPlace(evaluateExpression(actionData), 3);

                                    const isUserCorrect = lhsVal === rhsVal && lhsVal === correctVal;

                                    console.log("📘 Проверка внутреннего равенства:");
                                    console.log(`📘 Левое: ${lhs} → ${lhsVal}`);
                                    console.log(`📘 Правое: ${rhs} → ${rhsVal}`);
                                    console.log(`📗 Эталонное выражение: ${actionData} → ${correctVal}`);
                                    console.log(`📏 Сравнение: ${lhsVal} == ${rhsVal} && == ${correctVal} → ${isUserCorrect}`);

                                    return isUserCorrect;
                                }

                                // 📏 Сравнение по неравенствам (если знак есть хотя бы в одном выражении)
                                if (userInequality || actionInequality) {
                                    const userParts = splitInequality(userInput);
                                    const actionParts = splitInequality(actionData);

                                    const userSigns = extractInequalityOperators(userInput);
                                    const actionSigns = extractInequalityOperators(actionData);

                                    const resultsUser = userParts.map(part => roundToDecimalPlace(evaluateExpression(part), 3));
                                    const resultsAction = actionParts.map(part => roundToDecimalPlace(evaluateExpression(part), 3));

                                    console.log("📏 Сравнение неравенств");
                                    console.log("🔹 Части пользователя:", userParts, "→", resultsUser);
                                    console.log("🔸 Части эталона:", actionParts, "→", resultsAction);
                                    console.log("🔹 Операторы пользователя:", userSigns);
                                    console.log("🔸 Операторы эталона:", actionSigns);

                                    if (resultsUser.length !== resultsAction.length || userSigns.length !== actionSigns.length) {
                                        console.log("❌ Несовпадение количества частей или операторов");
                                        return false;
                                    }

                                    for (let i = 0; i < resultsUser.length; i++) {
                                        const valUser = resultsUser[i];
                                        const valCorrect = resultsAction[i];
                                        const match = valUser === valCorrect;

                                        console.log(`📘 Часть ${i + 1}: ${valUser} === ${valCorrect} → ${match}`);
                                        if (!match) return false;
                                    }

                                    for (let j = 0; j < userSigns.length; j++) {
                                        if (userSigns[j] !== actionSigns[j]) {
                                            console.log(`❌ Оператор ${j + 1} не совпадает: ${userSigns[j]} ≠ ${actionSigns[j]}`);
                                            return false;
                                        }
                                    }

                                    return true;
                                }


                                // 🔁 Сравнение по равенству слева и справа, если знак '=' есть в обоих выражениях
                                const [userInputLeft, userInputRight] = userInput.split('=');
                                const [actionDataLeft, actionDataRight] = actionData.split('=');

                                const leftValUser = evaluateExpression(userInputLeft);
                                const rightValUser = userInputRight ? evaluateExpression(userInputRight) : null;

                                const leftValCorrect = evaluateExpression(actionDataLeft);
                                const rightValCorrect = actionDataRight ? evaluateExpression(actionDataRight) : null;

                                console.log("📘 Левая часть пользователя:", userInputLeft, "→", leftValUser);
                                console.log("📘 Правая часть пользователя:", userInputRight, "→", rightValUser);
                                console.log("📗 Левая часть ответа:", actionDataLeft, "→", leftValCorrect);
                                console.log("📗 Правая часть ответа:", actionDataRight, "→", rightValCorrect);

                                const leftMatch = roundToDecimalPlace(leftValUser, 3) === roundToDecimalPlace(leftValCorrect, 3);

                                let rightMatch = true;
                                if (userInputRight && actionDataRight) {
                                    rightMatch = roundToDecimalPlace(rightValUser, 3) === roundToDecimalPlace(rightValCorrect, 3);
                                }

                                return leftMatch && rightMatch;

                            } catch (error) {
                                console.error("❌ Ошибка при вычислении/сравнении:", error);
                                return false;
                            }

                         }
                 function extractInequalityOperators(input) {
                     const regex = /(<=|>=|=|<|>)/g;
                     return input.match(regex) || [];
                 }

                 
                 function stripOuterParens(expr) {
                 if (expr.startsWith('(') && expr.endsWith(')')) {
                 return expr.substring(1, expr.length - 1);
                 }
                 return expr;
                 }
                 function replaceVariablesWithOne(expr) {
                 console.log("Исходное выражение: ", expr);
        
                 // 🔧 Добавляем умножение между переменной и pi/e (например: aπ → a * pi)
                 expr = expr.replace(/([xyabc])(?=pi\\b)/g, '$1*');  // xpi → x*pi
                 expr = expr.replace(/([xyabc])(?=e\\b)/g, '$1*');   // xe → x*e

                 // 🔧 Добавляем умножение между числом и переменной (например: 2a → 2*a)
                 expr = expr.replace(/(\\d)([xyabc])/g, '$1*$2');

                 // 🔧 Добавляем умножение между переменной и переменной (например: ax → a*x)
                 expr = expr.replace(/([xyabc])([xyabc])/g, '$1*$2');

                 // 🔧 Добавляем умножение между переменной и функцией (например: asin → a*sin)
                 expr = expr.replace(/([xyabc])(?=(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\b)/g, '$1*');

                 // 🔧 Добавляем умножение между переменной и числом (например: a2 → a*2)
                 expr = expr.replace(/([xyabc])(?=\\d)/g, '$1*');

                 
                 // Заменяем только отдельные переменные, избегая встроенных команд типа 'frac'
                 let replacedExpr = expr
                         .replace(/(?<=\\d)([xyabc])(?=[xyabc])/g, '(1)')              // цифра–буква–буква
                         .replace(/(?<=[xyabc])([xyabc])(?=[xyabc])/g, '(1)')         // буква–буква–буква
                         .replace(/(?<=[xyabc])([xyabc])(?=$|[^A-Za-z0-9_])/g, '(1)')  // буква–(конец строки или не-буква)
                         .replace(/\\b([xyabc])\\b/g, '(1)')                            // одиночный токен
                         .replace(/(?<=[nsit])([xyabc])(?![A-Za-z0-9_])/g,'(1)')
                 
                 
                 console.log("После замены переменных на 1: ", replacedExpr);
                 // Добавляем явное умножение между числом и функцией
                 replacedExpr = replacedExpr.replace(/(\\d)(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)/g, '$1*$2');
                 console.log("После добавления умножения между числом и функцией: ", replacedExpr);
                 
                 // Обработка степеней в тригонометрических функциях
                 replacedExpr = replacedExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\^\\{(\\d+)\\}\\((\\w)\\)/g, '$1($3)^($2)');
                 replacedExpr = replacedExpr.replace(/(sin|cos|tan|cot|arcsin|arccos|arctan|arccot)\\^\\{(\\d+)\\}(\\w)/g, '$1($3)^($2)');
                 console.log("После обработки степеней в тригонометрических функциях: ", replacedExpr);
                 
                 // Замена log_{a}(b) на log(b)/log(a)
                 replacedExpr = replacedExpr.replace(/log_\\{(\\d+)\\}\\(([^)]+)\\)/g, '(log($2) / log($1))');
                 console.log("После замены логарифмов по основанию: ", replacedExpr);
                 
                 // Добавляем умножение между числом и логарифмом
                 replacedExpr = replacedExpr.replace(/(\\d)\\s*\\((log\\([^)]+\\)\\s*\\/\\s*log\\([^)]+\\))\\)/g, '$1*$2');
                 console.log("После добавления умножения между числом и логарифмом: ", replacedExpr);
                 
                 return replacedExpr;
                 }
                 function roundToDecimalPlace(value, decimalPlaces) {
                 const factor = Math.pow(10, decimalPlaces);
                 return Math.round(value * factor) / factor;
                 }
                 
                 function hasVariables(expr) {
                 return /[xyabc]/.test(expr);
                 }
                 
                 
                 
                 function evaluateExpression(expr) {
                 try {
                     const node = math.parse(expr);
                     const code = node.compile();
                     return code.evaluate();
                 } catch (error) {
                     console.error("Ошибка при вычислении выражения: ", error);
                     throw error;
                 }
                 }
                 
                 function splitInequality(input) {
                     const operators = ['<=', '>=', '=', '<', '>'];
                     const allOperators = operators.join('|');
                     const regex = new RegExp(`(${allOperators})`);

                     const tokens = input.split(regex).map(s => s.trim()).filter(Boolean);

                     const parts = [];

                     for (let i = 0; i < tokens.length; i += 2) {
                         let part = tokens[i];
                         const originalPart = part;

                         // Удаление лишней открывающей скобки, если больше открывающих, чем закрывающих
                         if (part.startsWith('(') && (part.match(/\\(/g)?.length || 0) > (part.match(/\\)/g)?.length || 0)) {
                             part = part.slice(1);
                         }

                         // Удаление лишней закрывающей скобки, если больше закрывающих, чем открывающих
                         if (part.endsWith(')') && (part.match(/\\)/g)?.length || 0) > (part.match(/\\(/g)?.length || 0)) {
                             part = part.slice(0, -1);
                         }

                         parts.push(part);
                         console.log(`🔍 Часть ${i / 2 + 1}: до: "${originalPart}", после: "${part}"`);
                     }

                     return parts;
                 }

                 function processComparison() {
                 return compareMathInputWithData(userLatex, correctLatex);
                 }
                 
              </script>
           </head>
           <body></body>
        </html>
        """
    }
}

// MARK: - Расширение Notification.Name
extension Notification.Name {
    static let taskCompleted = Notification.Name("taskCompleted")
}
private func runAllTests() {
    print("🚀 Автоматический запуск тестов (всего: \(testCases.count))")
    for (index, test) in testCases.enumerated() {
        print("🔬 Тест \(index + 1):")
        print("👤 Пользовательский ввод: \(test.userLatex)")
        print("✅ Ожидаемый ответ: \(test.correctLatex)")

        let testWebView = HiddenCompareWebView(
            userAnswer: test.userLatex,
            correctAnswer: test.correctLatex
        ) { isCorrect in
            print(isCorrect ? "🎉 Результат: ✅ Прошло" : "❌ Результат: ❌ Не прошло")
            if isCorrect != test.expectedResult {
                print("⚠️ Несоответствие! Ждали \(test.expectedResult)")
            }
            print("----------------------------")
        }

        let hosting = UIHostingController(rootView: testWebView)
        UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: false) {
            // После показа
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                hosting.dismiss(animated: false) {
                    // ✅ Переход к следующему тесту только после завершения dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        runTest(at: index + 1)
                    }
                }
            }
        }
    }
}
private func runTest(at index: Int) {
    guard index < testCases.count else {
        print("✅ Все тесты завершены!")
        return
    }

    let test = testCases[index]
    print("🔬 Тест \(index + 1):")
    print("👤 Пользовательский ввод: \(test.userLatex)")
    print("✅ Ожидаемый ответ: \(test.correctLatex)")

    let testWebView = HiddenCompareWebView(
        userAnswer: test.userLatex,
        correctAnswer: test.correctLatex
    ) { isCorrect in
        print(isCorrect ? "🎉 Результат: ✅ Прошло" : "❌ Результат: ❌ Не прошло")
        if isCorrect != test.expectedResult {
            print("⚠️ Несоответствие! Ждали \(test.expectedResult)")
        }
        print("----------------------------")

        // ✅ Переходим к следующему тесту после завершения
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            runTest(at: index + 1)
        }
    }

    let hosting = UIHostingController(rootView: testWebView)
    UIApplication.shared.windows.first?.rootViewController?.present(hosting, animated: false) {
        // Закрываем после ~1 сек (или дольше для тяжёлых тестов)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hosting.dismiss(animated: false)
        }
    }
}


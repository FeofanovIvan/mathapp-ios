//
//  SettingsView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreData // ← обязательно!


struct SettingsView: View {
    var updateTitle: (String) -> Void
    
    @State private var name: String = "Загрузка..."
    @State private var email: String = "Загрузка..."
    //@State private var navigateToSubscriptionScreen = false

    @State private var examsTaken: Int = 0
    @State private var taskTaken: Int = 0
    @State private var bestScore: Int = 0
    @State private var bestScoreProfile: Int = 0
    @State private var bestScoreOGE: Int = 0


    @State private var totalTime: String = "0 мин."
    @State private var formulaAccuracy: Int = 0
    @State private var isSoundNotificationsExpanded = false
    @State private var isNotificationsEnabled = true
    @State private var isSoundEnabled = true
    @State private var isFAQExpanded = false
    @State private var isFeedbackExpanded = false
    @State private var isTermsExpanded = false
    @State private var isPrivacyExpanded = false
    @State private var isUpdatingContent = false
    @State private var showUpdateSuccess = false

    @StateObject private var profileVM = UserProfileViewModel()

        @AppStorage("selectedProfile") var selectedProfile: String = "База"

        private let localContext = PersistenceController.shared.localContainer.viewContext

        var body: some View {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.white, Color(red: 0.95, green: 0.98, blue: 1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ProfileStatsCard(
                            profileVM: profileVM,
                            examsTaken: examsTaken,
                            taskTaken: taskTaken,
                            bestScore: bestScore,
                            bestScoreProfile: bestScoreProfile,
                            bestScoreOGE: bestScoreOGE,
                            totalTime: totalTime,
                            formulaAccuracy: formulaAccuracy
                        )



                        Divider().padding(.horizontal)

                        DisclosureSettingsBlock(
                            icon: "bubble.left.fill",
                            title: "Обратная связь",
                            isExpanded: $isFeedbackExpanded,
                            content: {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Image(systemName: "link")
                                        Link("**feofanovamathtutor.com**", destination: URL(string: "https://feofanovamathtutor.com")!)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }

                                    HStack {
                                        Image(systemName: "message.fill")
                                        Link("**Чат-бот поддержки**", destination: URL(string: "https://t.me/your_support_bot")!)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }

                                    HStack {
                                        Image(systemName: "star.fill")
                                        Link("**Оцените нас в App Store**", destination: URL(string: "https://apps.apple.com/app/id1234567890")!)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }

                        )

                        // NavigationLink(destination: SubscriptionScreen(updateTitle: updateTitle)) {
                        //    SettingsBlock(icon: "crown.fill", title: "Управление подпиской")
                        // }



                        DisclosureSettingsBlock(
                            icon: "bell.fill",
                            title: "Звук и уведомления",
                            isExpanded: $isSoundNotificationsExpanded,
                            content: {
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle(isOn: $isNotificationsEnabled) {
                                        HStack {
                                            Image(systemName: "bell.fill")
                                            Text("Уведомления")
                                              
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                                    
                                    Toggle(isOn: $isSoundEnabled) {
                                        HStack {
                                            Image(systemName: "speaker.wave.2.fill")
                                            Text("Звук")
                                                
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        )

                        DisclosureSettingsBlock(
                            icon: "questionmark.circle.fill",
                            title: "FAQs",
                            isExpanded: $isFAQExpanded,
                            content: {
                                FAQBlock()
                            }
                        )

                        DisclosureSettingsBlock(
                            icon: "doc.text.fill",
                            title: "Условия использования",
                            isExpanded: $isTermsExpanded,
                            content: {
                                TermsOfUseBlock()
                            }
                        )

                        DisclosureSettingsBlock(
                            icon: "hand.raised.fill",
                            title: "Политика конфиденциальности",
                            isExpanded: $isPrivacyExpanded,
                            content: {
                                PrivacyPolicyBlock()
                            }
                        )

                        Button(action: {
                            isUpdatingContent = true

                            // EГЭ
                            DataImportService.downloadAndImportEGE(context: PersistenceController.shared.firebaseContext)

                                // ОГЭ — форс уже есть
                                DataImportService.downloadAndImportOGE(context: PersistenceController.shared.ogeContext)

                                // 🎮 Игра — теперь тоже форсим
                                DataUpdateScheduler.performGameForceUpdate()

                            // Простая задержка для индикатора
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                isUpdatingContent = false
                                showUpdateSuccess = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                    .frame(width: 30, height: 30)
                                    .background(Color.white)
                                    .cornerRadius(8)

                                Text(isUpdatingContent ? "Обновление..." : "Обновить контент")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                                Spacer()

                                if isUpdatingContent {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                        .alert(isPresented: $showUpdateSuccess) {
                            Alert(title: Text("Контент обновлён!"),
                                  message: Text("Все данные были успешно загружены."),
                                  dismissButton: .default(Text("Ок")))
                        }


                        SettingsBlock(icon: "arrowshape.turn.up.left.fill", title: "Выход")
                            .onTapGesture {
                                handleSignOut()
                            }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarHidden(true)
                   .onAppear {
                       profileVM.fetchUserProfile()
                       fetchLocalStats()
                   }
            // Новый способ перехода в iOS 16+
            // .navigationDestination(isPresented: $navigateToSubscriptionScreen) {
            //       SubscriptionScreen(updateTitle: { _ in })
            //     }
               }

    struct PrivacyPolicyBlock: View {
        @State private var expandedSection: Int? = nil

        let policies: [(title: String, body: String)] = [
            ("1. Общая информация",
             "MathUp уважает вашу конфиденциальность и защищает личные данные, предоставленные вами при использовании приложения."),

            ("2. Сбор данных",
             "Мы собираем только необходимую информацию — имя, email, ответы на задания и статистику использования. Эти данные помогают улучшать наш сервис."),

            ("3. Использование данных",
             "Собранные данные используются для анализа прогресса, персонализации и предоставления актуального контента."),

            ("4. Хранение и защита",
             "Ваши данные хранятся в Firebase и локально на вашем устройстве. Мы применяем технические меры защиты информации."),

            ("5. Раскрытие информации",
             "Мы не передаём персональные данные третьим лицам, за исключением случаев, предусмотренных законом."),

            ("6. Файлы cookie и аналитика",
             "Мы можем использовать аналитику Firebase и технические cookie для улучшения производительности и UX, без отслеживания личности."),

            ("7. Ваши права",
             "Вы имеете право запросить удаление или изменение ваших данных, написав нам через обратную связь."),

            ("8. Согласие",
             "Используя приложение, вы соглашаетесь с настоящей Политикой конфиденциальности."),

            ("9. Изменения политики",
             "Мы можем обновлять политику. Актуальная версия всегда будет доступна в разделе настроек приложения.")
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(policies.indices, id: \.self) { index in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == index },
                            set: { expandedSection = $0 ? index : nil }
                        ),
                        content: {
                            Text(policies[index].body)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        },
                        label: {
                            HStack {
                                Image(systemName: "hand.raised")
                                Text(policies[index].title)
                                    .font(.subheadline)
                                    .bold()
                            }
                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                        }
                    )
                    .padding(.horizontal, 8)
                }

                Divider().padding(.top, 12)

                HStack {
                    Image(systemName: "lock.shield")
                    Link("Связаться с нами", destination: URL(string: "https://feofanovamathtutor.com")!)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    struct TermsOfUseBlock: View {
        @State private var expandedSection: Int? = nil

        let terms: [(title: String, body: String)] = [
            ("1. Общие положения",
             "MathApp — это обучающее приложение для изучения и практики математики. Используя его, вы соглашаетесь с настоящими Условиями."),

            ("2. Регистрация и аккаунт",
             "Для доступа к функциям необходимо создать аккаунт. Вы обязуетесь предоставлять достоверные данные и хранить конфиденциальность своего пароля."),

            ("3. Использование контента",
             "Контент предназначен только для личного некоммерческого использования. Копирование и распространение без согласия запрещено."),

            ("4. Пользовательские данные",
             "Ваши ответы и статистика сохраняются локально и в облаке, используются для улучшения опыта. Мы не передаём данные третьим лицам."),

            ("5. Обновления и доступность",
             "Мы можем обновлять контент и функции без уведомления, а также временно ограничивать доступ к отдельным возможностям."),

            ("6. Ограничение ответственности",
             "MathApp не гарантирует абсолютную точность решений и успешную сдачу экзаменов. Использование — на ваш страх и риск."),

            ("7. Подписки и покупки",
             "Некоторые функции доступны по подписке. Условия регулируются через App Store и могут включать автоматическое продление."),

            ("8. Нарушения и блокировки",
             "Мы можем ограничить доступ при нарушении условий, попытках взлома или злоупотребления возможностями приложения."),

            ("9. Обратная связь",
             "Вы можете отправлять идеи через раздел «Обратная связь». Мы благодарны за предложения, но не обязуемся их реализовывать."),

            ("10. Изменения условий",
             "Условия могут обновляться. Продолжение использования означает согласие с последней версией.")
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(terms.indices, id: \.self) { index in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSection == index },
                            set: { expandedSection = $0 ? index : nil }
                        ),
                        content: {
                            Text(terms[index].body)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        },
                        label: {
                            HStack {
                                Image(systemName: "doc.text")
                                Text(terms[index].title)
                                    .font(.subheadline)
                                    .bold()
                            }
                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                        }
                    )
                    .padding(.horizontal, 8)
                }

                Divider().padding(.top, 12)

                HStack {
                    Image(systemName: "globe")
                    Link("Наш сайт", destination: URL(string: "https://feofanovamathtutor.com")!)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

       
    struct FAQBlock: View {
        @State private var expandedQuestion: Int? = nil

        let faqs: [(question: String, answer: String)] = [
            ("Как начать использовать приложение?",
             "После регистрации выберите профиль обучения — \"База\" или \"Профиль\". Вы получите доступ к заданиям, формулами и экзаменам, соответствующим выбранному уровню."),

            ("Что такое экзамен и как он работает?",
             "Экзамен — это подборка случайных задач по вашему профилю. Вы проходите задания по очереди, и после каждого можете получить результат. В конце показывается статистика и ваш итоговый балл."),

            ("Как пользоваться формульной клавиатурой?",
             "Наша клавиатура поддерживает математический синтаксис. Вводите выражения, используя кнопки с формулами. Всё, что вы вводите, отображается в виде LaTeX."),

            ("Что означают шаги решения?",
             "Каждая задача может состоять из нескольких шагов. Это помогает лучше понять, как решаются сложные примеры поэтапно."),

            ("Как рассчитывается результат экзамена?",
             "Мы сравниваем введённое вами выражение с правильным ответом, используя проверку через Math.js. Учитываются точность и структура."),

            ("Где посмотреть свою статистику?",
             "В разделе 'Настройки' — верхняя карточка показывает задания, формулы, экзамены и активное время."),

            ("Как включить или отключить звук и уведомления?",
             "В разделе 'Звук и уведомления' можно выбрать, какие функции включить с помощью переключателей."),

            ("Почему не отображаются формулы?",
             "Убедитесь, что у вас есть интернет. Формулы отображаются через MathJax/KaTeX. Перезапустите приложение, если нужно."),

            ("У меня остались вопросы, как связаться с поддержкой?",
             "Откройте 'Обратную связь' в настройках. Напишите нам через чат-бота или на сайте feofanovamathtutor.com.")
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(faqs.indices, id: \.self) { index in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedQuestion == index },
                            set: { expandedQuestion = $0 ? index : nil }
                        ),
                        content: {
                            Text(faqs[index].answer)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        },
                        label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text(faqs[index].question)
                                    .font(.subheadline)
                                    .bold()
                            }
                            .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                        }
                    )
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

        private func fetchLocalStats() {
            // Exams taken
            let examsFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ExamSessionEntity")
            examsFetch.predicate = NSPredicate(format: "isCompleted == YES")
            do {
                examsTaken = try localContext.count(for: examsFetch)
            } catch { print("Ошибка загрузки экзаменов") }

            // Task taken
            let tasksFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "UserStepProgress")
            tasksFetch.predicate = NSPredicate(format: "isCompleted == YES")
            do {
                taskTaken = try localContext.count(for: tasksFetch)
            } catch { print("Ошибка загрузки задач") }

            // Best score (База)
            let baseFetch = NSFetchRequest<NSManagedObject>(entityName: "ExamSessionEntity")
            baseFetch.predicate = NSPredicate(format: "profileType == %@", "База")
            do {
                let sessions = try localContext.fetch(baseFetch)
                bestScore = sessions.compactMap { $0.value(forKey: "correctAnswersCount") as? Int }.max() ?? 0
            } catch { print("Ошибка базы") }

            // Best score (Профиль)
            let profFetch = NSFetchRequest<NSManagedObject>(entityName: "ExamSessionEntity")
            profFetch.predicate = NSPredicate(format: "profileType == %@", "Профиль")
            do {
                let sessions = try localContext.fetch(profFetch)
                bestScoreProfile = sessions.compactMap { $0.value(forKey: "correctAnswersCount") as? Int }.max() ?? 0
            } catch { print("Ошибка профиля") }
            
            // Best score (ОГЭ)
            let ogeFetch = NSFetchRequest<NSManagedObject>(entityName: "ExamSessionEntity")
            // Я бы сразу добавил фильтр по завершённым, чтобы не учитывать незаконченные:
            ogeFetch.predicate = NSPredicate(format: "profileType == %@ AND isCompleted == YES", "ОГЭ")

            do {
                let sessionsOGE = try localContext.fetch(ogeFetch)
                bestScoreOGE = sessionsOGE
                    .compactMap { $0.value(forKey: "correctAnswersCount") as? Int }
                    .max() ?? 0
            } catch {
                print("Ошибка ОГЭ: \(error)")
            }


            // Total time
            let timeFetch = NSFetchRequest<NSManagedObject>(entityName: "AppUsageStats")
            do {
                let usage = try localContext.fetch(timeFetch)
                let totalSeconds = usage.compactMap { $0.value(forKey: "totalActiveSeconds") as? Int }.reduce(0, +)
                totalTime = formatTime(seconds: totalSeconds)
            } catch { print("Ошибка времени") }

            // Formula accuracy
            let statFetch = NSFetchRequest<NSManagedObject>(entityName: "FormulaStats")
            do {
                let stats = try localContext.fetch(statFetch)
                let correct = stats.compactMap { $0.value(forKey: "correctCount") as? Int }.reduce(0, +)
                let incorrect = stats.compactMap { $0.value(forKey: "incorrectCount") as? Int }.reduce(0, +)
                let total = correct + incorrect
                formulaAccuracy = total > 0 ? Int((Double(correct) / Double(total)) * 100.0) : 0
            } catch { print("Ошибка формул") }
        }

        private func formatTime(seconds: Int) -> String {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if hours > 0 {
                return "\(hours) ч. \(minutes) мин."
            } else {
                return "\(minutes) мин."
            }
        }

    private func handleSignOut() {
        do {
            try Auth.auth().signOut()
            print("🚪 Пользователь вышел из аккаунта")

            UserDefaults.standard.removeObject(forKey: "selectedProfile")
            NotificationCenter.default.post(name: .forceResetAppTimer, object: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let loginView = LoginView()
                    .environment(\.managedObjectContext, PersistenceController.shared.firebaseContext)
                    .environmentObject(AppTimerManager()) // новый экземпляр
                    .preferredColorScheme(.light) // 👈 добавь это.preferredColorScheme(.light) // 👈 добавь это
                window.rootViewController = UIHostingController(rootView: loginView)
                window.makeKeyAndVisible()
            }

        } catch {
            print("❌ Ошибка выхода: \(error.localizedDescription)")
        }
    }
}
struct ProfileStatsCard: View {
    @ObservedObject var profileVM: UserProfileViewModel

    var examsTaken: Int
    var taskTaken: Int
    var bestScore: Int
    var bestScoreProfile: Int
    var bestScoreOGE: Int
    var totalTime: String
    var formulaAccuracy: Int

    @State private var expandedSection: Int? = nil
    @State private var isEditVisible: Bool = false
    @State private var nameInput = ""
    @State private var emailInput = ""
    @State private var passwordInput = ""
    @State private var confirmPassword = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    let editSections: [(title: String, placeholder: String)] = [
        ("Сменить имя", "Введите новое имя"),
        ("Сменить почту", "Введите новую почту"),
        ("Сменить пароль", "Введите новый пароль\nПодтвердите новый пароль")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    isEditVisible.toggle()
                    if !isEditVisible {
                        expandedSection = nil
                    }
                }
            }) {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileVM.name)
                            .font(.title2)
                            .bold()

                        Text(profileVM.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.\(isEditVisible ? "up" : "right")")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                        .rotationEffect(.degrees(isEditVisible ? 180 : 0))
                        .animation(.easeInOut, value: isEditVisible)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Divider()

            // 🔽 Показываем блок редактирования только если isEditVisible
            if isEditVisible {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(editSections.indices, id: \.self) { index in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedSection == index },
                                set: { expandedSection = $0 ? index : nil }
                            ),
                            content: {
                                VStack(alignment: .leading, spacing: 8) {
                                    if index == 0 {
                                        TextField("Новое имя", text: $nameInput)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    } else if index == 1 {
                                        TextField("Новая почта", text: $emailInput)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .keyboardType(.emailAddress)
                                            .autocapitalization(.none)
                                    } else if index == 2 {
                                        SecureField("Новый пароль", text: $passwordInput)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        SecureField("Подтвердите пароль", text: $confirmPassword)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }

                                    Button("Сменить") {
                                        switch index {
                                        case 0:
                                            updateDisplayName(to: nameInput) { success in
                                                showAlert(success ? "Имя обновлено" : "Ошибка смены имени")
                                                if success { profileVM.fetchUserProfile() }
                                            }
                                        case 1:
                                            updateEmail(to: emailInput) { success in
                                                showAlert(success ? "Почта обновлена" : "Ошибка смены почты")
                                                if success { profileVM.fetchUserProfile() }
                                            }
                                        case 2:
                                            guard passwordInput == confirmPassword else {
                                                showAlert("Пароли не совпадают")
                                                return
                                            }
                                            updatePassword(to: passwordInput) { success in
                                                showAlert(success ? "Пароль обновлён" : "Ошибка смены пароля")
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .padding(.top, 6)
                            },
                            label: {
                                HStack {
                                    Image(systemName: index == 0 ? "person.fill" : index == 1 ? "envelope.fill" : "lock.fill")
                                    Text(editSections[index].title)
                                        .font(.subheadline)
                                        .bold()
                                }
                                .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                            }
                        )
                        .padding(.horizontal, 8)
                    }
                }

                Divider()
            }

            VStack(alignment: .leading, spacing: 12) {
                StatRow(label: "Всего времени", value: totalTime)
                StatRow(label: "Решено заданий", value: "\(taskTaken)")
                StatRow(label: "Правильных формул", value: "\(formulaAccuracy)%")
                StatRow(label: "Проведено экзаменов", value: "\(examsTaken)")
                
                
                Text("Лучший результат ОГЭ")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                    .bold()

                ProgressView(value: Float(bestScoreOGE) / 25) {   // 25 — по blocksRange 1...25
                    Text("\(bestScoreOGE) из 25")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                }
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                HStack {
                    Text("Оценка: \(gradeText(for: bestScoreOGE))")
                        .font(.footnote)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("🎯 \(feedbackText(for: bestScoreOGE))")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }


                // Прогресс по лучшему баллу
                Text("Лучший результат База")
                    .font(.subheadline)
                                       .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                                       .bold()

                ProgressView(value: Float(bestScore) / 21) {
                                    Text("\(bestScore) из 21")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.green)
                                }
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            

                HStack {
                       Text("Оценка: \(gradeText(for: bestScore))")
                           .font(.footnote)
                           .foregroundColor(.blue)
                       Spacer()
                       Text("🎯 \(feedbackText(for: bestScore))")
                           .font(.footnote)
                           .foregroundColor(.gray)
                   }
            }
            // Прогресс по лучшему баллу
            Text("Лучший результат Профиль")
                .font(.subheadline)
                .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                .bold()

            ProgressView(value: Float(bestScoreProfile) / 19) {
                                Text("\(bestScoreProfile) из 19")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        
            HStack {
                    Text("Оценка: \(gradeText(for: bestScoreProfile))")
                        .font(.footnote)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("🎯 \(feedbackText(for: bestScoreProfile))")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertMessage), dismissButton: .default(Text("Ок")))
            }

        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(radius: 5)
    }
    func showAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    private func calculateLevel(from exams: Int) -> Int {
        return (exams / 5) + 1
    }
}
private func gradeText(for score: Int) -> String {
    switch score {
    case 1..<5:
        return "2"
    case 5..<12:
        return "3"
    case 12..<17:
        return "4"
    case 17...21:
        return "5"
    default:
        return "–"
    }
}

private func feedbackText(for score: Int) -> String {
    switch score {
    case 0:
        return "Давай начнём!"
    case 1..<5:
        return "У тебя всё получится"
    case 5..<12:
        return "Надо поднажать"
    case 12..<17:
        return "Ты близок к цели"
    case 17...21:
        return "Так держать!"
    default:
        return ""
    }
}


struct StatRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.black)
                .bold()
        }
    }
}



struct SettingsBlock: View {
    var icon: String
    var title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                .frame(width: 30, height: 30) // Увеличенный размер иконок
                .background(Color.white)
                .cornerRadius(8)

            Text(title)
                .font(.headline)
                .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
        }
        .padding()
        .frame(maxWidth: .infinity) // Блоки на всю ширину экрана
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct DisclosureSettingsBlock<Content: View>: View {
    var icon: String
    var title: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                    .frame(width: 30, height: 30)
                    .background(Color.white)
                    .cornerRadius(8)

                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                Spacer()

                Image(systemName: "chevron.\(isExpanded ? "up" : "right")")
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut, value: isExpanded)
            }
            .padding()
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .padding(.horizontal, 12)
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.vertical, 4)
    }
}

func updatePassword(to newPassword: String, completion: @escaping (Bool) -> Void) {
    guard let user = Auth.auth().currentUser else {
        completion(false)
        return
    }

    user.updatePassword(to: newPassword) { error in
        if let error = error {
            print("❌ Ошибка смены пароля: \(error.localizedDescription)")
            completion(false)
        } else {
            print("✅ Пароль успешно обновлён")
            completion(true)
        }
    }
}
func updateEmail(to newEmail: String, completion: @escaping (Bool) -> Void) {
    guard let user = Auth.auth().currentUser else {
        print("❌ Пользователь не найден")
        completion(false)
        return
    }

    // ✅ Новый способ — отправка письма перед обновлением
    user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
        if let error = error {
            print("❌ Ошибка при отправке письма верификации: \(error.localizedDescription)")
            completion(false)
        } else {
            print("📨 Письмо для подтверждения почты отправлено")

            // Обновим Firestore, чтобы синхронизировать email после подтверждения
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).updateData(["email": newEmail]) { firestoreError in
                if let firestoreError = firestoreError {
                    print("❌ Ошибка обновления email в Firestore: \(firestoreError.localizedDescription)")
                } else {
                    print("✅ Email обновлён в Firestore (предварительно)")
                }
                completion(true)
            }
        }
    }
}

func updateDisplayName(to newName: String, completion: @escaping (Bool) -> Void) {
    guard let user = Auth.auth().currentUser else {
        completion(false)
        return
    }

    let db = Firestore.firestore()
    let userRef = db.collection("users").document(user.uid)

    userRef.updateData(["name": newName]) { error in
        if let error = error {
            print("❌ Ошибка обновления имени: \(error.localizedDescription)")
            completion(false)
        } else {
            print("✅ Имя успешно обновлено в Firestore")
            completion(true)
        }
    }
}
import Foundation
import FirebaseAuth
import FirebaseFirestore

class UserProfileViewModel: ObservableObject {
    @Published var name: String = "Загрузка..."
    @Published var email: String = "Загрузка..."

    func fetchUserProfile() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("❌ Пользователь не авторизован")
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        userRef.getDocument { document, error in
            if let error = error {
                print("❌ Ошибка запроса профиля: \(error.localizedDescription)")
                return
            }

            guard let document = document, document.exists else {
                print("⚠️ Документ профиля не найден")
                return
            }

            let data = document.data()
            DispatchQueue.main.async {
                self.name = data?["name"] as? String ?? "Имя не указано"
                self.email = data?["email"] as? String ?? "Почта не указана"
                print("✅ Профиль загружен: \(self.name), \(self.email)")
            }
        }
    }
}



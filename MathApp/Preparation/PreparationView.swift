//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//
import SwiftUI
import CoreData

struct PreparationView: View {
    @Environment(\.presentationMode) var presentationMode
    var updateTitle: (String) -> Void

    @AppStorage("selectedProfile") private var selectedProfile: String = "База"

    private var numberOfTasks: Int {
        switch selectedProfile {
        case "Профиль": return 19
        case "ОГЭ":     return 25
        default:        return 21 // База ЕГЭ
        }
    }

    private func actualBlockID(for index: Int) -> Int {
        // Профильные блоки начинаются с 22
        selectedProfile == "Профиль" ? (index + 21) : index
    }

    private var headerTitle: String {
        selectedProfile == "ОГЭ" ? "Подготовка к ОГЭ" : "Подготовка к ЕГЭ"
    }

    private var rootTitleOnBack: String {
        selectedProfile == "ОГЭ" ? "ОГЭ математика" : "ЕГЭ математика"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    updateTitle(rootTitleOnBack)
                }) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.white)
                        .padding()
                }

                Spacer()

                Text(headerTitle)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
            .background(Color(red: 0.12, green: 0.18, blue: 0.35))

            // Основной контент
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(1...numberOfTasks, id: \.self) { index in
                        let blockID = actualBlockID(for: index)

                        PreparationBlock(
                            title: "Задание \(index)",
                            blockID: blockID,
                            selectedProfile: selectedProfile
                        )
                    }
                }
                .padding(.vertical)
                .background(.white)
            }
        }
        .onAppear {
            updateTitle(headerTitle)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Блок подготовки
struct PreparationBlock: View {
    let title: String
    let blockID: Int
    let selectedProfile: String

    @State private var progressValue: Double = 0.0

    // Контекст данных задач по треку (ЕГЭ/ОГЭ)
    private var dataContext: NSManagedObjectContext {
        selectedProfile == "ОГЭ"
            ? PersistenceController.shared.ogeContext
            : PersistenceController.shared.firebaseContext
    }

    var body: some View {
        NavigationLink(
            destination: TaskDetailView(
                taskName: title,
                taskIndex: blockID,
                selectedProfile: selectedProfile
            )
            .navigationBarHidden(true)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                ProgressView(value: progressValue, total: 1.0)
                    .tint(.green)

                HStack(spacing: 10) {
                    NavigationLink(
                        destination: FormulasListView(blockID: Int64(blockID))
                            .navigationBarHidden(true)
                    ) {
                        Text("формулы")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 5)
                            .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                            .cornerRadius(8)
                    }

                    NavigationLink(
                        destination: ReferenceDetailView(
                            blockID: Int64(blockID),
                            selectedProfile: selectedProfile
                        )
                        .navigationBarHidden(true)
                    ) {
                        Text("справочник")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 5)
                            .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                            .cornerRadius(8)
                    }

                    NavigationLink(
                        destination: VideoPlayerView(videoUrl: getVideoUrl(for: blockID, profile: selectedProfile))
                            .navigationBarHidden(true)
                    ) {
                        Text("видео")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 5)
                            .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 5)
            .padding(.horizontal)
            .onAppear { loadProgress() }
        }
    }

    // Прогресс по шагам блока
    private func loadProgress() {
        // читаем сами задания из EGE/OGE, а прогресс — из локальной БД
        let localContext = PersistenceController.shared.localContext

        let blockRequest: NSFetchRequest<QuestionBlockEntity> = QuestionBlockEntity.fetchRequest()
        blockRequest.predicate = NSPredicate(format: "blockID == %d", Int64(blockID))
        blockRequest.fetchLimit = 1

        do {
            if let block = try dataContext.fetch(blockRequest).first,
               let orderedTasks = block.tasks {
                let allTasks = orderedTasks.compactMap { $0 as? TaskEntity }
                let allTaskIDs = allTasks.map { $0.taskID }

                let progressRequest: NSFetchRequest<UserStepProgress> = UserStepProgress.fetchRequest()
                progressRequest.predicate = NSPredicate(format: "taskID IN %@ AND isCompleted == YES", allTaskIDs)

                let completed = try localContext.count(for: progressRequest)
                let total = allTasks.count

                progressValue = total > 0 ? Double(completed) / Double(total) : 0.0
            } else {
                progressValue = 0.0
            }
        } catch {
            print("❌ Ошибка загрузки прогресса блока \(blockID): \(error.localizedDescription)")
            progressValue = 0.0
        }
    }
}

// MARK: - Видео-ссылка из БД
private func getVideoUrl(for blockID: Int, profile: String) -> String {
    let ctx = (profile == "ОГЭ")
        ? PersistenceController.shared.ogeContext
        : PersistenceController.shared.firebaseContext

    let request: NSFetchRequest<QuestionBlockEntity> = QuestionBlockEntity.fetchRequest()
    request.predicate = NSPredicate(format: "blockID == %d", Int64(blockID))
    request.fetchLimit = 1

    do {
        if let block = try ctx.fetch(request).first {
            return block.videoLink ?? ""
        }
    } catch {
        print("❌ Ошибка выборки videoLink для блока \(blockID): \(error.localizedDescription)")
    }
    return ""
}

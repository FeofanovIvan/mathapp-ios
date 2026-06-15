//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI
import CoreData

struct VideoAnalysisView: View {
    @Environment(\.presentationMode) var presentationMode
    var updateTitle: (String) -> Void

    @AppStorage("selectedProfile") private var selectedProfile: String = "База"

    // Выбор нужного хранилища
    private var dataContext: NSManagedObjectContext {
        selectedProfile == "ОГЭ"
        ? PersistenceController.shared.ogeContext
        : PersistenceController.shared.firebaseContext
    }

    // Кол-во заданий по треку
    private var numberOfTasks: Int {
        switch selectedProfile {
        case "Профиль": return 19
        case "ОГЭ":     return 25
        default:        return 21 // База
        }
    }

    // Смещение блоков для профиля ЕГЭ
    private func actualBlockID(for index: Int) -> Int64 {
        if selectedProfile == "Профиль" {
            // Профильные задания начинаются с блока 22
            return Int64(index + 21)
        } else {
            // База ЕГЭ и ОГЭ начинаются с 1
            return Int64(index)
        }
    }

    // init оставляем — он у тебя уже есть
    init(updateTitle: @escaping (String) -> Void) {
        self.updateTitle = updateTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        // корректный заголовок при возврате
                        updateTitle(selectedProfile == "ОГЭ" ? "ОГЭ математика" : "ЕГЭ математика")
                    }) {
                        Image(systemName: "arrow.backward")
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }

                Text("Видеоразбор")
                    .font(.headline)
                    .foregroundColor(.white)

                // балансируем правую часть, чтобы заголовок был по центру
                HStack { Spacer() }.frame(width: 60)
            }
            .padding()
            .background(Color(red: 0.12, green: 0.18, blue: 0.35))

            // Список заданий
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(1...numberOfTasks, id: \.self) { index in
                        let blockID = actualBlockID(for: index)
                        NavigationLink(
                            destination: VideoPlayerView(videoUrl: getVideoUrl(forBlockID: blockID))
                        ) {
                            VideoBlock(title: "Задание \(index)")
                        }
                    }
                }
                .padding(.vertical)
                .background(.white)
            }
        }
        .onAppear { updateTitle("Видеоразбор") }
        .navigationBarHidden(true)
    }

    // MARK: - Получение ссылки из Core Data
    private func getVideoUrl(forBlockID blockID: Int64) -> String {
        let request: NSFetchRequest<QuestionBlockEntity> = QuestionBlockEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "blockID == %d", blockID)

        do {
            if let block = try dataContext.fetch(request).first {
                // videoLink хранится у блока (импорт уже это делает)
                return block.videoLink ?? ""
            } else {
                print("⚠️ Блок с ID \(blockID) не найден в \(selectedProfile)")
                return ""
            }
        } catch {
            print("❌ Ошибка выборки блока \(blockID): \(error.localizedDescription)")
            return ""
        }
    }
}

struct VideoBlock: View {
    let title: String

    var body: some View {
        HStack {
            Image(systemName: "play.rectangle.fill")
                .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                .frame(width: 40, height: 40)
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
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}




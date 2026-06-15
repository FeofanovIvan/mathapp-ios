import Foundation
import CoreData

// MARK: - Codable модели

struct ExportedBlock: Codable {
    let blockID: Int
    let name: String
    let videoLink: String?
    let referenceMaterial: String?
    let tasks: [ExportedTask]
    let formulas: [ExportedFormula]
}

struct ExportedTask: Codable {
    let taskID: Int
    let taskText: String
    let drawingLink: String?
    let answer: String
    let hint: String?
    let given: String?
    let steps: [ExportedStep]

    enum CodingKeys: String, CodingKey {
        case taskID, drawingLink, answer, hint, given, steps
        case taskText = "description" // ключ в JSON
    }
}

struct ExportedStep: Codable {
    let stepID: Int
    let solutionVariant: String
    let stepText: String
    let stepAction: String?

    enum CodingKeys: String, CodingKey {
        case stepID
        case solutionVariant
        case stepText = "stepDescription" // 🔥 вот так правильно
        case stepAction
    }
}


struct ExportedFormula: Codable {
    let formulaID: Int
    let name: String
    let formula: String
}

class DataSyncManager {
    static func importFromJSON(url: URL, context: NSManagedObjectContext) {
        do {
            let data = try Data(contentsOf: url)
            print("📦 Размер JSON-файла: \(data.count) байт")

            let decoder = JSONDecoder()
            let blocks = try decoder.decode([ExportedBlock].self, from: data)
            print("🔍 Успешно декодировано блоков: \(blocks.count)")

            // Очистка старых данных
            try clearOldData(in: context)

            for (index, block) in blocks.enumerated() {
                let blockEntity = QuestionBlockEntity(context: context)
                blockEntity.blockID = Int64(block.blockID)
                blockEntity.name = block.name
                blockEntity.videoLink = block.videoLink
                blockEntity.referenceMaterial = block.referenceMaterial

                for task in block.tasks {
                    let taskEntity = TaskEntity(context: context)
                    taskEntity.taskID = Int64(task.taskID)
                    taskEntity.taskText = task.taskText
                    taskEntity.drawingLink = task.drawingLink
                    taskEntity.answer = task.answer
                    taskEntity.hint = task.hint
                    taskEntity.given = task.given
                    taskEntity.block = blockEntity

                    for step in task.steps {
                        let stepEntity = StepEntity(context: context)
                        stepEntity.stepID = Int64(step.stepID)
                        stepEntity.solutionVariant = step.solutionVariant
                        stepEntity.stepText = step.stepText
                        stepEntity.stepAction = step.stepAction
                        stepEntity.task = taskEntity
                    }
                }

                for formula in block.formulas {
                    let formulaEntity = FormulaEntity(context: context)
                    formulaEntity.formulaID = Int64(formula.formulaID)
                    formulaEntity.name = formula.name
                    formulaEntity.formula = formula.formula
                    formulaEntity.block = blockEntity
                }

                print("✅ Импортирован блок \(index + 1): \(block.name)")
            }

            try context.save()
            print("🎉 Импорт завершён и данные сохранены в Core Data")
        } catch {
            print("❌ Ошибка при импорте JSON")
            print("📛 \(error.localizedDescription)")
            let nsError = error as NSError
            print("📂 Domain: \(nsError.domain), Code: \(nsError.code)")
            print("📋 Info: \(nsError.userInfo)")
        }
    }

    private static func clearOldData(in context: NSManagedObjectContext) throws {
            guard let model = context.persistentStoreCoordinator?.managedObjectModel else {
                print("⚠️ Модель не найдена у переданного контекста"); return
            }

            func hasEntity(_ name: String) -> Bool {
                model.entitiesByName[name] != nil
            }

            func wipe(_ entityName: String) throws {
                guard hasEntity(entityName) else {
                    print("⏭ Пропуск очистки: сущность \(entityName) отсутствует в этой модели")
                    return
                }
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let req = NSBatchDeleteRequest(fetchRequest: fr)
                try context.execute(req)
            }

            // Удаляем в порядке зависимостей
            try wipe("StepEntity")
            try wipe("TaskEntity")
            try wipe("QuestionBlockEntity")
        }
}

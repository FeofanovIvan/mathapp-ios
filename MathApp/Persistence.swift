//
//  Persistence.swift
//  MathApp
//
//  Created by Ivan Feofanov on 02/01/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    private(set) var firebaseContainer: NSPersistentContainer   // EGE
    private(set) var ogeContainer: NSPersistentContainer        // OGE (второй store на той же модели)
    private(set) var localContainer: NSPersistentContainer      // Локальные сущности (MathApp)

    @MainActor
    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    init(inMemory: Bool = false) {
        // 1) ЯВНО грузим модель ОДИН РАЗ и используем один и тот же объект для обоих контейнеров
        guard let modelURL = Bundle.main.url(forResource: "AppDataModel", withExtension: "momd"),
              let sharedModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("❌ Не удалось загрузить AppDataModel.momd")
        }

        firebaseContainer = NSPersistentContainer(name: "AppDataModel", managedObjectModel: sharedModel)
        ogeContainer      = NSPersistentContainer(name: "AppDataModel", managedObjectModel: sharedModel)

        // Отдельная модель для прочих локальных сущностей
        localContainer    = NSPersistentContainer(name: "MathApp")

        if inMemory {
            firebaseContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            ogeContainer.persistentStoreDescriptions.first!.url      = URL(fileURLWithPath: "/dev/null")
            localContainer.persistentStoreDescriptions.first!.url    = URL(fileURLWithPath: "/dev/null")
        } else {
            // 2) Разносим файлы SQLite (иначе они затрут друг друга)
            if let desc = ogeContainer.persistentStoreDescriptions.first {
                let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                desc.url = base.appendingPathComponent("AppDataModel_OGE.sqlite")
            }
            // firebaseContainer и localContainer оставляем с дефолтными путями (или тоже можно задать явно)
        }

        // 3) Загружаем сторы
        firebaseContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error (EGE) \(error), \(error.userInfo)")
            }
        }
        ogeContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error (OGE) \(error), \(error.userInfo)")
            }
        }
        localContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error (Local) \(error), \(error.userInfo)")
            }
        }

        // 4) Авто-мердж
        firebaseContainer.viewContext.automaticallyMergesChangesFromParent = true
        ogeContainer.viewContext.automaticallyMergesChangesFromParent      = true
        localContainer.viewContext.automaticallyMergesChangesFromParent    = true
    }

    // Контексты
    var firebaseContext: NSManagedObjectContext { firebaseContainer.viewContext } // EGE
    var ogeContext:      NSManagedObjectContext { ogeContainer.viewContext }      // OGE
    var localContext:    NSManagedObjectContext { localContainer.viewContext }    // Local
}

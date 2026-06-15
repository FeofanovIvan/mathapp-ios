//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 01/04/25.
//

import Foundation
import CoreData

class DataImportService {

    // MARK: - EGE (основная БД)
    /// Сохранённый метод (обратная совместимость)
    static func downloadAndImport(context: NSManagedObjectContext) {
        downloadAndImportEGE(context: context)
    }

    /// Явный метод для EGE
    static func downloadAndImportEGE(context: NSManagedObjectContext) {
        JSONDownloader.shared.downloadJSON { result in
            switch result {
            case .success(let url):
                DataSyncManager.importFromJSON(url: url, context: context)
                print("🎉 [EGE] Импорт завершён после загрузки")
                NotificationCenter.default.post(name: .egeImportFinished, object: nil)
            case .failure(let error):
                print("❌ [EGE] Ошибка при загрузке JSON: \(error.localizedDescription)")
                NotificationCenter.default.post(name: .egeImportFailed, object: error)
            }
        }
    }

    // MARK: - OGE (вторая БД)
    /// Новый метод для второй БД (OGE)
    static func downloadAndImportOGE(context: NSManagedObjectContext) {
        JSONDownloader.shared.downloadOGEJSON { result in
            switch result {
            case .success(let url):
                DataSyncManager.importFromJSON(url: url, context: context)
                print("🎉 [OGE] Импорт завершён после загрузки")
                NotificationCenter.default.post(name: .ogeImportFinished, object: nil)
            case .failure(let error):
                print("❌ [OGE] Ошибка при загрузке JSON: \(error.localizedDescription)")
                NotificationCenter.default.post(name: .ogeImportFailed, object: error)
            }
        }
    }
}
import Foundation
import CoreData

extension Notification.Name {
    static let egeImportFinished  = Notification.Name("egeImportFinished")
    static let ogeImportFinished  = Notification.Name("ogeImportFinished")
    static let egeImportFailed    = Notification.Name("egeImportFailed")
    static let ogeImportFailed    = Notification.Name("ogeImportFailed")
}

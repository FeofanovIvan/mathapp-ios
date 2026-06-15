//
//  DataUpdateScheduler.swift
//  MathApp
//
//  Created by Ivan Feofanov on 01/04/25.
//
import Foundation
import CoreData
import FirebaseFirestore

final class DataUpdateScheduler {

    // MARK: - UserDefaults keys
    private enum VersionKey {
        static let ege  = "version_ege"
        static let oge  = "version_oge"
        static let game = "version_game"
    }

    // MARK: - Firestore paths
    private enum FSPath {
        static let collection = "sync_metadata"
        static let egeDoc     = "MathUpDatabase"     // поле "version" (number)
        static let ogeDoc     = "MathUpOgeDatabase"  // поле "version" (number)
        static let gameDoc    = "GameDatabase"       // поле "version" (number)
        static let versionKey = "version"
    }

    // защита от параллельных запусков
    private static var isUpdatingEGE  = false
    private static var isUpdatingOGE  = false
    private static var isUpdatingGAME = false

    // MARK: - EGE

    static func performEGEUpdateIfNeeded(context: NSManagedObjectContext) {
        guard !isUpdatingEGE else { print("⏳ [EGE] Обновление уже выполняется — пропуск"); return }
        isUpdatingEGE = true

        fetchRemoteVersion(doc: FSPath.egeDoc) { result in
            defer { isUpdatingEGE = false }
            switch result {
            case .failure(let err):
                print("⚠️ [EGE] Не удалось получить версию из Firestore: \(err.localizedDescription)")
            case .success(let remote):
                let local = UserDefaults.standard.integer(forKey: VersionKey.ege)
                print("🧭 [EGE] Версии: local=\(local), remote=\(remote)")
                guard remote > local else {
                    print("✔️ [EGE] Локальные данные актуальны — обновление не требуется")
                    return
                }
                print("⬆️ [EGE] Новая версия (\(remote) > \(local)) → запускаем обновление")
                DataImportService.downloadAndImportEGE(context: context)
                UserDefaults.standard.set(remote, forKey: VersionKey.ege)
                print("✅ [EGE] Установлена version_ege=\(remote)")
            }
        }
    }
    static func performGameForceUpdate() {
            MathGameUpdateService.forceRefreshFromFirebase()
        }
    // MARK: - OGE

    static func performOGEUpdateIfNeeded(context: NSManagedObjectContext) {
        guard !isUpdatingOGE else { print("⏳ [OGE] Обновление уже выполняется — пропуск"); return }
        isUpdatingOGE = true

        fetchRemoteVersion(doc: FSPath.ogeDoc) { result in
            defer { isUpdatingOGE = false }
            switch result {
            case .failure(let err):
                print("⚠️ [OGE] Не удалось получить версию из Firestore: \(err.localizedDescription)")
            case .success(let remote):
                let local = UserDefaults.standard.integer(forKey: VersionKey.oge)
                print("🧭 [OGE] Версии: local=\(local), remote=\(remote)")
                guard remote > local else {
                    print("✔️ [OGE] Локальные данные актуальны — обновление не требуется")
                    return
                }
                print("⬆️ [OGE] Новая версия (\(remote) > \(local)) → запускаем обновление")
                DataImportService.downloadAndImportOGE(context: context)
                UserDefaults.standard.set(remote, forKey: VersionKey.oge)
                print("✅ [OGE] Установлена version_oge=\(remote)")
            }
        }
    }

    // MARK: - GAME

    static func performGameUpdateIfNeeded() {
        guard !isUpdatingGAME else { print("⏳ [GAME] Обновление уже выполняется — пропуск"); return }
        isUpdatingGAME = true

        fetchRemoteVersion(doc: FSPath.gameDoc) { result in
            defer { isUpdatingGAME = false }
            switch result {
            case .failure(let err):
                print("⚠️ [GAME] Не удалось получить версию из Firestore: \(err.localizedDescription)")
            case .success(let remote):
                let local = UserDefaults.standard.integer(forKey: VersionKey.game)
                print("🧭 [GAME] Версии: local=\(local), remote=\(remote)")
                guard remote > local else {
                    print("✔️ [GAME] Локальные данные актуальны — обновление не требуется")
                    return
                }
                print("⬆️ [GAME] Новая версия (\(remote) > \(local)) → запускаем обновление")
                MathGameUpdateService.syncGameCharacters()   // существующий код обновления игры
                UserDefaults.standard.set(remote, forKey: VersionKey.game)
                print("✅ [GAME] Установлена version_game=\(remote)")
            }
        }
    }

    // MARK: - Firestore helper

    private static func fetchRemoteVersion(doc: String, completion: @escaping (Result<Int, Error>) -> Void) {
        Firestore.firestore()
            .collection(FSPath.collection)
            .document(doc)
            .getDocument { snap, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let ver = snap?.data()?[FSPath.versionKey] as? Int else {
                    let err = NSError(domain: "DataUpdateScheduler",
                                      code: -404,
                                      userInfo: [NSLocalizedDescriptionKey: "version not found in \(doc)"])
                    completion(.failure(err))
                    return
                }
                completion(.success(ver))
            }
    }
}

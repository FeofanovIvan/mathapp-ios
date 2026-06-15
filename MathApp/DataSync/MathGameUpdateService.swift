//
//  MathGameUpdateService.swift
//  MathApp
//
//  Created by Ivan Feofanov on 10/04/25.
//

import Foundation
import CoreData
import FirebaseStorage
import FirebaseFirestore
import UIKit

struct MathGameUpdateService {

    // MARK: - Version keys & Firestore doc mapping
    private enum Defaults {
        static let versionGame = "version_game"
    }

    /// Firestore: коллекция `sync_metadata`, документ для игры — `GameDatabase`, поле `version` (Int)
    private enum FirestorePath {
        static let collection = "sync_metadata"
        static let gameDoc    = "GameDatabase"
        static let versionKey = "version"
    }
    static func forceRefreshFromFirebase() {
        // 1) Узнаём актуальную версию в Firestore
        fetchRemoteVersion { versionResult in
            switch versionResult {
            case .failure(let err):
                print("⚠️ [GAME] Force: не удалось получить версию из Firestore: \(err.localizedDescription)")
                // даже без версии всё равно качаем и импортируем, но версию не обновляем
                downloadJSONFromFirebase { jsonResult in
                    switch jsonResult {
                    case .failure(let e):
                        print("❌ [GAME] Force: ошибка загрузки JSON из Firebase: \(e.localizedDescription)")
                        NotificationCenter.default.post(name: .gameImportFailed, object: e)
                    case .success(let json):
                        importCharacters(json)
                        // версия не меняется, т.к. не знаем remote
                        NotificationCenter.default.post(name: .gameImportFinished, object: nil)
                    }
                }
            case .success(let remoteVersion):
                // 2) Качаем JSON независимо от локального состояния
                downloadJSONFromFirebase { jsonResult in
                    switch jsonResult {
                    case .failure(let e):
                        print("❌ [GAME] Force: ошибка загрузки JSON из Firebase: \(e.localizedDescription)")
                        NotificationCenter.default.post(name: .gameImportFailed, object: e)
                    case .success(let json):
                        importCharacters(json)
                        // 3) Ставим удалённую версию в локальное хранилище
                        UserDefaults.standard.set(remoteVersion, forKey: "version_game")
                        print("✅ [GAME] Force: импорт завершён, version_game=\(remoteVersion)")
                        NotificationCenter.default.post(name: .gameImportFinished, object: nil)
                    }
                }
            }
        }
    }

    // MARK: - Public API

    /// Главная точка синхронизации персонажей игры.
    static func syncGameCharacters() {
        ensureLocalSeedIfMissing { usedSeed in
            if usedSeed {
                // Уже импортировали из seed внутри ensureLocalSeedIfMissing
                return
            }
            // Локальный файл существует → сверяемся с Firestore по версии
            fetchRemoteVersion { remoteResult in
                switch remoteResult {
                case .failure(let err):
                    print("⚠️ [GameSync] Не удалось получить версию из Firestore: \(err.localizedDescription). Оставляем локальные данные как есть.")
                case .success(let remoteVersion):
                    let localVersion = UserDefaults.standard.integer(forKey: Defaults.versionGame) // 0, если не было
                    print("🧭 [GameSync] Версии: local=\(localVersion), remote=\(remoteVersion)")
                    if remoteVersion > localVersion {
                        print("⬆️ [GameSync] Доступна новая версия (\(remoteVersion) > \(localVersion)) — обновляем из Firebase Storage")
                        downloadJSONFromFirebase { result in
                            switch result {
                            case .failure(let e):
                                print("❌ [GameSync] Ошибка загрузки JSON из Firebase: \(e.localizedDescription)")
                            case .success(let json):
                                importCharacters(json)
                                UserDefaults.standard.set(remoteVersion, forKey: Defaults.versionGame)
                                print("✅ [GameSync] Обновление завершено. Установлена version_game=\(remoteVersion)")
                            }
                        }
                    } else {
                        print("⏳ [GameSync] Локальные данные актуальны (remote ≤ local), загрузка не требуется.")
                    }
                }
            }
        }
    }

    // MARK: - Seed on first run

    /// Если JSON ещё нет в Documents — копируем seed из бандла, ставим version_game=1 и импортируем.
    /// Возвращает через completion: true, если использован seed (и всё сделано), иначе false.
    private static func ensureLocalSeedIfMissing(completion: @escaping (Bool) -> Void) {
        let fileURL = localFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("📦 [GameSync] Локальный JSON найден: \(fileURL.lastPathComponent) @ \(fileURL.path)")
            completion(false)
            return
        }

        guard let seedURL = Bundle.main.url(forResource: "characters_export", withExtension: "json") else {
            print("⚠️ [GameSync] Seed characters_export.json в бандле не найден — будем полагаться на Firebase.")
            completion(false)
            return
        }

        do {
            try FileManager.default.copyItem(at: seedURL, to: fileURL)
            print("🌱 [GameSync] [source=bundle-seed] Скопирован seed в Documents: \(fileURL.lastPathComponent)")

            let data = try Data(contentsOf: fileURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ [GameSync] Не удалось распарсить seed JSON")
                completion(true)
                return
            }

            importCharacters(json)
            // Инициализируем версию = 1 при первом запуске с seed
            if UserDefaults.standard.object(forKey: Defaults.versionGame) == nil {
                UserDefaults.standard.set(1, forKey: Defaults.versionGame)
                print("🧭 [META] Установлен version_game = 1 (инициализация при seed)")
            }
            print("📊 [META] Текущая version_game=\(UserDefaults.standard.integer(forKey: Defaults.versionGame))")
            completion(true)
        } catch {
            print("❌ [GameSync] Ошибка копирования seed: \(error.localizedDescription)")
            completion(false)
        }
    }

    // MARK: - Firestore version

    private static func fetchRemoteVersion(completion: @escaping (Result<Int, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection(FirestorePath.collection)
            .document(FirestorePath.gameDoc)
            .getDocument { snap, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = snap?.data(),
                      let ver = data[FirestorePath.versionKey] as? Int else {
                    completion(.failure(NSError(domain: "GameSync", code: -3, userInfo: [NSLocalizedDescriptionKey: "version not found"])))
                    return
                }
                completion(.success(ver))
            }
    }

    // MARK: - Storage JSON

    private static func downloadJSONFromFirebase(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let storageRef = Storage.storage().reference().child("math_game/characters_export.json")
        print("☁️ [GameSync] [source=firebase] Скачиваем characters_export.json из Firebase Storage")
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "GameSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "empty data"])))
                return
            }
            do {
                // сохраняем на диск для офлайна
                try data.write(to: localFileURL(), options: [.atomic])
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("✅ [GameSync] JSON сохранён в Documents и распарсен")
                    completion(.success(json))
                } else {
                    completion(.failure(NSError(domain: "GameSync", code: -2, userInfo: [NSLocalizedDescriptionKey: "parse error"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Import

    private static func importCharacters(_ json: [[String: Any]]) {
        let context = PersistenceController.shared.localContainer.viewContext

        for item in json {
            guard let id = item["id"] as? Int64 else { continue }

            let fetch: NSFetchRequest<MathGameCharacterEntity> = MathGameCharacterEntity.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %d", id)

            let character = (try? context.fetch(fetch).first) ?? MathGameCharacterEntity(context: context)
            character.id = id
            character.name = item["name"] as? String
            character.imageName = item["imageName"] as? String
            character.achievement = item["achievement"] as? String
            character.info = item["info"] as? String

            if let imageName = character.imageName {
                downloadImageIfNeeded(named: imageName)
            }
        }

        do {
            try context.save()
            print("✅ [GameSync] MathGameCharacterEntity обновлён")
            NotificationCenter.default.post(name: .gameImportFinished, object: nil)
        } catch {
            print("❌ [GameSync] Ошибка сохранения: \(error.localizedDescription)")
            NotificationCenter.default.post(name: .gameImportFailed, object: error)
        }

    }

    // MARK: - Images

    private static func downloadImageIfNeeded(named fullName: String) {
        if imageExistsLocally(named: fullName) {
            print("✅ [GameSync] Изображение \(fullName) уже существует")
            return
        }

        let nameComponents = fullName.split(separator: ".")
        guard nameComponents.count == 2 else {
            print("❌ [GameSync] Неверный формат имени изображения: \(fullName)")
            return
        }

        let baseName = String(nameComponents[0])
        let ext = String(nameComponents[1])

        let storageRef = Storage.storage().reference().child("math_game/images/\(baseName).\(ext)")
        storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
            if let data = data, let image = UIImage(data: data) {
                saveImageToDocuments(image, name: baseName)
                print("📥 [GameSync] Загрузили изображение \(fullName) из Firebase")
            } else {
                print("❌ [GameSync] Ошибка загрузки изображения \(fullName): \(error?.localizedDescription ?? "")")
            }
        }
    }

    private static func saveImageToDocuments(_ image: UIImage, name: String) {
        guard let data = image.pngData() else { return }
        let url = localImagesDir().appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(at: localImagesDir(), withIntermediateDirectories: true)
            try data.write(to: url)
            print("💾 [GameSync] Сохранили \(name).png в Documents/images")
        } catch {
            print("❌ [GameSync] Ошибка сохранения \(name): \(error.localizedDescription)")
        }
    }

    private static func imageExistsLocally(named fullName: String) -> Bool {
        let baseName = fullName.split(separator: ".").first.map(String.init) ?? fullName
        if UIImage(named: baseName) != nil { return true }
        let path = localImagesDir().appendingPathComponent("\(baseName).png").path
        return FileManager.default.fileExists(atPath: path)
    }

    // MARK: - Paths

    private static func localFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("characters_export.json")
    }

    private static func localImagesDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images", isDirectory: true)
    }
}
extension Notification.Name {
    static let gameImportFinished = Notification.Name("gameImportFinished")
    static let gameImportFailed   = Notification.Name("gameImportFailed")
}


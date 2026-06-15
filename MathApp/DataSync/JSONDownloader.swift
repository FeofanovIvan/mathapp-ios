//
//  ✅ JSONDownloader.swift
//  MathApp
//
//  Created by Ivan Feofanov on 01/04/25.
//
import Foundation
import FirebaseStorage

final class JSONDownloader {
    static let shared = JSONDownloader()
    private init() {}

    // Какие наборы данных умеем тянуть
    enum Dataset: String {
        case ege = "EGE"
        case oge = "OGE"

        var storagePath: String {
            switch self {
            case .ege: return "databases/data_export.json"
            case .oge: return "databases/data_export_oge.json"
            }
        }

        var localFilename: String {
            switch self {
            case .ege: return "data_export.json"
            case .oge: return "data_export_oge.json"
            }
        }

        var logTag: String { "[\(rawValue)]" }
    }

    // MARK: - Публичные методы (только эти два)

    /// ЕГЭ: если локальный уже есть — обновляем из Firebase; если нет — берём seed из бандла (или Firebase, если seed отсутствует).
    func downloadJSON(completion: @escaping (Result<URL, Error>) -> Void) {
        handle(.ege, completion: completion)
    }

    /// ОГЭ: если локальный уже есть — обновляем из Firebase; если нет — берём seed из бандла (или Firebase, если seed отсутствует).
    func downloadOGEJSON(completion: @escaping (Result<URL, Error>) -> Void) {
        handle(.oge, completion: completion)
    }

    // MARK: - Приватная реализация

    private func handle(_ dataset: Dataset, completion: @escaping (Result<URL, Error>) -> Void) {
        let dstURL = localURL(for: dataset)

        // A) Локальный уже есть → сразу обновляем из Firebase
        if FileManager.default.fileExists(atPath: dstURL.path) {
            print("📦 \(dataset.logTag) [source=local-existing] Найден локальный JSON: \(dstURL.lastPathComponent) @ \(dstURL.path)")
            downloadFromFirebase(dataset, to: dstURL, completion: completion)
            return
        }

        // B) Локального нет → пробуем seed из бандла
        if let seedURL = seedURLInBundle(for: dataset) {
            do {
                try ensureDirectoryExists(at: dstURL.deletingLastPathComponent())
                try FileManager.default.copyItem(at: seedURL, to: dstURL)
                print("🌱 \(dataset.logTag) [source=bundle-seed] Скопирован seed из бандла: \(seedURL.lastPathComponent) → \(dstURL.lastPathComponent)")
                print("🗂️ \(dataset.logTag) Seed (bundle): \(seedURL.path)")
                print("🗂️ \(dataset.logTag) Target (docs):  \(dstURL.path)")

                // 👇 Инициализируем локальное хранилище версиями при первом запуске с seed
                initializeSeedMetadata(for: dataset)

                completion(.success(dstURL))
                return
            } catch {
                print("⚠️ \(dataset.logTag) Не удалось скопировать seed из бандла: \(error.localizedDescription)")
                // фоллбэк — качаем из Firebase
            }
        } else {
            print("ℹ️ \(dataset.logTag) Seed '\(dataset.localFilename)' в бандле не найден → качаем из Firebase")
        }

        // C) Seed нет/не скопировался → Firebase
        downloadFromFirebase(dataset, to: dstURL, completion: completion)
    }

    private func downloadFromFirebase(_ dataset: Dataset, to localURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let storage = Storage.storage()
        let ref = storage.reference(withPath: dataset.storagePath)

        // чистим, чтобы исключить конфликт записи
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("🧹 \(dataset.logTag) Удаляем существующий файл перед загрузкой: \(localURL.lastPathComponent)")
            try? FileManager.default.removeItem(at: localURL)
        }

        print("☁️ \(dataset.logTag) [source=firebase] Начинаю загрузку из Firebase: \(dataset.storagePath)")
        ref.write(toFile: localURL) { _, error in
            if let error = error {
                print("❌ \(dataset.logTag) [source=firebase] Ошибка загрузки JSON: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ \(dataset.logTag) [source=firebase] JSON загружен: \(localURL.path)")
                completion(.success(localURL))
            }
        }
    }

    private func localURL(for dataset: Dataset) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(dataset.localFilename, isDirectory: false)
    }

    private func seedURLInBundle(for dataset: Dataset) -> URL? {
        let name = (dataset.localFilename as NSString).deletingPathExtension
        let ext  = (dataset.localFilename as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    private func ensureDirectoryExists(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - Metadata (UserDefaults)

    /// Если стартуем с seed-файла, создаём локальные версии в UserDefaults по схеме SyncMetadata(version_game, version_oge, version_ege).
    private func initializeSeedMetadata(for dataset: Dataset) {
        let d = UserDefaults.standard

        // Если ещё не инициализировали общий флаг/версию игры — выставим 1
        if d.object(forKey: DefaultsKeys.version_game) == nil {
            d.set(1, forKey: DefaultsKeys.version_game)
            print("🧭 [META] Установлен version_game = 1 (инициализация при seed)")
        }

        switch dataset {
        case .ege:
            if d.object(forKey: DefaultsKeys.version_ege) == nil {
                d.set(1, forKey: DefaultsKeys.version_ege)
                print("🧭 [META] Установлен version_ege = 1 (инициализация при seed EGE)")
            } else {
                print("🧭 [META] version_ege уже инициализирован (=\(d.integer(forKey: DefaultsKeys.version_ege)))")
            }
        case .oge:
            if d.object(forKey: DefaultsKeys.version_oge) == nil {
                d.set(1, forKey: DefaultsKeys.version_oge)
                print("🧭 [META] Установлен version_oge = 1 (инициализация при seed OGE)")
            } else {
                print("🧭 [META] version_oge уже инициализирован (=\(d.integer(forKey: DefaultsKeys.version_oge)))")
            }
        }

        d.synchronize() // не обязателен, но пусть будет для явности в логах

        // Выведем текущие значения для контроля
        let vg = d.integer(forKey: DefaultsKeys.version_game)
        let ve = d.object(forKey: DefaultsKeys.version_ege) != nil ? d.integer(forKey: DefaultsKeys.version_ege) : nil
        let vo = d.object(forKey: DefaultsKeys.version_oge) != nil ? d.integer(forKey: DefaultsKeys.version_oge) : nil
        print("📊 [META] Текущие версии: version_game=\(vg), version_ege=\(ve.map(String.init) ?? "nil"), version_oge=\(vo.map(String.init) ?? "nil")")
    }

    private enum DefaultsKeys {
        static let version_game = "version_game"
        static let version_oge  = "version_oge"
        static let version_ege  = "version_ege"
    }
}

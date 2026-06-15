//
//  WelcomeBootstrapView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 18/09/25.
//
//

import SwiftUI
import CoreHaptics

struct WelcomeBootstrapView: View {
    // Brand
    private let brandDark = Color(red: 0.12, green: 0.18, blue: 0.35)
    private let bgGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.95, green: 0.98, blue: 1.0), .white]),
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Фазы загрузки
    enum Phase: Int, CaseIterable { case hello, seeding, shortWait, checkUpdates, updating, done }

    @State private var phase: Phase = .hello
    @State private var isAnimatingBadge = false
    @State private var isReady = false
    @State private var engine: CHHapticEngine?

    // Профиль пользователя (по умолчанию пустой)
    @AppStorage("selectedProfile") private var selectedProfile: String = ""

    // Колбэк в родителя
    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                // Лого + название
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(brandDark.opacity(0.06))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimatingBadge ? 1.04 : 0.96)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimatingBadge)

                        Image(systemName: "function")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(brandDark)
                            .accessibilityHidden(true)
                    }

                    Text("MathUp")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(brandDark)
                        .tracking(0.5)
                }

                // Статус
                Group {
                    switch phase {
                    case .hello:
                        StatusPill(text: "Добро пожаловать в MathUp", color: brandDark)
                    case .seeding:
                        StatusPill(text: "Сейчас мы загрузим базу данных", color: brandDark)
                    case .shortWait:
                        StatusPill(text: "Вам нужно немного подождать", color: brandDark)
                    case .checkUpdates:
                        StatusPill(text: "Сейчас мы проверим обновления", color: brandDark)
                    case .updating:
                        StatusPill(text: "Обновляем БД", color: brandDark)
                    case .done:
                        StatusPill(text: "Отлично! Мы настроили приложение", color: brandDark)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                // Индикатор прогресса
                if phase != .done {
                    PulseDots()
                        .frame(height: 14)
                        .padding(.top, -10)
                        .accessibilityLabel("Идёт подготовка…")
                }

                // Блок выбора профиля появляется после завершения бутстрапа
                if phase == .done {
                    VStack(spacing: 14) {
                        Text("Выберите профиль")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(brandDark.opacity(0.9))

                        Menu {
                            Button("База ЕГЭ")     { selectedProfile = "База" }
                            Button("Профиль ЕГЭ")  { selectedProfile = "Профиль" }
                            Divider()
                            Button("ОГЭ")          { selectedProfile = "ОГЭ" }
                        } label: {
                            HStack(spacing: 10) {
                                Text(selectedProfile.isEmpty
                                     ? "Профиль не выбран"
                                     : (selectedProfile == "База" ? "База ЕГЭ"
                                        : (selectedProfile == "Профиль" ? "Профиль ЕГЭ" : "ОГЭ")))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(brandDark)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: brandDark.opacity(0.18), radius: 10, x: 0, y: 6)
                        }

                        if !selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                haptic(.success)
                                withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                                    isReady = true
                                }
                                onComplete?()
                            } label: {
                                Text("Продолжить")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.green.opacity(0.25), radius: 10, x: 0, y: 6)
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            isAnimatingBadge = true
            prepareHaptics()
            advancePhases()
        }
        .opacity(isReady ? 0 : 1)
        .animation(.easeInOut(duration: 0.35), value: isReady)
    }

    // MARK: - Фазовый драйвер (реактивный)
    private func advancePhases() {
        Task { @MainActor in
            haptic(.light)

            // 1) Hello → Seeding
            withAnimation { phase = .seeding }

            // Стартуем все импорты параллельно
            DataImportService.downloadAndImportEGE(context: PersistenceController.shared.firebaseContext)
            DataImportService.downloadAndImportOGE(context: PersistenceController.shared.ogeContext)
            MathGameUpdateService.syncGameCharacters()

            // Едем дальше по ПЕРВОМУ успешному/ошибочному событию (или короткий таймаут)
            _ = await waitFirstEvent(
                success: [.egeImportFinished, .ogeImportFinished, .gameImportFinished],
                fail:    [.egeImportFailed,   .ogeImportFailed,   .gameImportFailed],
                timeoutSeconds: 5
            )

            // 2) Seeding → ShortWait (небольшая визуальная пауза)
            withAnimation { phase = .shortWait }
            haptic(.soft)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // 3) ShortWait → CheckUpdates
            withAnimation { phase = .checkUpdates }

            // Сверяем версии и при необходимости запускаем обновления (пойдут параллельно)
            DataUpdateScheduler.performEGEUpdateIfNeeded(context: PersistenceController.shared.firebaseContext)
            DataUpdateScheduler.performOGEUpdateIfNeeded(context: PersistenceController.shared.ogeContext)
            DataUpdateScheduler.performGameUpdateIfNeeded()

            // 4) CheckUpdates → Updating
            withAnimation { phase = .updating }

            // Переходим дальше по ПЕРВОМУ событию об окончании обновления (или короткий таймаут, если обновлений нет)
            _ = await waitFirstEvent(
                success: [.egeImportFinished, .ogeImportFinished, .gameImportFinished],
                fail:    [.egeImportFailed,   .ogeImportFailed,   .gameImportFailed],
                timeoutSeconds: 1.2
            )

            // 5) Updating → Done
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { phase = .done }
            haptic(.success)
        }
    }

    // MARK: - Haptics
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    private func haptic(_ style: HapticStyle) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let events: [CHHapticEvent]
        switch style {
        case .light:
            events = [CHHapticEvent(eventType: .hapticTransient,
                                    parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                                                 CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)],
                                    relativeTime: 0)]
        case .soft:
            events = [CHHapticEvent(eventType: .hapticTransient,
                                    parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                                                 CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)],
                                    relativeTime: 0)]
        case .medium:
            events = [CHHapticEvent(eventType: .hapticTransient,
                                    parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                                                 CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)],
                                    relativeTime: 0)]
        case .success:
            events = [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                                           CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)],
                              relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                                           CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)],
                              relativeTime: 0.08)
            ]
        }
        let pattern = try? CHHapticPattern(events: events, parameters: [])
        let player = try? engine?.makePlayer(with: pattern!)
        try? player?.start(atTime: 0)
    }

    enum HapticStyle { case light, soft, medium, success }
}

// MARK: - Subviews

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(0.08))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.12), lineWidth: 1))
            .shadow(color: color.opacity(0.06), radius: 10, x: 0, y: 6)
            .accessibilityLabel(text)
    }
}

private struct PulseDots: View {
    @State private var t: CGFloat = 0
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.black.opacity(0.18))
                    .frame(width: 8, height: 8)
                    .scaleEffect(1 + 0.25 * sin(t + CGFloat(i) * 0.7))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: true), value: t)
            }
        }
        .onAppear { t = .pi / 2 }
    }
}

// MARK: - Wait helpers

/// Ждёт ПЕРВОЕ из указанных событий (успех/ошибка) и сразу возвращает его; nil по таймауту.
private func waitFirstEvent(success names: [Notification.Name],
                            fail failNames: [Notification.Name],
                            timeoutSeconds: TimeInterval) async -> Notification.Name? {
    await withCheckedContinuation { cont in
        var tokens: [NSObjectProtocol] = []
        var finished = false

        func finish(_ name: Notification.Name?) {
            guard !finished else { return }
            finished = true
            tokens.forEach { NotificationCenter.default.removeObserver($0) }
            cont.resume(returning: name)
        }

        for n in names {
            let t = NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { _ in
                finish(n)
            }
            tokens.append(t)
        }
        for n in failNames {
            let t = NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { _ in
                finish(n)
            }
            tokens.append(t)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
            finish(nil)
        }
    }
}

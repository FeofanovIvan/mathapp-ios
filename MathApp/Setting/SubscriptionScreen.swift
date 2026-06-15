//
//  SubscriptionScreen.swift
//  MathApp
//
//  Created by Ivan Feofanov on 09/04/25.
//

import SwiftUI

struct SubscriptionScreen: View {
    @Environment(\.dismiss) var dismiss
    var updateTitle: (String) -> Void

    var body: some View {
        ZStack {
            // 🔹 Фон как в настройках
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color(red: 0.95, green: 0.98, blue: 1)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 🔝 Верхняя панель
                HStack {
                    Button(action: {
                        dismiss()
                        updateTitle("ЕГЭ математика")
                    }) {
                        Image(systemName: "arrow.backward")
                            .foregroundColor(.white)
                            .padding()
                    }

                    Spacer()

                    Text("Управление подпиской")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()
                    Spacer().frame(width: 60)
                }
                .padding(.bottom, 8)
                .background(Color(red: 0.12, green: 0.18, blue: 0.35))

                // 🔽 Контент
                ScrollView {
                    VStack(spacing: 20) {
                        SubscriptionCard(
                            icon: "leaf.fill",
                            title: "Бесплатная подписка",
                            description: "В базовой подписке вы получаете доступ ко всем теоретическим файлам, практике, экзамену без оценивания и первым пяти разборам заданий.",
                            isCurrent: false
                        )

                        SubscriptionCard(
                            icon: "calendar",
                            title: "Ежемесячная подписка",
                            description: "Полный доступ ко всем заданиям, разбору ошибок, оценке решений и статистике прогресса. Оплата раз в месяц."
                        )

                        SubscriptionCard(
                            icon: "calendar.badge.plus",
                            title: "Годовая подписка",
                            description: "Экономия 40%. Полный доступ на 12 месяцев. Включает всё, что есть в месячной подписке."
                        )

                        SubscriptionCard(
                            icon: "gift.fill",
                            title: "Акция до 01.01.2026",
                            description: "Бесплатная полная подписка доступна всем пользователям до 1 января 2026 года. Успейте воспользоваться!",
                            isCurrent: true,
                            animateGift: true
                        )
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
    }
}


struct SubscriptionCard: View {
    var icon: String
    var title: String
    var description: String
    var isCurrent: Bool = false
    var animateGift: Bool = false

    @State private var rotate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if animateGift && icon == "gift.fill" {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.pink)
                        .rotationEffect(.degrees(rotate ? 10 : -10))
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: rotate)
                        .onAppear { rotate = true }
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                Text(title)
                    .font(.headline)
                    .bold()

                Spacer()

                if isCurrent {
                    Text("Текущая")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}


struct AnimatedRibbonView: View {
    @State private var pulse: Bool = false

    var body: some View {
        Text("Акция")
            .font(.caption)
            .bold()
            .padding(6)
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(pulse ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            .onAppear {
                pulse = true
            }
    }
}

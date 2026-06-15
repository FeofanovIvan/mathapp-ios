//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI
import FirebaseFirestore

struct NewsView: View {
    @State private var news: [NewsItem] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // 🔹 Фон
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                if isLoading {
                    ProgressView("Загрузка новостей...")
                        .padding()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(sortedNews) { item in
                            NewsItemView(item: item)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.5), value: news)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: fetchNews)
    }

    private var sortedNews: [NewsItem] {
        news.sorted {
            ($0.dateObject ?? Date.distantPast) > ($1.dateObject ?? Date.distantPast)
        }
    }

    private func fetchNews() {
        let db = Firestore.firestore()
        db.collection("news").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Ошибка загрузки новостей: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else { return }

            self.news = documents.compactMap { doc in
                let data = doc.data()
                return NewsItem(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "Без заголовка",
                    content: data["content"] as? String ?? "Нет описания",
                    date: data["date"] as? String ?? "—"
                )
            }

            isLoading = false
        }
    }
}

import SwiftUI

struct NewsCardView: View {
    var description: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal, 10)
    }
}
import Foundation

struct NewsItem: Identifiable, Equatable {
    let id: String
    let title: String
    let content: String
    let date: String

    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: date)
    }

}
struct NewsItemView: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image("appnews")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))

                    Text(item.date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text(item.content)
                .font(.subheadline)
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading) // 🔹 Главное изменение
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 4)
    }
}





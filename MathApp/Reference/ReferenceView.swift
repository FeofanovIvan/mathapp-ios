//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//

import SwiftUI

struct ReferenceView: View {
    @Environment(\.presentationMode) var presentationMode
    var updateTitle: (String) -> Void

    @AppStorage("selectedProfile") var selectedProfile: String = "База" // "База", "Профиль", "ОГЭ"

    private var numberOfTasks: Int {
        selectedProfile == "ОГЭ" ? 25 : (selectedProfile == "Профиль" ? 19 : 21)
    }

    private var examTitle: String {
        selectedProfile == "ОГЭ" ? "ОГЭ математика" : "ЕГЭ математика"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    updateTitle(examTitle)
                }) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.white)
                        .padding()
                }

                Spacer()

                Text("Справочник")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
                Spacer().frame(width: 60)
            }
            .padding()
            .background(Color(red: 0.12, green: 0.18, blue: 0.35))

            // Список блоков
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(1...numberOfTasks, id: \.self) { index in
                        // для ЕГЭ профильных блоки начинаются с 22 (смещение +21)
                        let actualBlockID: Int = {
                            if selectedProfile == "Профиль" {
                                return index + 21
                            } else {
                                return index // База ЕГЭ и ОГЭ идут подряд без смещения
                            }
                        }()

                        NavigationLink(
                            destination: ReferenceDetailView(
                                blockID: Int64(actualBlockID),
                                selectedProfile: selectedProfile
                            )
                        ) {
                            ReferenceBlock(title: "Задание \(index)")
                        }
                    }
                }
                .padding(.vertical)
                .background(.white)
            }
        }
        .onAppear {
            updateTitle("Справочник")
        }
        .navigationBarHidden(true)
        .navigationBarTitle("")
    }
}

struct ReferenceBlock: View {
    let title: String

    var body: some View {
        HStack {
            Image(systemName: "book.fill")
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

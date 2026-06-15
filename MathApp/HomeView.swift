//
//  HomeView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 06/01/25.
//
import CoreData
import SwiftUI

struct HomeView: View {
    var selectedOption: String
    var updateTitle: (String) -> Void

    // Пропорции на основе ширины iPhone 16 (393 pt)
    let baseWidth: CGFloat = 393
    let cards: [(String, String, CGFloat, CGFloat, CGFloat, Bool)] = [
        ("Правила", "rb_10492", 100, 140, 80, true),
        ("Экзамен", "rb_13742", 105, 260, 180, false),
        ("Подготовка", "rb_2754", 105, 160, 280, true),
        ("Справочник", "rb_2149341898", 100, 250, 380, false),
        ("Формулы", "cartoon", 100, 140, 480, true),
        ("Видеоразбор", "13795580_5363934", 105, 220, 580, false),
        ("Игры", "cute", 105, 135, 700, true)
    ]

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / baseWidth

            ZStack {
                AnimatedBackground()
                AnimatedBlobs()

                ScrollView(.vertical, showsIndicators: false) {
                    ZStack {
                        ForEach(0..<cards.count, id: \.self) { index in
                            let card = cards[index]

                            NavigationLink(destination: destinationView(for: card.0)) {
                                CircleCardView(
                                    title: card.0,
                                    imageName: card.1,
                                    imageSize: card.2 * scale,
                                    fontSize: 18 * scale,
                                    alignLeft: card.5
                                )
                            }
                            .position(
                                x: card.3 * scale,
                                y: card.4 * scale
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 740 * scale)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    @ViewBuilder
    func destinationView(for title: String) -> some View {
        switch title {
        case "Правила": RulesScreen(updateTitle: updateTitle)
        case "Экзамен": ExamView()
        case "Подготовка": PreparationView(updateTitle: updateTitle)
        case "Справочник": ReferenceView(updateTitle: updateTitle)
        case "Формулы": FormulasView(updateTitle: updateTitle)
        case "Видеоразбор": VideoAnalysisView(updateTitle: updateTitle)
        case "Игры": PortraitPuzzleView(updateTitle: updateTitle)
        default: Text("Экран в разработке")
        }
    }
}


struct AnimatedBackground: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.94, green: 0.96, blue: 1.0),
                Color(red: 1.0, green: 1.0, blue: 1.0),
                Color(red: 0.92, green: 0.95, blue: 0.99)
            ]),
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
        .onAppear {
            animate = true
        }
    }
}

struct CircleCardView: View {
    var title: String
    var imageName: String
    var imageSize: CGFloat
    var fontSize: CGFloat
    var alignLeft: Bool

    @State private var animate = false

    var body: some View {
        HStack(spacing: 16) {
            if alignLeft {
                CircleImage(imageName: imageName, size: imageSize)
                Text(title)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
            } else {
                Text(title)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.35))
                CircleImage(imageName: imageName, size: imageSize)
            }
        }
        .padding(8)
        .scaleEffect(animate ? 1.03 : 0.97)
        .animation(
            .easeInOut(duration: Double.random(in: 2.0...3.5)).repeatForever(autoreverses: true),
            value: animate
        )
        .onAppear { animate = true }
    }
}

struct CircleImage: View {
    var imageName: String
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
                .shadow(radius: 5)

            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.75, height: size * 0.75)
                    .clipShape(Circle())
            } else {
                Text("😶")
                    .font(.system(size: size * 0.4))
            }
        }
    }
}


struct AnimatedBlobs: View {
    @State private var move = false

    var body: some View {
        ZStack {
            Blob(color: Color.purple.opacity(0.25), size: 350, offset: CGSize(width: move ? 100 : -80, height: move ? -100 : 80))
            Blob(color: Color.blue.opacity(0.25), size: 280, offset: CGSize(width: move ? -120 : 60, height: move ? 100 : -90))
            Blob(color: Color.pink.opacity(0.25), size: 300, offset: CGSize(width: move ? 90 : -70, height: move ? 60 : -100))
        }
        .blur(radius: 90)
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                move.toggle()
            }
        }
    }
}

struct Blob: View {
    var color: Color
    var size: CGFloat
    var offset: CGSize

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(offset)
    }
}

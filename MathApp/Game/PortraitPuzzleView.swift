//
//  PortraitPuzzleView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 09/04/25.
//

import SwiftUI
import CoreData

struct PortraitPuzzleView: View {
    @Environment(\.presentationMode) var presentationMode
    var updateTitle: (String) -> Void

    @State private var characters: [MathGameCharacterEntity] = []
    @State private var currentIndex = 0
    @State private var tiles: [Tile] = []
    @State private var isCompleted = false
    @State private var showFullImage = false
    @State private var showInfoCard = false

    let gridSize = 4

    private var context: NSManagedObjectContext {
        PersistenceController.shared.localContainer.viewContext
    }

    var currentCharacter: MathGameCharacterEntity? {
        guard characters.indices.contains(currentIndex) else { return nil }
        return characters[currentIndex]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.95, green: 0.98, blue: 1.0), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        updateTitle("ЕГЭ математика")
                    }) {
                        Image(systemName: "arrow.backward")
                            .foregroundColor(.white)
                            .padding()
                    }

                    Spacer()

                    Text("Собери портрет")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()
                    Spacer().frame(width: 60)
                }
                .padding()
                .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                Spacer(minLength: 15)

                ScrollView {
                       VStack(spacing: 10) {

                Text("Здесь зашифрован портрет великого математика")
                    .font(.title3)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color(red: 0.15, green: 0.2, blue: 0.4))
                                        .padding()
                                        .frame(maxWidth: .infinity) // ← важно!
                                        .fixedSize(horizontal: false, vertical: true) // ← это принудит перенос
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(14)
                                        .padding(.horizontal)
                                        .shadow(radius: 3)
                Spacer(minLength: 10)

                if isCompleted {
                    ZStack {
                        if let imageName = currentCharacter?.imageName,
                           let image = loadImage(named: imageName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 360, height: 360)
                                .cornerRadius(16)
                                .shadow(radius: 8)
                                .transition(.opacity)
                        }

                        if showInfoCard {
                            VStack(spacing: 10) {
                                Text("Это \(currentCharacter?.name ?? "неизвестно")")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(currentCharacter?.achievement ?? "")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(16)
                            .padding(.horizontal, 30)
                            .shadow(radius: 6)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 2), count: gridSize), spacing: 2) {
                        ForEach(tiles) { tile in
                            if let image = tile.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(10)
                                    .shadow(color: .gray.opacity(0.3), radius: 2)
                                    .onTapGesture {
                                        move(tile: tile)
                                    }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .transition(.opacity)
                }

                Spacer(minLength: 10)

                HStack(alignment: .top, spacing: 10) {
                    Text("📌")
                    Text(currentCharacter?.info ?? "")
                        .font(.body)
                                              .multilineTextAlignment(.leading)
                                              .frame(maxWidth: .infinity, alignment: .leading)
                                              .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(14)
                .padding(.horizontal)
                .shadow(radius: 3)

                Spacer()

                HStack(spacing: 10) {
                    CircleButton(iconName: "chevron.left", action: {
                        if currentIndex > 0 {
                            currentIndex -= 1
                            resetPuzzle()
                        }
                    })

                    CircleButton(iconName: "chevron.right", action: {
                        if currentIndex < characters.count - 1 {
                            currentIndex += 1
                            resetPuzzle()
                        }
                    })
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
                }
            }
            .onAppear {
                updateTitle("Собери портрет")
                fetchCharacters()
            }
        }
        .navigationBarHidden(true)
    }

    private func fetchCharacters() {
        let request: NSFetchRequest<MathGameCharacterEntity> = MathGameCharacterEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MathGameCharacterEntity.name, ascending: true)]

        do {
            characters = try context.fetch(request)
            resetPuzzle()
        } catch {
            print("❌ Ошибка загрузки персонажей: \(error.localizedDescription)")
        }
    }

    private func resetPuzzle() {
        isCompleted = false
        showFullImage = false
        showInfoCard = false

        if let imageName = currentCharacter?.imageName,
           let image = loadImage(named: imageName) {
            let originalTiles = sliceImage(image, gridSize: gridSize)
            let shuffled = originalTiles.shuffled()
            tiles = shuffled.enumerated().map { index, tile in
                let row = index / gridSize
                let col = index % gridSize
                return Tile(id: tile.id, image: tile.image, row: row, col: col)
            }
        }
    }

    private func checkIfPuzzleIsSolved() {
        for index in tiles.indices {
            if tiles[index].id != index {
                return
            }
        }
        withAnimation(.easeIn(duration: 0.5)) {
            isCompleted = true
            showFullImage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showInfoCard = true
            }
        }
    }
    private func loadImage(named name: String) -> UIImage? {
        // 1. Пробуем из Assets
        if let assetImage = UIImage(named: name) {
            return assetImage
        }

        // 2. Пробуем из Documents
        let baseName = name.split(separator: ".").first.map(String.init) ?? name
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(baseName).png")

        if FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let docImage = UIImage(data: data) {
            return docImage
        }

        return nil
    }


    private func move(tile: Tile) {
        guard let emptyIndex = tiles.firstIndex(where: { $0.image == nil }),
              let tappedIndex = tiles.firstIndex(of: tile) else { return }

        let emptyTile = tiles[emptyIndex]
        let rowDiff = abs(tile.row - emptyTile.row)
        let colDiff = abs(tile.col - emptyTile.col)

        if (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1) {
            var newTiles = tiles
            newTiles[emptyIndex].row = tile.row
            newTiles[emptyIndex].col = tile.col
            newTiles[tappedIndex].row = emptyTile.row
            newTiles[tappedIndex].col = emptyTile.col
            newTiles.swapAt(emptyIndex, tappedIndex)
            tiles = newTiles
            checkIfPuzzleIsSolved()
        }
    }
}


struct CircleButton: View {
    let iconName: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeIn(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring()) {
                    isPressed = false
                }
                action()
            }
        }) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color(red: 0.12, green: 0.18, blue: 0.35))
                .clipShape(Circle())
                .scaleEffect(isPressed ? 0.88 : 1.0)
                .shadow(radius: 4)
        }
    }
}

struct Tile: Identifiable, Equatable {
    let id: Int
    let image: UIImage?
    var row: Int
    var col: Int
}

func sliceImage(_ image: UIImage, gridSize: Int = 4) -> [Tile] {
    let size = image.size
    let tileWidth = size.width / CGFloat(gridSize)
    let tileHeight = size.height / CGFloat(gridSize)
    var tiles: [Tile] = []

    for row in 0..<gridSize {
        for col in 0..<gridSize {
            let id = row * gridSize + col
            let rect = CGRect(x: CGFloat(col) * tileWidth,
                              y: CGFloat(row) * tileHeight,
                              width: tileWidth,
                              height: tileHeight)
            let imagePiece: UIImage? = image.cgImage?.cropping(to: rect).map {
                UIImage(cgImage: $0, scale: image.scale, orientation: image.imageOrientation)
            }
            tiles.append(Tile(id: id, image: imagePiece, row: row, col: col))
        }
    }

    // Последнюю плитку делаем пустой
    tiles[tiles.count - 1] = Tile(id: tiles.count - 1, image: nil, row: gridSize - 1, col: gridSize - 1)
    return tiles
}





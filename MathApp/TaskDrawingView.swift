//
//  DrawingCanvasView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 02/04/25.
//
import SwiftUI
import CoreGraphics

// MARK: - Models

enum ShapeType { case circle, rect, triangle, rightTriangle }

struct ShapeModel: Identifiable {
    let id = UUID()
    var type: ShapeType
    var start: CGPoint      // world
    var end: CGPoint        // world
    var color: Color
    var stroke: CGFloat
    // Только для rightTriangle
    var rotationDeg: CGFloat = 0

    var bounds: (tl: CGPoint, br: CGPoint) {
        let left = min(start.x, end.x), top = min(start.y, end.y)
        let right = max(start.x, end.x), bottom = max(start.y, end.y)
        return (CGPoint(x:left, y:top), CGPoint(x:right, y:bottom))
    }
}

// MARK: - View

struct TaskDrawingView: View {
    @ObservedObject var canvasState: DrawingCanvasState

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                GridBackground(offset: canvasState.offset)
                AxesLayer(show: canvasState.showAxes, offset: canvasState.offset)

                // === CANVAS ===
                Canvas { context, _ in
                    // линии (готовые)
                    for line in canvasState.lines {
                        let path = Path { path in
                            guard let fp = line.points.first else { return }
                            path.move(to: CGPoint(x: fp.x + canvasState.offset.width,
                                                  y: fp.y + canvasState.offset.height))
                            for p in line.points.dropFirst() {
                                path.addLine(to: CGPoint(x: p.x + canvasState.offset.width,
                                                         y: p.y + canvasState.offset.height))
                            }
                        }
                        context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
                    }

                    // фигуры (готовые)
                    for s in canvasState.shapes {
                        drawShape(s, in: context, offset: canvasState.offset)
                    }

                    // активная фигура (в процессе)
                    if let s = canvasState.currentShape {
                        drawShape(s, in: context, offset: canvasState.offset)
                    }

                    // активная линия
                    let path = Path { path in
                        guard let fp = canvasState.currentLine.points.first else { return }
                        path.move(to: CGPoint(x: fp.x + canvasState.offset.width,
                                              y: fp.y + canvasState.offset.height))
                        for p in canvasState.currentLine.points.dropFirst() {
                            path.addLine(to: CGPoint(x: p.x + canvasState.offset.width,
                                                     y: p.y + canvasState.offset.height))
                        }
                    }
                    context.stroke(path, with: .color(canvasState.currentLine.color),
                                   lineWidth: canvasState.currentLine.lineWidth)
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // стартовое центрирование 1 раз
                        if !canvasState.didCenterOnAppear {
                            canvasState.didCenterOnAppear = true
                            canvasState.offset = CGSize(width: geo.size.width/2,
                                                        height: geo.size.height/2)
                        }

                        if canvasState.isMoveMode {
                            if let last = canvasState.lastDragPosition {
                                canvasState.offset = CGSize(
                                    width: canvasState.offset.width + value.translation.width - last.width,
                                    height: canvasState.offset.height + value.translation.height - last.height
                                )
                            }
                            canvasState.lastDragPosition = value.translation
                        } else if canvasState.isEraserActive {
                            erase(at: value.location - canvasState.offset)
                        } else if let tool = canvasState.selectedShapeTool {
                            // рисуем фигуру
                            let world = value.location - canvasState.offset
                            if canvasState.currentShape == nil {
                                canvasState.currentShape = ShapeModel(
                                    type: tool,
                                    start: world,
                                    end: world,
                                    color: canvasState.selectedColor,
                                    stroke: CGFloat(canvasState.lineWidth)
                                )
                            } else {
                                canvasState.currentShape?.end = world
                            }
                        } else {
                            // обычная линия
                            canvasState.currentLine.points.append(value.location - canvasState.offset)
                        }
                    }
                    .onEnded { _ in
                        if canvasState.isMoveMode {
                            canvasState.lastDragPosition = nil
                            return
                        }
                        if canvasState.isEraserActive { return }

                        if let s = canvasState.currentShape {
                            if s.start != s.end {
                                canvasState.shapes.append(s)
                                if s.type == .rightTriangle {
                                    canvasState.selectedShapeIndex = canvasState.shapes.indices.last
                                }
                            }
                            canvasState.currentShape = nil
                            return
                        }
                        if !canvasState.currentLine.points.isEmpty {
                            canvasState.lines.append(canvasState.currentLine)
                            canvasState.currentLine = DrawingLine(points: [],
                                                                  color: canvasState.selectedColor,
                                                                  lineWidth: CGFloat(canvasState.lineWidth))
                        }
                    }
                )
                .background(Color.clear)
                .cornerRadius(10)
                .shadow(radius: 5)
                .onAppear {
                    if !canvasState.didCenterOnAppear {
                        canvasState.didCenterOnAppear = true
                        canvasState.offset = CGSize(width: geo.size.width/2,
                                                    height: geo.size.height/2)
                    }
                }

                // === Кнопки поворота (только если выбран rightTriangle) ===
                GeometryReader { proxy in
                    if let i = canvasState.selectedShapeIndex,
                       canvasState.shapes.indices.contains(i),
                       canvasState.shapes[i].type == .rightTriangle {

                        let s = canvasState.shapes[i]
                        let b = s.bounds
                        let centerBottomWorld = CGPoint(x: (b.tl.x + b.br.x)/2, y: b.br.y)
                        let anchor = CGPoint(x: centerBottomWorld.x + canvasState.offset.width,
                                             y: centerBottomWorld.y + canvasState.offset.height)

                        // ограничиваем в экране
                        let x = max(8, min(anchor.x - 72, proxy.size.width - 120))
                        let y = min(anchor.y + 24, proxy.size.height - 56)

                        HStack(spacing: 12) {
                            Button {
                                if canvasState.shapes.indices.contains(i) {
                                    canvasState.shapes[i].rotationDeg -= 15
                                }
                            } label: {
                                Image(systemName: "rotate.left")
                                    .foregroundColor(.white)
                                    .padding(10)
                            }
                            .background(Color.indigo.opacity(0.95), in: Capsule())

                            Button {
                                if canvasState.shapes.indices.contains(i) {
                                    canvasState.shapes[i].rotationDeg += 15
                                }
                            } label: {
                                Image(systemName: "rotate.right")
                                    .foregroundColor(.white)
                                    .padding(10)
                            }
                            .background(Color.indigo.opacity(0.95), in: Capsule())
                        }
                        .position(x: x, y: y)
                        .animation(.easeInOut(duration: 0.15), value: canvasState.shapes[i].rotationDeg)
                    }
                }

                // === Нижняя панель (компактная в landscape) ===
                VStack {
                    Spacer()
                    BottomBar(canvasState: canvasState, isLandscape: isLandscape, canvasSize: geo.size)
                }
            }
            // === Правая панель (без «карандаша»): Undo / Оси / Центр / Фигуры ===
            .overlay(
                RightSidePanel(
                    isLandscape: isLandscape,
                    showAxes: canvasState.showAxes,
                    onToggleAxes: { canvasState.showAxes.toggle() },
                    onResetView: {
                        canvasState.offset = CGSize(width: geo.size.width/2,
                                                    height: geo.size.height/2)
                    },
                    onUndo: { canvasState.undo() },
                    selectedShape: canvasState.selectedShapeTool,
                    onSelectShape: { tool in
                        canvasState.selectedShapeTool = tool
                        canvasState.isEraserActive = false
                        canvasState.isMoveMode = false
                    }
                )
                .padding(.trailing, 8),
                alignment: .trailing
            )
            // Tap-выбор фигуры (bbox), чтобы показывать кнопки поворота
            .modifier(ShapeTapSelectionModifier(canvasState: canvasState))
        }
        .onChange(of: canvasState.selectedColor) { newColor in
            canvasState.currentLine.color = newColor
            if canvasState.currentShape != nil {
                canvasState.currentShape?.color = newColor
            }
        }
        .onChange(of: canvasState.lineWidth) { newWidth in
            canvasState.currentLine.lineWidth = CGFloat(newWidth)
            if canvasState.currentShape != nil {
                canvasState.currentShape?.stroke = CGFloat(newWidth)
            }
        }
    }

    // MARK: - Eraser

    private func erase(at location: CGPoint) {
        let eraseRadius: CGFloat = 10
        var newLines: [DrawingLine] = []

        for line in canvasState.lines {
            var seg: [CGPoint] = []
            for p in line.points {
                let d = hypot(p.x - location.x, p.y - location.y)
                if d > eraseRadius {
                    seg.append(p)
                } else if !seg.isEmpty {
                    newLines.append(DrawingLine(points: seg, color: line.color, lineWidth: line.lineWidth))
                    seg = []
                }
            }
            if !seg.isEmpty {
                newLines.append(DrawingLine(points: seg, color: line.color, lineWidth: line.lineWidth))
            }
        }
        canvasState.lines = newLines
    }

    // MARK: - Figures

    private func drawShape(_ s: ShapeModel, in context: GraphicsContext, offset: CGSize) {
        let style = StrokeStyle(lineWidth: s.stroke)

        switch s.type {
        case .circle:
            let cx = (s.start.x + s.end.x)/2, cy = (s.start.y + s.end.y)/2
            let rx = abs(s.end.x - s.start.x)/2, ry = abs(s.end.y - s.start.y)/2
            let r = max(rx, ry)
            let center = CGPoint(x: cx + offset.width, y: cy + offset.height)
            let rect = CGRect(x: center.x - r, y: center.y - r, width: 2*r, height: 2*r)
            context.stroke(Path(ellipseIn: rect), with: .color(s.color), style: style)

        case .rect:
            let (tl, br) = s.bounds
            let tlS = CGPoint(x: tl.x + offset.width, y: tl.y + offset.height)
            let brS = CGPoint(x: br.x + offset.width, y: br.y + offset.height)
            let rect = CGRect(x: tlS.x, y: tlS.y, width: brS.x - tlS.x, height: brS.y - tlS.y)
            context.stroke(Path(rect), with: .color(s.color), style: style)

        case .triangle:
            let (tl, br) = s.bounds
            let p1 = CGPoint(x: (tl.x + br.x)/2 + offset.width, y: tl.y + offset.height)   // верх
            let p2 = CGPoint(x: tl.x + offset.width, y: br.y + offset.height)
            let p3 = CGPoint(x: br.x + offset.width, y: br.y + offset.height)
            var path = Path()
            path.move(to: p1); path.addLine(to: p2); path.addLine(to: p3); path.closeSubpath()
            context.stroke(path, with: .color(s.color), style: style)

        case .rightTriangle:
            // базовый путь в МИРОВЫХ координатах (прямой угол — левый-низ bbox)
            let (tl, br) = s.bounds
            let aW = CGPoint(x: tl.x, y: br.y) // прямой угол
            let bW = CGPoint(x: br.x, y: br.y)
            let cW = CGPoint(x: tl.x, y: tl.y)
            var path = Path()
            path.move(to: aW); path.addLine(to: bW); path.addLine(to: cW); path.closeSubpath()

            // поворот вокруг прямого угла, затем перевод в экран
            let pivotW = aW
            let t1 = CGAffineTransform(translationX: -pivotW.x, y: -pivotW.y)
            let r  = CGAffineTransform(rotationAngle: s.rotationDeg * .pi/180)
            let t2 = CGAffineTransform(translationX: pivotW.x, y: pivotW.y)
            let toScreen = CGAffineTransform(translationX: offset.width, y: offset.height)

            path = path.applying(t1).applying(r).applying(t2).applying(toScreen)
            context.stroke(path, with: .color(s.color), style: style)
        }
    }
}

// MARK: - Grid & Axes

struct GridBackground: View {
    let offset: CGSize
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let spacing: CGFloat = 20
                let startX = -size.width * 2 + offset.width.truncatingRemainder(dividingBy: spacing)
                let startY = -size.height * 2 + offset.height.truncatingRemainder(dividingBy: spacing)

                for x in stride(from: startX, to: size.width * 2, by: spacing) {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: -size.height * 2))
                            path.addLine(to: CGPoint(x: x, y: size.height * 2))
                        },
                        with: .color(Color.gray.opacity(0.3)),
                        lineWidth: 0.5
                    )
                }
                for y in stride(from: startY, to: size.height * 2, by: spacing) {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: -size.width * 2, y: y))
                            path.addLine(to: CGPoint(x: size.width * 2, y: y))
                        },
                        with: .color(Color.gray.opacity(0.3)),
                        lineWidth: 0.5
                    )
                }
            }
        }
        .background(Color.white)
    }
}

struct AxesLayer: View {
    var show: Bool
    var offset: CGSize
    var spacing: CGFloat = 40

    var body: some View {
        if !show { EmptyView() } else {
            Canvas { ctx, size in
                let left = -offset.width
                let top = -offset.height
                let right = left + size.width
                let bottom = top + size.height

                ctx.withCGContext { cg in
                    cg.translateBy(x: offset.width, y: offset.height)
                    cg.setStrokeColor(UIColor.darkGray.cgColor)
                    cg.setLineWidth(2)

                    // оси
                    cg.move(to: CGPoint(x: left, y: 0)); cg.addLine(to: CGPoint(x: right, y: 0)); cg.strokePath()
                    cg.move(to: CGPoint(x: 0, y: top));  cg.addLine(to: CGPoint(x: 0, y: bottom)); cg.strokePath()

                    // риски
                    cg.setLineWidth(1.2)
                    let tick: CGFloat = 8
                    let startXi = Int(floor(left/spacing))
                    let endXi   = Int(ceil(right/spacing))
                    for i in startXi...endXi {
                        let x = CGFloat(i) * spacing
                        cg.move(to: CGPoint(x: x, y: -tick)); cg.addLine(to: CGPoint(x: x, y: tick))
                    }
                    cg.strokePath()

                    let startYi = Int(floor(top/spacing))
                    let endYi   = Int(ceil(bottom/spacing))
                    for j in startYi...endYi {
                        let y = CGFloat(j) * spacing
                        cg.move(to: CGPoint(x: -tick, y: y)); cg.addLine(to: CGPoint(x: tick, y: y))
                    }
                    cg.strokePath()

                    // крестик в (0,0)
                    cg.setLineWidth(1.2)
                    cg.move(to: CGPoint(x: -6, y: -6)); cg.addLine(to: CGPoint(x: 6, y: 6))
                    cg.move(to: CGPoint(x: -6, y: 6));  cg.addLine(to: CGPoint(x: 6, y: -6))
                    cg.strokePath()
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Lines

struct DrawingLine {
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

private extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x - rhs.width, y: lhs.y - rhs.height)
    }
}

// MARK: - State

class DrawingCanvasState: ObservableObject {
    // линии
    @Published var lines: [DrawingLine] = []
    @Published var currentLine: DrawingLine = DrawingLine(points: [], color: .blue, lineWidth: 2)

    // стиль
    @Published var selectedColor: Color = .blue
    @Published var lineWidth: Double = 2

    // режимы
    @Published var isEraserActive: Bool = false
    @Published var isMoveMode: Bool = false

    // вид
    @Published var offset: CGSize = .zero
    @Published var lastDragPosition: CGSize? = nil
    @Published var showAxes: Bool = true
    @Published var didCenterOnAppear: Bool = false

    // фигуры
    @Published var shapes: [ShapeModel] = []
    @Published var currentShape: ShapeModel? = nil
    @Published var selectedShapeTool: ShapeType? = nil
    @Published var selectedShapeIndex: Int? = nil // для поворота RT

    func clear() {
        lines = []
        shapes = []
        currentShape = nil
        selectedShapeTool = nil
        selectedShapeIndex = nil
        currentLine = DrawingLine(points: [], color: selectedColor, lineWidth: CGFloat(lineWidth))
        offset = .zero
        lastDragPosition = nil
        didCenterOnAppear = false
    }

    func undo() {
        if currentShape != nil { currentShape = nil; return }
        if !currentLine.points.isEmpty {
            currentLine = DrawingLine(points: [], color: selectedColor, lineWidth: CGFloat(lineWidth)); return
        }
        if !shapes.isEmpty { _ = shapes.removeLast(); selectedShapeIndex = nil; return }
        if !lines.isEmpty { _ = lines.removeLast(); return }
    }
}

// MARK: - Right Panel (без «карандаша»)

private struct RightSidePanel: View {
    let isLandscape: Bool
    let showAxes: Bool
    let onToggleAxes: () -> Void
    let onResetView: () -> Void
    let onUndo: () -> Void

    let selectedShape: ShapeType?
    let onSelectShape: (ShapeType?) -> Void

    var body: some View {
        let stack = VStack(spacing: 8) {
            sideFab(symbol: "arrow.uturn.backward", bg: .brown, action: onUndo)
            sideFab(symbol: "chart.xyaxis.line", bg: showAxes ? .green : .gray, action: onToggleAxes)
            sideFab(symbol: "scope", bg: .blue, action: onResetView)

            Divider().frame(width: 36)

            shapeBtn(systemSymbol: "circle",   selected: selectedShape == .circle)   { onSelectShape(.circle) }
            shapeBtn(systemSymbol: "square",   selected: selectedShape == .rect)     { onSelectShape(.rect) }
            shapeBtn(systemSymbol: "triangle", selected: selectedShape == .triangle) { onSelectShape(.triangle) }
            shapeBtnCustomRT(selected: selectedShape == .rightTriangle) { onSelectShape(.rightTriangle) }
        }
        .padding(6)
        .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))

        if isLandscape {
            ScrollView(.vertical, showsIndicators: true) { stack }.frame(maxHeight: .infinity)
        } else {
            stack
        }
    }

    private func sideFab(symbol: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .resizable().scaledToFit().frame(width: 18, height: 18)
                .foregroundColor(.white).padding(10)
        }
        .background(bg, in: Circle())
        .shadow(radius: 2)
    }

    private func shapeBtn(systemSymbol: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Image(systemName: systemSymbol)
                .resizable().scaledToFit().frame(width: 18, height: 18)
                .foregroundColor(.white).padding(10)
        }
        .background(selected ? Color.indigo : Color.gray, in: Circle())
        .shadow(radius: 2)
    }

    private func shapeBtnCustomRT(selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height, pad: CGFloat = 6
                Path { p in
                    p.move(to: CGPoint(x: pad, y: h - pad))
                    p.addLine(to: CGPoint(x: w - pad, y: h - pad))
                    p.addLine(to: CGPoint(x: pad, y: pad))
                    p.closeSubpath()
                }
                .stroke(Color.white, lineWidth: 2)
            }
            .frame(width: 38, height: 38)
        }
        .background(selected ? Color.indigo : Color.gray, in: Circle())
        .shadow(radius: 2)
    }
}

// MARK: - Bottom bar (compact in landscape)

private struct BottomBar: View {
    @ObservedObject var canvasState: DrawingCanvasState
    let isLandscape: Bool
    let canvasSize: CGSize

    var body: some View {
        HStack(spacing: isLandscape ? 8 : 10) {
            ColorPicker("", selection: $canvasState.selectedColor)
                .labelsHidden()

            // Короче слайдер в landscape
            HStack(spacing: 6) {

                Slider(value: $canvasState.lineWidth, in: 1...10, step: 1)
                    .frame(maxWidth: isLandscape ? 120 : 160)
                if !isLandscape {
                    Text("\(Int(canvasState.lineWidth))")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, alignment: .leading)
                }
            }

            Divider().frame(height: isLandscape ? 22 : 28)

            toolBtn(symbol: "pencil",
                    active: !canvasState.isEraserActive && !canvasState.isMoveMode && canvasState.selectedShapeTool == nil,
                    isLandscape: isLandscape) {
                canvasState.isEraserActive = false
                canvasState.isMoveMode = false
                canvasState.selectedShapeTool = nil
            }
            toolBtn(symbol: "pencil.slash",
                    active: canvasState.isEraserActive,
                    isLandscape: isLandscape) {
                canvasState.isEraserActive.toggle()
                canvasState.isMoveMode = false
                canvasState.selectedShapeTool = nil
            }
            Button {
                canvasState.clear()
            } label: {
                Image(systemName: "trash")
                    .resizable().scaledToFit()
                    .frame(width: isLandscape ? 16 : 20, height: isLandscape ? 16 : 20)
                    .padding(isLandscape ? 6 : 10)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            toolBtn(symbol: "arrow.up.and.down.and.arrow.left.and.right",
                    active: canvasState.isMoveMode,
                    isLandscape: isLandscape) {
                canvasState.isMoveMode.toggle()
                canvasState.isEraserActive = false
                canvasState.selectedShapeTool = nil
            }
        }
        .padding(isLandscape ? 6 : 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 5)
        .padding(.horizontal, isLandscape ? 6 : 8)
        .padding(.bottom, isLandscape ? 4 : 6)
    }

    @ViewBuilder
    private func toolBtn(symbol: String, active: Bool, isLandscape: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .resizable().scaledToFit()
                .frame(width: isLandscape ? 16 : 20, height: isLandscape ? 16 : 20)
                .padding(isLandscape ? 6 : 10)
                .foregroundColor(.white)
                .background(active ? Color.indigo : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Tap Selection (selects top-most shape by bbox; used for RT rotation buttons)

private struct ShapeTapSelectionModifier: ViewModifier {
    @ObservedObject var canvasState: DrawingCanvasState

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.simultaneousGesture(
                SpatialTapGesture().onEnded { e in
                    select(atScreen: e.location)
                }
            )
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if abs(value.translation.width) < 3 && abs(value.translation.height) < 3 {
                            select(atScreen: value.location)
                        }
                    }
            )
        }
    }

    private func select(atScreen p: CGPoint) {
        let world = CGPoint(x: p.x - canvasState.offset.width, y: p.y - canvasState.offset.height)
        if let idx = canvasState.shapes.indices.reversed().first(where: { i in
            let b = canvasState.shapes[i].bounds
            return world.x >= b.tl.x && world.x <= b.br.x &&
                   world.y >= b.tl.y && world.y <= b.br.y
        }) {
            canvasState.selectedShapeIndex = idx
        } else {
            canvasState.selectedShapeIndex = nil
        }
    }
}

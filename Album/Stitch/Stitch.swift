import SwiftUI
import UIKit

/// Welt „Kreuzstich“: Leinen, Garn und Stiche. Farbe steckt nur im Garn.
enum Stitch {
    static let linen = Color(red: 239/255, green: 230/255, blue: 210/255)
    static let card = Color(red: 251/255, green: 248/255, blue: 240/255)
    static let red = Color(red: 200/255, green: 50/255, blue: 43/255)
    static let cobalt = Color(red: 31/255, green: 63/255, blue: 140/255)
    static let mustard = Color(red: 214/255, green: 160/255, blue: 34/255)
    static let ink = Color(red: 28/255, green: 26/255, blue: 23/255)
    static let inkSoft = Color(red: 88/255, green: 80/255, blue: 68/255)

    /// Aida-Gewebe als Kachel: Garnbündel mit kleinen Löchern an den Kreuzungspunkten.
    static let linenTile: UIImage = {
        let cell: CGFloat = 6, count = 16
        let size = CGSize(width: cell * CGFloat(count), height: cell * CGFloat(count))
        var random = SeededRandom(seed: 7)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            UIColor(Stitch.linen).setFill(); cg.fill(CGRect(origin: .zero, size: size))
            for row in 0..<count {
                for column in 0..<count {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell).insetBy(dx: 0.55, dy: 0.55)
                    let lift = CGFloat(random.next(in: -0.035...0.045))
                    UIColor(white: 1, alpha: 0.30 + lift).setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 1.4).fill()
                    UIColor(white: 1, alpha: 0.22).setFill()
                    cg.fill(CGRect(x: rect.minX + 0.6, y: rect.minY + 0.5, width: rect.width - 1.8, height: 0.8))
                }
            }
            UIColor(red: 150/255, green: 132/255, blue: 104/255, alpha: 0.42).setFill()
            for row in 0...count {
                for column in 0...count {
                    cg.fillEllipse(in: CGRect(x: CGFloat(column) * cell - 0.75, y: CGFloat(row) * cell - 0.75, width: 1.5, height: 1.5))
                }
            }
            for _ in 0..<40 {
                let start = CGPoint(x: random.next(in: 0...Double(size.width)), y: random.next(in: 0...Double(size.height)))
                let path = UIBezierPath()
                path.move(to: start)
                path.addLine(to: CGPoint(x: start.x + random.next(in: -9...9), y: start.y + random.next(in: -2...2)))
                UIColor(red: 120/255, green: 100/255, blue: 70/255, alpha: 0.10).setStroke()
                path.lineWidth = 0.4; path.stroke()
            }
        }
    }()

    /// Ein Kreuzstich: erst „/“, dann „\“. `progress` 0…1 zeichnet beide Hälften nacheinander.
    static func drawCross(_ context: inout GraphicsContext, in rect: CGRect, color: Color, progress: CGFloat = 1) {
        guard progress > 0 else { return }
        let inset = rect.width * 0.12
        let r = rect.insetBy(dx: inset, dy: inset)
        let width = rect.width * 0.36
        let first = (CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.minY))
        let second = (CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY))
        drawThread(&context, from: first.0, to: first.1, amount: min(progress * 2, 1), color: color, width: width)
        if progress > 0.5 {
            drawThread(&context, from: second.0, to: second.1, amount: (progress - 0.5) * 2, color: color, width: width)
        }
    }

    /// Vorgedrucktes Muster für noch nicht Gesticktes.
    static func drawPrinted(_ context: inout GraphicsContext, in rect: CGRect) {
        let r = rect.insetBy(dx: rect.width * 0.22, dy: rect.width * 0.22)
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.maxY)); path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.move(to: CGPoint(x: r.minX, y: r.minY)); path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        context.stroke(path, with: .color(Stitch.ink.opacity(0.3)), lineWidth: max(0.8, rect.width * 0.1))
    }

    private static func drawThread(_ context: inout GraphicsContext, from a: CGPoint, to b: CGPoint, amount: CGFloat, color: Color, width: CGFloat) {
        let end = CGPoint(x: a.x + (b.x - a.x) * amount, y: a.y + (b.y - a.y) * amount)
        var path = Path(); path.move(to: a); path.addLine(to: end)
        let round = StrokeStyle(lineWidth: width, lineCap: .round)
        context.stroke(path.offsetBy(dx: width * 0.18, dy: width * 0.26), with: .color(.black.opacity(0.22)), style: round)
        context.stroke(path, with: .color(color), style: round)
        context.stroke(path.offsetBy(dx: -width * 0.12, dy: -width * 0.14), with: .color(.white.opacity(0.28)),
                       style: StrokeStyle(lineWidth: width * 0.34, lineCap: .round))
    }
}

struct LinenBackground: View {
    var body: some View {
        Image(uiImage: Stitch.linenTile).resizable(resizingMode: .tile).ignoresSafeArea()
    }
}

/// Ein Stickmuster: Kästchen mit Garnfarbe, in Stickreihenfolge.
struct StitchGrid {
    struct Cell { let x: Int; let y: Int; let color: Color }
    let columns: Int
    let rows: Int
    let cells: [Cell]

    /// Muster aus Textzeilen. Zeichen: `r` rot, `b` kobalt, `y` senf, `k` tinte, alles andere leer.
    init(pattern: [String]) {
        let width = pattern.map(\.count).max() ?? 0
        var cells: [Cell] = []
        for (y, line) in pattern.enumerated() {
            for (x, char) in line.enumerated() {
                let color: Color? = switch char {
                case "r": Stitch.red
                case "b": Stitch.cobalt
                case "y": Stitch.mustard
                case "k": Stitch.ink
                default: nil
                }
                if let color { cells.append(Cell(x: x, y: y, color: color)) }
            }
        }
        columns = width; rows = pattern.count
        self.cells = cells.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    }

    /// Muster aus einer Schrift oder einem SF Symbol, abgetastet auf ein Raster.
    init(rendering image: UIImage, rows: Int, color: Color) {
        let aspect = image.size.width / max(image.size.height, 1)
        let columns = max(1, Int((CGFloat(rows) * aspect).rounded()))
        let size = CGSize(width: columns, height: rows)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.preferredRange = .standard
        let small = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        var cells: [Cell] = []
        if let data = small.cgImage?.dataProvider?.data, let bytes = CFDataGetBytePtr(data), let cg = small.cgImage {
            let perRow = cg.bytesPerRow, perPixel = cg.bitsPerPixel / 8
            for y in 0..<rows {
                for x in 0..<columns where bytes[y * perRow + x * perPixel + (perPixel - 1)] > 110 {
                    cells.append(Cell(x: x, y: y, color: color))
                }
            }
        }
        self.columns = columns; self.rows = rows
        self.cells = cells.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    }

    private init(columns: Int, rows: Int, cells: [Cell]) {
        self.columns = columns; self.rows = rows; self.cells = cells
    }

    /// Entfernt leere Ränder, damit das Muster genau so groß ist wie seine Stiche.
    func trimmed() -> StitchGrid {
        guard let minX = cells.map(\.x).min(), let maxX = cells.map(\.x).max(),
              let minY = cells.map(\.y).min(), let maxY = cells.map(\.y).max() else { return self }
        return StitchGrid(columns: maxX - minX + 1, rows: maxY - minY + 1,
                          cells: cells.map { Cell(x: $0.x - minX, y: $0.y - minY, color: $0.color) })
    }

    static func text(_ string: String, rows: Int, color: Color) -> StitchGrid {
        let base = UIFont.systemFont(ofSize: 120, weight: .black)
        let font = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 120) } ?? base
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: UIColor.black])
        let width = attributed.size().width
        // Volle Zeilenhöhe inklusive Unterlänge, damit das „g“ nicht abgeschnitten wird.
        let size = CGSize(width: ceil(width) + 8, height: ceil(font.ascender - font.descender) + 8)
        let image = UIGraphicsImageRenderer(size: size).image { _ in attributed.draw(at: CGPoint(x: 4, y: 4)) }
        return StitchGrid(rendering: image, rows: rows, color: color).trimmed()
    }

    static func symbol(_ name: String, rows: Int, color: Color) -> StitchGrid {
        let config = UIImage.SymbolConfiguration(pointSize: 120, weight: .bold)
        let image = UIImage(systemName: name, withConfiguration: config)?.withTintColor(.black, renderingMode: .alwaysOriginal) ?? UIImage()
        return StitchGrid(rendering: image, rows: rows, color: color)
    }
}

/// Zeichnet ein Muster. `stitched` ist animierbar: Stiche entstehen Kästchen für Kästchen.
struct StitchPatternView: View, Animatable {
    let grid: StitchGrid
    var cell: CGFloat
    var stitched: Double
    var showPrinted = true

    var animatableData: Double {
        get { stitched }
        set { stitched = newValue }
    }

    init(_ grid: StitchGrid, cell: CGFloat, stitched: Double? = nil, showPrinted: Bool = true) {
        self.grid = grid; self.cell = cell; self.showPrinted = showPrinted
        self.stitched = stitched ?? Double(grid.cells.count)
    }

    var body: some View {
        Canvas { context, _ in
            for (index, item) in grid.cells.enumerated() {
                let rect = CGRect(x: CGFloat(item.x) * cell, y: CGFloat(item.y) * cell, width: cell, height: cell)
                let amount = CGFloat(stitched - Double(index))
                if amount >= 1 {
                    Stitch.drawCross(&context, in: rect, color: item.color)
                } else if amount > 0 {
                    if showPrinted { Stitch.drawPrinted(&context, in: rect) }
                    Stitch.drawCross(&context, in: rect, color: item.color, progress: amount)
                } else if showPrinted {
                    Stitch.drawPrinted(&context, in: rect)
                }
            }
        }
        .frame(width: CGFloat(grid.columns) * cell, height: CGFloat(grid.rows) * cell)
        .accessibilityHidden(true)
    }
}

/// Gestickte Überschrift.
struct StitchedText: View {
    let text: String
    var rows = 13
    var cell: CGFloat = 5
    var color = Stitch.red
    var body: some View {
        StitchPatternView(StitchGrid.text(text, rows: rows, color: color), cell: cell, showPrinted: false)
            .accessibilityElement().accessibilityLabel(text).accessibilityAddTraits(.isHeader)
    }
}

/// Kleines gesticktes Symbol.
struct StitchedSymbol: View {
    let name: String
    var rows = 11
    var cell: CGFloat = 2.4
    var color = Stitch.red
    var body: some View {
        StitchPatternView(StitchGrid.symbol(name, rows: rows, color: color), cell: cell, showPrinted: false)
    }
}

/// Zwei kleine Kreuze als „Heftstich“, der Fotos und Zettel am Stoff hält.
struct TackStitch: View {
    var color = Stitch.red
    var size: CGFloat = 12
    var body: some View {
        Canvas { context, canvasSize in
            Stitch.drawCross(&context, in: CGRect(origin: .zero, size: canvasSize), color: color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct StitchButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(primary ? Stitch.card : Stitch.red)
            .background(primary ? Stitch.red : Stitch.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Stitch.red, lineWidth: primary ? 0 : 1.5))
            .shadow(color: .black.opacity(primary ? 0.18 : 0.06), radius: primary ? 6 : 3, y: primary ? 3 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return range.lowerBound + Double(state % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
    }
}

extension String {
    /// Stabiler Wert −1…1 aus einer ID, z. B. für die Schräglage eines Fotos.
    var stableTilt: Double {
        let sum = unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1000 }
        return Double(sum) / 500 - 1
    }
}

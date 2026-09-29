import SwiftUI
import UIKit

/// Welt „Kreuzstich“: Leinen, Garn und Stiche. Farbe steckt nur im Garn.
enum Stitch {
    // Hell: ungefärbtes Leinen. Dunkel: indigogefärbtes Leinen, die Garne etwas heller.
    static let linen = dynamic(light: (239, 230, 210), dark: (29, 33, 48))
    static let card = dynamic(light: (251, 248, 240), dark: (41, 46, 64))
    /// Rot als Schrift und Garn. Auf Leinen und Karte mindestens 4,5:1 in beiden Modi.
    static let red = dynamic(light: (184, 42, 36), dark: (245, 122, 108))
    /// Rot als Fläche (Knöpfe, ausgewählte Chips) mit heller Schrift darauf, mindestens 5,8:1.
    static let redFill = dynamic(light: (184, 42, 36), dark: (178, 48, 40))
    static let cobalt = dynamic(light: (31, 63, 140), dark: (128, 162, 238))
    static let mustard = dynamic(light: (214, 160, 34), dark: (238, 192, 84))
    static let ink = dynamic(light: (28, 26, 23), dark: (242, 236, 222))
    static let inkSoft = dynamic(light: (88, 80, 68), dark: (186, 178, 162))
    /// Dunkles Garn für Öffnungen im Stickbild, unabhängig vom Modus.
    static let opening = Color(red: 28/255, green: 26/255, blue: 23/255)
    /// Schrift auf `redFill`: in beiden Modi hell.
    static let onAccent = Color(red: 251/255, green: 248/255, blue: 240/255)

    static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
        })
    }

    /// Abstände im 8-Punkt-Raster. `page` ist der Seitenrand überall.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let page: CGFloat = 16
    }

    /// Eckenradien, immer mit kontinuierlicher Kurve.
    enum Radius {
        static let thumb: CGFloat = 8
        static let card: CGFloat = 16
        static let floating: CGFloat = 24
    }

    /// Drei Höhenstufen: flach (keine), angeheftet (Papier auf Stoff), schwebend (über der Karte).
    enum Elevation {
        case flat, pinned, floating
        var opacity: Double { switch self { case .flat: 0; case .pinned: 0.14; case .floating: 0.18 } }
        var radius: CGFloat { switch self { case .flat: 0; case .pinned: 5; case .floating: 14 } }
        var y: CGFloat { switch self { case .flat: 0; case .pinned: 3; case .floating: 6 } }
    }

    /// Feste Größen: Tippfläche nach Apple (44), Hauptknopf, Vorschaubild in Listen.
    enum Size {
        static let touch: CGFloat = 44
        static let button: CGFloat = 56
        static let thumb: CGFloat = 44
    }

    /// Einheitliche Größe für Heftstiche.
    static let tackSize: CGFloat = 12

    static func linenTile(dark: Bool) -> UIImage { dark ? darkTile : lightTile }
    private static let lightTile = makeTile(dark: false)
    private static let darkTile = makeTile(dark: true)

    /// Aida-Gewebe als Kachel: Garnbündel mit kleinen Löchern an den Kreuzungspunkten.
    private static func makeTile(dark: Bool) -> UIImage {
        let cell: CGFloat = 6, count = 16
        let size = CGSize(width: cell * CGFloat(count), height: cell * CGFloat(count))
        var random = SeededRandom(seed: 7)
        let base = dark ? UIColor(red: 29/255, green: 33/255, blue: 48/255, alpha: 1) : UIColor(red: 239/255, green: 230/255, blue: 210/255, alpha: 1)
        let lift = dark ? 0.035 : 0.30
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            base.setFill(); cg.fill(CGRect(origin: .zero, size: size))
            for row in 0..<count {
                for column in 0..<count {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell).insetBy(dx: 0.55, dy: 0.55)
                    let jitter = CGFloat(random.next(in: -0.035...0.045))
                    UIColor(white: 1, alpha: lift + jitter * (dark ? 0.4 : 1)).setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 1.4).fill()
                    UIColor(white: 1, alpha: dark ? 0.025 : 0.22).setFill()
                    cg.fill(CGRect(x: rect.minX + 0.6, y: rect.minY + 0.5, width: rect.width - 1.8, height: 0.8))
                }
            }
            (dark ? UIColor(white: 0, alpha: 0.22) : UIColor(red: 150/255, green: 132/255, blue: 104/255, alpha: 0.42)).setFill()
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
                (dark ? UIColor(white: 1, alpha: 0.05) : UIColor(red: 120/255, green: 100/255, blue: 70/255, alpha: 0.10)).setStroke()
                path.lineWidth = 0.4; path.stroke()
            }
        }
    }

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
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Image(uiImage: Stitch.linenTile(dark: scheme == .dark)).resizable(resizingMode: .tile).ignoresSafeArea()
    }
}

extension View {
    /// Einheitliche Karte: Innenabstand 16, Radius 16, Kartenfläche, wahlweise mit Schatten.
    func stitchCard(_ elevation: Stitch.Elevation = .flat, padding: CGFloat = Stitch.Space.m) -> some View {
        self.padding(padding)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .stitchElevation(elevation)
    }

    func stitchElevation(_ elevation: Stitch.Elevation) -> some View {
        shadow(color: .black.opacity(elevation.opacity), radius: elevation.radius, y: elevation.y)
    }
}

/// Gestrichelte Trennlinie (Perforation), überall gleich.
struct PerforationLine: View {
    var body: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay(HLine().stroke(Stitch.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .accessibilityHidden(true)
    }
    private struct HLine: Shape {
        func path(in rect: CGRect) -> Path { Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.width, y: rect.midY)) } }
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
                case "k": Stitch.opening // Öffnungen (Fenster, Tor) bleiben in beiden Modi dunkel
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
    var size: CGFloat = Stitch.tackSize
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
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.button)
            .foregroundStyle(primary ? Stitch.onAccent : Stitch.red)
            .background(primary ? Stitch.redFill : Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.red, lineWidth: primary ? 0 : 1.5))
            .stitchElevation(primary ? .pinned : .flat)
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

import SwiftUI
import UIKit

/// Welt „Papier & Marke“: flaches Papier, dunkle Tinte, Burgunder als einzige Aktionsfarbe.
/// Die Namen bleiben wie gewachsen (`Stitch`, `LinenBackground`, `stitchCard`, `StitchButton`),
/// nur ihr Aussehen ist neu. Die Rituale (Briefkasten, Einladung) sticken weiter und nutzen
/// dafür `TackStitch`, `StitchedText` und `StitchPatternView`; die Hauptbildschirme nicht mehr.
enum Stitch {
    /// Seitengrund: ruhiges, flaches Papier. Nachts warmes Dunkelbraun, kein Blaustich.
    static let linen = dynamic(light: (245, 242, 236), dark: (26, 23, 21))
    /// Karten, Felder, Knöpfe ohne Füllung: einen Hauch heller als der Grund, dazu eine Haarlinie.
    static let card = dynamic(light: (254, 253, 250), dark: (38, 34, 32))
    /// Haarlinie: Kontur von Karten, Feldern, Chips und Trennern.
    static let rule = dynamic(light: (225, 219, 208), dark: (60, 54, 50))
    /// Burgunder als Schrift (Links, Textknöpfe, Hinweise). Auf Papier und Karte mindestens 6:1 in beiden Modi.
    static let red = dynamic(light: (159, 52, 56), dark: (225, 137, 139))
    /// Burgunder als Fläche (Hauptknopf, gewählter Filter) mit heller Schrift darauf, mindestens 6,5:1.
    static let redFill = dynamic(light: (159, 52, 56), dark: (142, 48, 52))
    /// Zweiter, kühler Akzent: Besucht-Siegel, zweiter Tagesfaden auf der Karte. Nie für Hauptaktionen.
    static let cobalt = dynamic(light: (59, 85, 116), dark: (157, 182, 212))
    static let ink = dynamic(light: (36, 33, 30), dark: (243, 239, 232))
    static let inkSoft = dynamic(light: (107, 100, 89), dark: (176, 167, 156))
    /// Hinter dem Vollbildfoto, in beiden Modi dunkel.
    static let scrim = Color(red: 20/255, green: 18/255, blue: 16/255)
    static let opening = scrim
    /// Schrift auf `redFill`: in beiden Modi hell.
    static let onAccent = Color(red: 251/255, green: 247/255, blue: 241/255)

    static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
        })
    }

    /// Abstände: 4, 8, 12, 16, 24, 32, 48. `page` ist der Seitenrand und bewusst kein Rasterwert:
    /// 20 gibt Text und Karten Luft zum Bildschirmrand, ohne die Rhythmen im Inneren zu verschieben.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let page: CGFloat = 20
    }

    /// Eckenradien, immer mit kontinuierlicher Kurve.
    enum Radius {
        static let thumb: CGFloat = 12
        static let card: CGFloat = 20
        /// Blätter und große schwebende Flächen.
        static let sheet: CGFloat = 28
        static let floating = sheet
    }

    /// Drei Höhenstufen, bewusst flach: Ruhende Flächen trennt die Haarlinie, nicht der Schatten.
    enum Elevation {
        case flat, pinned, floating
        var opacity: Double { switch self { case .flat: 0; case .pinned: 0.07; case .floating: 0.12 } }
        var radius: CGFloat { switch self { case .flat: 0; case .pinned: 4; case .floating: 14 } }
        var y: CGFloat { switch self { case .flat: 0; case .pinned: 1; case .floating: 5 } }
    }

    /// Feste Größen: Tippfläche nach Apple (44), Hauptknopf (52), Vorschaubild in kompakten Zeilen (56).
    enum Size {
        static let touch: CGFloat = 44
        static let button: CGFloat = 52
        static let thumb: CGFloat = 56
    }

    /// Bewegung: kurze Dauern, zwei Federn, nichts darüber. `maybe` nimmt „Bewegung reduzieren“ mit.
    enum Motion {
        /// Farbe, Deckkraft, Auswahl.
        static let quick = 0.18
        /// Inhalt, der sich umbaut.
        static let settle = 0.28
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.78)
        static let snap = Animation.spring(response: 0.30, dampingFraction: 0.80)
        static let sheet = Animation.spring(response: 0.38, dampingFraction: 0.86)
        static func maybe(_ reduceMotion: Bool, _ animation: Animation) -> Animation? { reduceMotion ? nil : animation }
    }

    /// Einheitliche Größe für Heftstiche (nur noch in den Ritualen).
    static let tackSize: CGFloat = 12

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

/// Grund jeder Seite: flaches Papier. Der Name bleibt, die Gewebe-Kachel ist fort.
struct LinenBackground: View {
    var body: some View {
        Stitch.linen.ignoresSafeArea()
    }
}

extension View {
    /// Einheitliche Karte: Innenabstand 16, Radius 20, Papierfläche, Haarlinie, wahlweise mit Schatten.
    func stitchCard(_ elevation: Stitch.Elevation = .flat, padding: CGFloat = Stitch.Space.m) -> some View {
        let shape = RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous)
        return self.padding(padding)
            .background(Stitch.card, in: shape)
            .overlay(shape.strokeBorder(Stitch.rule, lineWidth: 1))
            .stitchElevation(elevation)
    }

    func stitchElevation(_ elevation: Stitch.Elevation) -> some View {
        shadow(color: .black.opacity(elevation.opacity), radius: elevation.radius, y: elevation.y)
    }

    /// Textknopf ohne Fläche: Burgunder, mindestens 44 hoch (Route, Tag ändern, Bearbeiten).
    func albumTextAction() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(Stitch.red)
            .frame(minHeight: Stitch.Size.touch)
    }
}

/// Gestrichelte Trennlinie (Perforation), überall gleich.
struct PerforationLine: View {
    var body: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay(HLine().stroke(Stitch.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .accessibilityHidden(true)
    }
    private struct HLine: Shape {
        func path(in rect: CGRect) -> Path { Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.width, y: rect.midY)) } }
    }
}

/// Umriss einer Briefmarke: runde Ecken, dazu sparsame Zähne an allen vier Kanten.
/// Mit `FillStyle(eoFill: true)` geclippt schneiden die Zähne kleine Kerben in die Fläche.
struct StampBorder: Shape {
    var radius: CGFloat = Stitch.Radius.thumb
    var tooth: CGFloat = 3
    var spacing: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        func notches(along length: CGFloat, at point: (CGFloat) -> CGPoint) {
            let usable = length - radius * 2
            guard usable > spacing else { return }
            let count = max(1, Int(usable / spacing))
            let step = usable / CGFloat(count)
            for index in 0...count {
                let center = point(radius + step * CGFloat(index))
                path.addEllipse(in: CGRect(x: center.x - tooth, y: center.y - tooth, width: tooth * 2, height: tooth * 2))
            }
        }
        notches(along: rect.width) { CGPoint(x: rect.minX + $0, y: rect.minY) }
        notches(along: rect.width) { CGPoint(x: rect.minX + $0, y: rect.maxY) }
        notches(along: rect.height) { CGPoint(x: rect.minX, y: rect.minY + $0) }
        notches(along: rect.height) { CGPoint(x: rect.maxX, y: rect.minY + $0) }
        return path
    }
}

/// Ein Foto wie eine Marke: die Zähne kerben die Kante aus, dahinter scheint die Karte durch.
/// Ersetzt das frühere Polaroid mit Heftstich und Schräglage.
struct StampPhoto: View {
    var asset: PlaceImageAsset?
    var root: URL? = nil
    var thumbnailWidth: Int? = nil
    var tooth: CGFloat = 3
    var spacing: CGFloat = 18
    var body: some View {
        AlbumPhoto(asset: asset, root: root, thumbnailWidth: thumbnailWidth)
            .clipShape(StampBorder(tooth: tooth, spacing: spacing), style: FillStyle(eoFill: true))
    }
}

/// Abschnittsüberschrift, überall gleich: optional ein Burgunder-Hinweis davor („Heute“),
/// rechts eine leise Zweitangabe. 12 Abstand zum Inhalt setzt der Aufrufer.
struct AlbumSectionHeader: View {
    let title: String
    var highlight: String? = nil
    var detail: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Stitch.Space.xs) {
            if let highlight {
                Text(highlight).font(.headline).foregroundStyle(Stitch.red)
            }
            Text(title).font(.headline).foregroundStyle(Stitch.ink)
            Spacer(minLength: 0)
            if !detail.isEmpty {
                Text(detail).font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Ein Ort als kompakte Zeile: Vorschaubild 56, Name, Zweitzeile, optional eine Notiz.
/// Die ganze Zeile ist die Hauptaktion; Nebenaktionen setzt der Aufrufer daneben.
struct AlbumPlaceRow: View {
    let title: String
    var meta: String = ""
    var note: String = ""
    var asset: PlaceImageAsset? = nil
    var root: URL? = nil
    /// Nummer im Tagesplan.
    var index: Int? = nil
    var visited = false
    /// Zweitzeile in Burgunder, wenn sie einen Hinweis trägt („hat dann zu“).
    var metaHighlighted = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Stitch.Space.s) {
                AlbumPhoto(asset: asset, root: root, thumbnailWidth: 120)
                    .frame(width: Stitch.Size.thumb, height: Stitch.Size.thumb)
                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous).strokeBorder(Stitch.rule, lineWidth: 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: Stitch.Space.xs) {
                        if let index {
                            Text("\(index)").font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundStyle(Stitch.inkSoft).accessibilityHidden(true)
                        }
                        Text(title).font(.headline).foregroundStyle(Stitch.ink)
                            .multilineTextAlignment(.leading).lineLimit(2)
                        if visited {
                            Image(systemName: "checkmark.seal.fill").font(.footnote)
                                .foregroundStyle(Stitch.cobalt).accessibilityLabel("Besucht")
                        }
                    }
                    if !meta.isEmpty {
                        Text(meta).font(.subheadline).foregroundStyle(metaHighlighted ? Stitch.red : Stitch.inkSoft)
                    }
                    if !note.isEmpty {
                        Text(note).font(.footnote).foregroundStyle(Stitch.inkSoft).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Hauptknopf (gefüllt, Burgunder) und Nebenknopf (Papier mit Haarlinie). Gleiche Höhe, gleiche Form.
/// `loading` zeigt einen Spinner vor der Beschriftung; gesperrt wird der Knopf von außen (`.disabled`).
struct StitchButton: ButtonStyle {
    var primary = false
    var loading = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous)
        return HStack(spacing: Stitch.Space.xs) {
            if loading {
                ProgressView().controlSize(.small).tint(primary ? Stitch.onAccent : Stitch.red)
            }
            configuration.label
        }
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Stitch.Space.m)
        .padding(.vertical, Stitch.Space.s)
        .frame(maxWidth: .infinity, minHeight: Stitch.Size.button, alignment: .center)
        .foregroundStyle(primary ? Stitch.onAccent : Stitch.ink)
        .background(primary ? Stitch.redFill : Stitch.card, in: shape)
        .overlay(shape.fill(Stitch.ink.opacity(configuration.isPressed ? 0.06 : 0)))
        .overlay(shape.strokeBorder(primary ? Color.clear : Stitch.rule, lineWidth: 1))
        .opacity(enabled ? 1 : 0.4)
        .contentShape(shape)
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
        .animation(Stitch.Motion.maybe(reduceMotion, Stitch.Motion.press), value: configuration.isPressed)
    }
}

/// Runder Knopf nur mit Symbol, 44 × 44: Papier, Haarlinie, Tinte.
struct HeaderIconButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            .background(Stitch.card, in: Circle())
            .overlay(Circle().strokeBorder(Stitch.rule, lineWidth: 1))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(Stitch.Motion.maybe(reduceMotion, Stitch.Motion.press), value: configuration.isPressed)
    }
}

/// Ein Stickmuster: Kästchen mit Garnfarbe, in Stickreihenfolge. Nur noch für die Rituale.
struct StitchGrid {
    struct Cell { let x: Int; let y: Int; let color: Color }
    let columns: Int
    let rows: Int
    let cells: [Cell]

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

/// Gestickte Überschrift. Nur noch in den Ritualen (Einladung); die Hauptbildschirme setzen Serifenschrift.
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

/// Kleines Symbol in der Größe, die früher ein Stickbild hatte (`rows` × `cell`), jetzt als SF Symbol.
/// Der Name bleibt, damit Aufrufer außerhalb des Redesigns unverändert bleiben und doch nativ aussehen.
struct StitchedSymbol: View {
    let name: String
    var rows = 11
    var cell: CGFloat = 2.4
    var color = Stitch.red
    private var side: CGFloat { CGFloat(rows) * cell }
    var body: some View {
        Image(systemName: name)
            .font(.system(size: side * 0.82, weight: .regular))
            .foregroundStyle(color)
            .frame(height: side)
            .accessibilityHidden(true)
    }
}

/// Zwei kleine Kreuze als „Heftstich“. Nur noch in den Ritualen (Briefkasten, Einladung, Bordkarte).
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

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return range.lowerBound + Double(state % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
    }
}

extension String {
    /// Stabiler Wert −1…1 aus einer ID, z. B. für die Reihenfolge kleiner Verzögerungen.
    var stableTilt: Double {
        let sum = unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1000 }
        return Double(sum) / 500 - 1
    }
}

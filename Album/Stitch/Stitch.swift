import SwiftUI
import UIKit

/// Welt „Briefmarke“: ruhiges Papier, Tinte, Poststempel. Jeder Ort ist eine Marke mit Pastellrand je Kategorie.
/// Quelle der Werte: Figma „Album Foundations“ (Datei BvFJ4PzwQXAxhPlrEw73rB). Der Name `Stitch` bleibt aus Gründen
/// der Verträglichkeit; gestickt wird nichts mehr.
enum Stitch {
    // MARK: Farben (Hell / Dunkel)

    static let paper = dynamic(light: (244, 239, 228), dark: (26, 23, 20))
    static let paperDeep = dynamic(light: (232, 223, 208), dark: (42, 37, 32))
    /// Markenweiß: Karten, Marken, Felder.
    static let card = dynamic(light: (251, 248, 242), dark: (37, 33, 29))
    static let rule = dynamic(light: (221, 211, 194), dark: (62, 56, 49))
    static let ink = dynamic(light: (28, 25, 21), dark: (242, 237, 227))
    static let inkSoft = dynamic(light: (107, 100, 92), dark: (181, 172, 160))
    /// Poststempel als Schrift und Linie. Auf Papier 4,7:1, auf Karte 5,1:1.
    static let red = dynamic(light: (182, 69, 50), dark: (236, 134, 114))
    /// Poststempel als Fläche, helle Schrift darauf mindestens 5,2:1.
    static let redFill = dynamic(light: (182, 69, 50), dark: (166, 61, 44))
    /// Zweite Tinte: Besucht, Hinweise, zweite Route.
    static let teal = dynamic(light: (61, 92, 90), dark: (141, 179, 175))
    /// Nur Zierde (Stempelring, Sterne), nie Schrift.
    static let gold = dynamic(light: (196, 165, 116), dark: (214, 186, 138))
    static let onAccent = Color(red: 251 / 255, green: 248 / 255, blue: 242 / 255)
    /// Hintergrund hinter Vollbildfotos, in beiden Modi dunkel.
    static let scrim = Color(red: 20 / 255, green: 18 / 255, blue: 16 / 255)

    /// Pastellränder der Marken, fest je Kategorie. Nie für Schrift.
    enum Mat {
        static let rose = dynamic(light: (240, 206, 198), dark: (94, 62, 57))
        static let sky = dynamic(light: (203, 221, 235), dark: (52, 71, 88))
        static let butter = dynamic(light: (242, 227, 178), dark: (88, 78, 47))
        static let mint = dynamic(light: (207, 227, 209), dark: (50, 73, 58))
        static let lilac = dynamic(light: (221, 211, 235), dark: (67, 59, 86))
    }

    static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
        })
    }

    // MARK: Schrift

    /// Fraunces für Titel, Instrument Serif für Ortsnamen, SF für alles Lesbare, SF Mono für Codes und Zeiten.
    /// Alle wachsen mit Dynamic Type.
    enum Face {
        static func display(_ size: CGFloat = 34, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
            .custom("Fraunces-SemiBold", size: size, relativeTo: style)
        }
        static func title(_ size: CGFloat = 22, relativeTo style: Font.TextStyle = .title2) -> Font {
            .custom("Fraunces-SemiBold", size: size, relativeTo: style)
        }
        static func place(_ size: CGFloat = 22, relativeTo style: Font.TextStyle = .title2) -> Font {
            .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
        }
        static let ticket = Font.system(.footnote, design: .monospaced).weight(.medium)
        static func code(_ style: Font.TextStyle) -> Font { Font.system(style, design: .monospaced).weight(.medium) }
    }

    // MARK: Maße

    /// Abstände in Punkten; `page` ist der Seitenrand überall.
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

    /// Eckenradien, immer mit kontinuierlicher Kurve. Marken haben fast keine Ecke.
    enum Radius {
        static let stamp: CGFloat = 4
        static let thumb: CGFloat = 10
        static let card: CGFloat = 18
        static let floating: CGFloat = 26
    }

    /// Drei Höhen: flach, aufgeklebt (Marke auf Papier), schwebend (über der Karte).
    enum Elevation {
        case flat, pinned, floating
        var opacity: Double { switch self { case .flat: 0; case .pinned: 0.10; case .floating: 0.16 } }
        var radius: CGFloat { switch self { case .flat: 0; case .pinned: 6; case .floating: 18 } }
        var y: CGFloat { switch self { case .flat: 0; case .pinned: 3; case .floating: 8 } }
    }

    /// Feste Größen: Tippfläche nach Apple, Hauptknopf, Vorschaubild.
    enum Size {
        static let touch: CGFloat = 44
        static let button: CGFloat = 52
        static let thumb: CGFloat = 48
    }

    /// Warme Schattenfarbe statt Schwarz, damit Marken auf Papier liegen statt zu schweben.
    static let shadow = Color(red: 0.24, green: 0.17, blue: 0.10)
}

// MARK: Flächen

struct PaperBackground: View {
    var body: some View { Stitch.paper.ignoresSafeArea() }
}

extension View {
    /// Einheitliche Karte: Markenweiß, Radius 18, feine Kontur; wahlweise mit Schatten.
    func stitchCard(_ elevation: Stitch.Elevation = .flat, padding: CGFloat = Stitch.Space.m) -> some View {
        self.padding(padding)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous)
                .strokeBorder(Stitch.rule, lineWidth: elevation == .flat ? 1 : 0))
            .stitchElevation(elevation)
    }

    func stitchElevation(_ elevation: Stitch.Elevation) -> some View {
        shadow(color: Stitch.shadow.opacity(elevation.opacity), radius: elevation.radius, y: elevation.y)
    }
}

/// Gepunktete Trennlinie (Perforation), überall gleich.
struct PerforationLine: View {
    var color = Stitch.rule
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 2
            while x < size.width {
                context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: size.height / 2 - 1.5, width: 3, height: 3)), with: .color(color))
                x += 7
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

// MARK: Marke

/// Rechteck mit Zähnung: an allen Kanten halbrunde Bisse in gleichem Abstand, an den Ecken ausgerichtet.
struct StampShape: Shape {
    var hole: CGFloat = 2.6
    var pitch: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var holes = Path()
        func bite(along length: CGFloat, at point: (CGFloat) -> CGPoint) {
            let count = max(2, Int((length / pitch).rounded()))
            let step = length / CGFloat(count)
            for index in 0..<count {
                let center = point(step * (CGFloat(index) + 0.5))
                holes.addEllipse(in: CGRect(x: center.x - hole, y: center.y - hole, width: hole * 2, height: hole * 2))
            }
        }
        bite(along: rect.width) { CGPoint(x: rect.minX + $0, y: rect.minY) }
        bite(along: rect.width) { CGPoint(x: rect.minX + $0, y: rect.maxY) }
        bite(along: rect.height) { CGPoint(x: rect.minX, y: rect.minY + $0) }
        bite(along: rect.height) { CGPoint(x: rect.maxX, y: rect.minY + $0) }
        return Path(rect).subtracting(holes)
    }
}

/// Ein Foto als Briefmarke: gezähntes Markenweiß, darin der Pastellrand der Kategorie, darin das Bild.
struct StampFrame<Content: View>: View {
    var mat: Color = Stitch.paperDeep
    var inset: CGFloat = 7
    var matWidth: CGFloat = 4
    var elevation: Stitch.Elevation = .pinned
    @ViewBuilder var content: Content

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .padding(matWidth)
            .background(mat, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .padding(inset)
            .background(Stitch.card)
            .clipShape(StampShape())
            .compositingGroup()
            .stitchElevation(elevation)
    }
}

/// Ticket: Karte mit zwei halbrunden Kerben an der Abrisskante. `stub` ist die Breite des Abschnitts rechts.
struct TicketShape: Shape {
    var stub: CGFloat
    var notch: CGFloat = 9
    var radius: CGFloat = Stitch.Radius.thumb

    func path(in rect: CGRect) -> Path {
        let x = rect.maxX - stub
        let notches = Path { path in
            path.addEllipse(in: CGRect(x: x - notch, y: rect.minY - notch, width: notch * 2, height: notch * 2))
            path.addEllipse(in: CGRect(x: x - notch, y: rect.maxY - notch, width: notch * 2, height: notch * 2))
        }
        return Path(roundedRect: rect, cornerRadius: radius, style: .continuous).subtracting(notches)
    }
}

/// Runder Poststempel: Ring mit Ortsname und Datum, leicht schräg aufgedrückt.
struct Postmark: View {
    var top = "PRAHA"
    var bottom: String
    var color = Stitch.red
    var size: CGFloat = 76
    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: 2)
            Circle().strokeBorder(color.opacity(0.7), lineWidth: 1).padding(5)
            VStack(spacing: 1) {
                Text(top).font(.system(size: size * 0.15, weight: .bold, design: .monospaced)).tracking(1.5)
                Rectangle().fill(color).frame(width: size * 0.5, height: 1)
                Text(bottom).font(.system(size: size * 0.13, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-12))
        .accessibilityHidden(true)
    }
}

// MARK: Kategorien

extension Place {
    /// Pastellrand der Marke.
    var mat: Color {
        switch category {
        case "Essen & Trinken": Stitch.Mat.rose
        case "Sehenswert": Stitch.Mat.sky
        case "Aussicht": Stitch.Mat.butter
        case "Unterkunft": Stitch.Mat.lilac
        case "Shopping": Stitch.Mat.mint
        default: Stitch.paperDeep
        }
    }

    var symbol: String {
        switch category {
        case "Essen & Trinken": "fork.knife"
        case "Sehenswert": "building.columns"
        case "Aussicht": "binoculars"
        case "Unterkunft": "bed.double"
        case "Shopping": "bag"
        default: "sparkle"
        }
    }
}

// MARK: Knöpfe

/// Hauptknopf als Pille (Poststempel), Nebenknopf als helle Pille mit Kontur.
struct StitchButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.button)
            .padding(.horizontal, Stitch.Space.m)
            .foregroundStyle(primary ? Stitch.onAccent : Stitch.ink)
            .background(primary ? Stitch.redFill : Stitch.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Stitch.rule, lineWidth: primary ? 0 : 1))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Runder Knopf nur mit Symbol, 44 × 44.
struct HeaderIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            .background(Stitch.card, in: Circle())
            .overlay(Circle().strokeBorder(Stitch.rule, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Stille Textaktion in Poststempel-Rot, 44 hoch.
struct TextActionButton: ButtonStyle {
    var tint = Stitch.red
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            .frame(minHeight: Stitch.Size.touch)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

/// Abschnittsüberschrift: Fraunces links, optional eine Zahl oder Aktion rechts.
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Stitch.Face.title(22, relativeTo: .title3)).foregroundStyle(Stitch.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Stitch.Space.s)
            trailing
        }
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) { self.title = title; self.trailing = EmptyView() }
}

// MARK: Hilfen

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return range.lowerBound + Double(state % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
    }
}

extension String {
    /// Stabiler Wert −1…1 aus einer ID.
    var stableTilt: Double {
        let sum = unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1000 }
        return Double(sum) / 500 - 1
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}

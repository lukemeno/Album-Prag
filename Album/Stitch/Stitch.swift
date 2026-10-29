import SwiftUI
import UIKit

/// Welt „Briefmarke“: warmes Papier, Tinte, roter Poststempel. Jeder Ort ist eine Marke mit Pastellrand je Kategorie.
/// Quelle der Werte: Figma „Briefmarke“. Der Name `Stitch` bleibt aus Gründen der Verträglichkeit; gestickt wird nichts mehr.
enum Stitch {
    // MARK: Farben (Hell / Nacht)

    /// App-Fläche: das warme Papier, auf dem die Marken liegen.
    static let paper = dynamic(light: (245, 242, 236), dark: (28, 27, 31))
    /// Karten und Felder: weißes Markenpapier auf der App-Fläche.
    static let card = dynamic(light: (255, 255, 255), dark: (42, 40, 48))
    /// Feine Linien und Perforation.
    static let line = dynamic(light: (230, 224, 214), dark: (58, 56, 66))
    /// Tinte: Haupttext.
    static let ink = dynamic(light: (28, 26, 23), dark: (242, 238, 230))
    /// Zweite Tinte: Nebentext, Hinweise.
    static let inkSoft = dynamic(light: (107, 100, 90), dark: (181, 174, 163))
    /// Auswahlfläche (gewählter Tag, gewählter Ort): Himmelblau, im Dunkeln ein gedämpftes Blau.
    static let selection = dynamic(light: (207, 224, 245), dark: (52, 62, 84))
    /// Poststempel-Rot als Schrift, Symbol und Linie.
    static let action = dynamic(light: (184, 42, 36), dark: (245, 122, 108))
    /// Poststempel-Rot als Fläche; Schrift darauf ist `onAction`.
    static let actionFill = dynamic(light: (184, 42, 36), dark: (178, 48, 40))
    /// Schrift und Symbol auf `actionFill`, in beiden Modi weiß.
    static let onAction = Color.white
    /// Hintergrund hinter Vollbildfotos, in beiden Modi dunkel.
    static let scrim = Color(red: 20 / 255, green: 18 / 255, blue: 16 / 255)

    /// Pastellränder der Marken, fest je Kategorie, in beiden Modi gleich. Nie für Schrift.
    enum Stamp {
        /// Essen & Trinken
        static let rose = rgb(246, 201, 207)
        /// Sehenswert
        static let sky = rgb(207, 224, 245)
        /// Aussicht
        static let butter = rgb(247, 227, 166)
        /// Shopping
        static let mint = rgb(205, 235, 217)
        /// Unterkunft
        static let lilac = rgb(227, 213, 242)
        /// Zettel
        static let note = rgb(251, 231, 161)
        /// Schrift und Symbole auf Markenfarben: feste Tinte, in beiden Modi dunkel.
        static let ink = rgb(28, 26, 23)
        static let inkSoft = rgb(107, 100, 90)
    }

    fileprivate static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
        })
    }

    // MARK: Schrift

    /// Nur SF (System), alles wächst mit Dynamic Type. `size` ist die Grundgröße, `style` die Skalierungsbasis.
    enum Face {
        private static func scaled(_ size: CGFloat, _ weight: UIFont.Weight, _ style: Font.TextStyle) -> Font {
            Font(UIFontMetrics(forTextStyle: style.uiStyle).scaledFont(for: .systemFont(ofSize: size, weight: weight)))
        }

        /// Hero-Titel, 34 bold.
        static func display(_ size: CGFloat = 34, relativeTo style: Font.TextStyle = .largeTitle) -> Font { scaled(size, .bold, style) }
        /// Seitentitel, 28 bold.
        static func title(_ size: CGFloat = 28, relativeTo style: Font.TextStyle = .title) -> Font { scaled(size, .bold, style) }
        /// Abschnittstitel, 20 semibold.
        static let section = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption.weight(.medium)
        /// Ortsname auf Marke und Karte.
        static func place(_ size: CGFloat = 22, relativeTo style: Font.TextStyle = .title2) -> Font { scaled(size, .semibold, style) }
        static func wordmark(_ size: CGFloat = 28, relativeTo style: Font.TextStyle = .title) -> Font { scaled(size, .bold, style) }
        /// Handschriftlicher Zettel, Caveat 24. Solange die Schrift fehlt (Datei nicht im Bundle), fällt sie auf SF kursiv zurück.
        static var note: Font {
            if UIFont(name: "Caveat-Regular", size: 24) != nil { return .custom("Caveat-Regular", size: 24, relativeTo: .title3) }
            return .system(.title3).italic()
        }
        /// Ziffern in fester Breite: Buchungsnummer, Gate, Uhrzeit.
        static let ticket = Font.system(.footnote).weight(.medium).monospacedDigit()
        static func code(_ style: Font.TextStyle) -> Font { Font.system(style).weight(.medium).monospacedDigit() }
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
        static let page: CGFloat = 16
    }

    /// Eckenradien, immer mit kontinuierlicher Kurve. Marken haben fast keine Ecke.
    enum Radius {
        static let photo: CGFloat = 4
        static let small: CGFloat = 16
        static let card: CGFloat = 24
        static let floating: CGFloat = 32
        /// Alte Namen der Aufrufer; zeigen auf `photo` und `small`.
        static let stamp: CGFloat = photo
        static let thumb: CGFloat = small
    }

    /// Vier Höhen: flach, aufgeklebt (Karte auf Papier), Objekt (Marke, Ticket) und schwebend (über der Karte).
    /// Werte aus Figma (Unschärfe als CSS-Blur); der SwiftUI-Radius ist die halbe Unschärfe.
    enum Elevation {
        case flat, pinned, object, floating
        var opacity: Double { switch self { case .flat: 0; case .pinned: 0.08; case .object: 0.14; case .floating: 0.16 } }
        var radius: CGFloat { switch self { case .flat: 0; case .pinned: 4; case .object: 5; case .floating: 12 } }
        var y: CGFloat { switch self { case .flat: 0; case .pinned: 2; case .object: 4; case .floating: 10 } }
    }

    /// Feste Größen: Tippfläche nach Apple, Hauptknopf, Vorschaubild.
    enum Size {
        static let touch: CGFloat = 44
        static let button: CGFloat = 52
        static let thumb: CGFloat = 48
    }

    /// Gemeinsame Bewegungswerte. Besondere Choreografien behalten ihre eigenen Schwellen und Beats.
    enum Motion {
        static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
        static let panel = Animation.spring(response: 0.42, dampingFraction: 0.88)
        static let decisionReturn = Animation.spring(response: 0.4, dampingFraction: 0.72)
        static let reducedFade = Animation.easeInOut(duration: 0.2)
    }

    /// Schattenfarbe: Tinte, in beiden Modi gleich.
    static let shadow = rgb(28, 26, 23)
}

private extension Font.TextStyle {
    var uiStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

// MARK: Flächen

struct PaperBackground: View {
    var body: some View { Stitch.paper.ignoresSafeArea() }
}

extension View {
    /// Einheitliche Karte: Markenweiß, Radius 24, Kartenschatten, keine Kontur.
    func stitchCard(_ elevation: Stitch.Elevation = .pinned, padding: CGFloat = Stitch.Space.m) -> some View {
        self.padding(padding)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .stitchElevation(elevation)
    }

    func stitchElevation(_ elevation: Stitch.Elevation) -> some View {
        shadow(color: Stitch.shadow.opacity(elevation.opacity), radius: elevation.radius, y: elevation.y)
    }
}

/// Gepunktete Trennlinie (Perforation), überall gleich.
struct PerforationLine: View {
    var color = Stitch.line
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
    var mat: Color = Stitch.paper
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
    var top = "ALBUM"
    var bottom: String
    var color = Stitch.action
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
        case "Essen & Trinken": Stitch.Stamp.rose
        case "Sehenswert": Stitch.Stamp.sky
        case "Aussicht": Stitch.Stamp.butter
        case "Unterkunft": Stitch.Stamp.lilac
        case "Shopping": Stitch.Stamp.mint
        default: Stitch.paper
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

/// Hauptknopf als rote Pille (Poststempel), Nebenknopf als weiße Pille mit Linie.
struct StitchButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Stitch.Face.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Stitch.Space.m)
            .padding(.vertical, Stitch.Space.s)
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.button, alignment: .center)
            .foregroundStyle(primary ? Stitch.onAction : Stitch.ink)
            .background(primary ? Stitch.actionFill : Stitch.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Stitch.line, lineWidth: primary ? 0 : 1))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: configuration.isPressed)
    }
}

/// Weißer runder Knopf nur mit Symbol, 44 × 44, mit Kartenschatten.
struct HeaderIconButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            .background(Stitch.card, in: Circle())
            .stitchElevation(.pinned)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: configuration.isPressed)
    }
}

/// Stille Textaktion in Poststempel-Rot, 44 hoch.
struct TextActionButton: ButtonStyle {
    var tint = Stitch.action
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Stitch.Face.subheadline.weight(.semibold)).foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: Stitch.Size.touch, minHeight: Stitch.Size.touch, alignment: .center)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

/// Abschnittsüberschrift: Tinte links, optional eine Zahl oder Aktion rechts.
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Stitch.Face.section).foregroundStyle(Stitch.ink)
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

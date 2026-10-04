import SwiftUI
import UIKit

/// Welt „Briefmarke“: ruhiges Papier, Tinte, Poststempel. Jeder Ort ist eine Marke mit Pastellrand je Kategorie.
/// Quelle der Werte: Figma „Album Foundations“ (Datei BvFJ4PzwQXAxhPlrEw73rB). Der Name `Stitch` bleibt aus Gründen
/// der Verträglichkeit; gestickt wird nichts mehr.
enum Stitch {
    // MARK: Farben (Hell / Dunkel)

    static let paper = dynamic(light: (250, 249, 247), dark: (18, 24, 34))
    static let paperDeep = dynamic(light: (237, 241, 246), dark: (28, 37, 50))
    /// Helle Karten und Felder heben sich leise vom kühlen Reisehintergrund ab.
    /// Warm white surfaces match the paper while remaining visibly raised from it.
    static let card = dynamic(light: (255, 254, 251), dark: (28, 36, 49))
    static let rule = dynamic(light: (224, 230, 237), dark: (54, 64, 80))
    static let ink = dynamic(light: (15, 24, 49), dark: (243, 246, 251))
    /// #66676C auf Papier erreicht AA-Kontrast auch für kleine Schrift; #737378 lag knapp darunter.
    static let inkSoft = dynamic(light: (102, 103, 108), dark: (175, 187, 201))
    /// Koralle für Text, Auswahl und primäre Aktionen mit ausreichendem Kontrast.
    static let red = dynamic(light: (190, 70, 54), dark: (255, 145, 125))
    /// Koralle als Aktionsfläche; heller Vordergrund bleibt gut lesbar.
    static let redFill = dynamic(light: (190, 70, 54), dark: (159, 55, 43))
    /// Zweite Tinte für besuchte Orte und bestätigte Zustände.
    static let teal = dynamic(light: (40, 112, 128), dark: (117, 190, 194))
    /// Sanfte hellblaue Auswahlfläche für die aktuell fokussierte Karte oder Listenzeile.
    static let selection = dynamic(light: (231, 242, 253), dark: (37, 56, 79))
    /// Nur Zierde (Stempelring, Sterne), nie Schrift.
    static let gold = dynamic(light: (196, 165, 116), dark: (214, 186, 138))
    static let onAccent = Color(red: 1, green: 1, blue: 1)
    static let actionFill = Color(red: 15 / 255, green: 24 / 255, blue: 49 / 255)
    /// Hintergrund hinter Vollbildfotos, in beiden Modi dunkel.
    static let scrim = Color(red: 20 / 255, green: 18 / 255, blue: 16 / 255)

    /// Pastellränder der Marken, fest je Kategorie. Nie für Schrift.
    enum Mat {
        static let rose = dynamic(light: (250, 220, 214), dark: (88, 54, 58))
        static let sky = dynamic(light: (210, 231, 246), dark: (43, 65, 86))
        static let butter = dynamic(light: (249, 235, 194), dark: (77, 67, 43))
        static let mint = dynamic(light: (214, 237, 224), dark: (43, 69, 60))
        static let lilac = dynamic(light: (230, 222, 247), dark: (62, 54, 85))
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
        static let thumb: CGFloat = 12
        static let card: CGFloat = 22
        static let floating: CGFloat = 28
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

    /// Gemeinsame Bewegungswerte. Besondere Choreografien behalten ihre eigenen Schwellen und Beats.
    enum Motion {
        static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
        static let panel = Animation.spring(response: 0.42, dampingFraction: 0.88)
        static let decisionReturn = Animation.spring(response: 0.4, dampingFraction: 0.72)
        static let reducedFade = Animation.easeInOut(duration: 0.2)
    }

    /// Warme Schattenfarbe statt Schwarz, damit Marken auf Papier liegen statt zu schweben.
    static let shadow = Color(red: 0.12, green: 0.18, blue: 0.27)
}

// MARK: Flächen

struct PaperBackground: View {
    var body: some View { Stitch.paper.ignoresSafeArea() }
}

extension View {
    /// Einheitliche Karte: Markenweiß, feine Kontur; wahlweise mit Schatten.
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

// MARK: Zoom-Übergang

extension View {
    /// Quelle für den Zoom ins Detail (iOS 18+). Davor ohne Wirkung.
    @ViewBuilder func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Ziel des Zooms: direkt auf die Wurzel eines Blatts setzen. Bei „Bewegung reduzieren“ bleibt es ein normales Blatt.
    @ViewBuilder func zoomDestination(id: some Hashable, in namespace: Namespace.ID, enabled: Bool = true) -> some View {
        if enabled {
            if #available(iOS 18.0, *) {
                navigationTransition(.zoom(sourceID: id, in: namespace))
            } else {
                self
            }
        } else {
            self
        }
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

/// Hauptknopf als navy Pille, Nebenknopf als helle Pille mit Kontur.
struct StitchButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Stitch.Space.m)
            .padding(.vertical, Stitch.Space.s)
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.button, alignment: .center)
            .foregroundStyle(primary ? Stitch.onAccent : Stitch.ink)
            .background(primary ? Stitch.actionFill : Stitch.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Stitch.rule, lineWidth: primary ? 0 : 1))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: configuration.isPressed)
    }
}

/// Runder Knopf nur mit Symbol, 44 × 44.
struct HeaderIconButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            .background(Stitch.card, in: Circle())
            .overlay(Circle().strokeBorder(Stitch.rule, lineWidth: 1))
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: configuration.isPressed)
    }
}

/// Stille Textaktion in Navy, 44 hoch.
struct TextActionButton: ButtonStyle {
    var tint = Stitch.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: Stitch.Size.touch, minHeight: Stitch.Size.touch, alignment: .center)
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
            Text(title).font(Stitch.Face.title(20, relativeTo: .title3)).foregroundStyle(Stitch.ink)
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

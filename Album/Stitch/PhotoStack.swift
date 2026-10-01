import SwiftUI

extension Place {
    /// Hauptfoto und die weiteren Fotos des Foto-Streifens, in dieser Reihenfolge.
    var photoAssets: [PlaceImageAsset] {
        guard let main = image else { return [] }
        return [main] + (gallery ?? []).map(PlaceImageAsset.external)
    }
}

/// Aufrechte Fotos eines Ortes; hintere Fotos liegen leicht versetzt darunter.
/// Horizontal wischen blättert zyklisch (der Finger führt die Karte, halbe Geste = halbe Bewegung, zu kurz federt zurück),
/// Tippen öffnet das Foto groß, die Zähler-Schaltfläche blättert ohne Geste.
struct PhotoStack: View {
    let photos: [PlaceImageAsset]
    let root: URL
    var title: String
    var subtitle: String
    var onOpen: (PlaceImageAsset, CGRect) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Reihenfolge von vorn nach hinten, als Nummern der Fotos.
    @State private var order: [Int] = []
    @State private var drag: CGFloat = 0
    /// Karte, die gerade seitlich hinausfliegt und sich dann hinten einreiht.
    @State private var flying: Int?
    @State private var horizontal: Bool?
    @State private var frame: CGRect = .zero
    @State private var flip = 0

    /// Ab diesem Weg (oder vorhergesagtem Ende) blättert die Karte weiter.
    private let threshold: CGFloat = 80

    private var current: [Int] { order.isEmpty ? Array(photos.indices) : order }
    private var front: Int { current[0] }
    /// Wer dem Finger folgt: die vorderste Karte, beim Hinausfliegen die fliegende.
    private var mover: Int { flying ?? front }
    private var progress: CGFloat { min(abs(drag) / threshold, 1) }

    var body: some View {
        ZStack {
            // Hinten zuerst zeichnen, damit die vordere Karte oben liegt.
            ForEach(Array(current.enumerated().reversed()), id: \.element) { position, id in
                if !reduceMotion || position == 0 { card(id, position: position) }
            }
        }
        .padding(.horizontal, Stitch.Space.xs)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onOpen(photos[front], frame) }
        .simultaneousGesture(reduceMotion ? nil : swipe)
        .overlay(alignment: .topTrailing) { counter }
        .sensoryFeedback(.selection, trigger: flip)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Foto-Stapel")
        .accessibilityAction(named: "Nächstes Foto") { advance(-1) }
        .accessibilityAction(named: "Foto vergrößern") { onOpen(photos[front], frame) }
    }

    @ViewBuilder private func card(_ id: Int, position: Int) -> some View {
        let isMover = id == mover
        let slot = slot(position)
        Group {
            if position == 0 {
                PhotoCard(asset: photos[id], root: root, thumbnailWidth: 960)
                    .accessibilityLabel("Foto von \(title), \(subtitle)")
            } else {
                AlbumPhoto(asset: photos[id], root: root, thumbnailWidth: 500)
                    .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                    .stitchElevation(.pinned)
                    .accessibilityHidden(true)
            }
        }
        .offset(x: reduceMotion ? 0 : slot.offset.width + (isMover ? drag : 0), y: reduceMotion ? 0 : slot.offset.height)
        .rotationEffect(.degrees(reduceMotion ? 0 : slot.angle + (isMover ? Double(drag) / 18 : 0)))
        .zIndex(isMover && flying != nil ? 100 : Double(current.count - position))
        .transition(.opacity)
    }

    /// Lage einer Karte im Stapel; beim Wischen rücken die hinteren Karten anteilig nach vorn.
    private func slot(_ position: Int) -> (offset: CGSize, angle: Double) {
        func base(_ p: Int) -> (CGSize, Double) {
            switch min(p, 2) {
            case 0: (.zero, 0)
            case 1: (CGSize(width: 6, height: 4), 0)
            default: (CGSize(width: -6, height: 6), 0)
            }
        }
        guard position > 0, flying == nil else { return base(position) }
        let from = base(position), to = base(position - 1), t = Double(progress) * 0.7
        return (CGSize(width: from.0.width + (to.0.width - from.0.width) * t, height: from.0.height + (to.0.height - from.0.height) * t),
                from.1 + (to.1 - from.1) * t)
    }

    private var counter: some View {
        Button { advance(-1) } label: {
            Text("\(front + 1) / \(photos.count)")
                .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(Stitch.onAccent)
                .padding(.horizontal, Stitch.Space.s).padding(.vertical, Stitch.Space.xxs)
                .background(Capsule().fill(.black.opacity(0.4)))
                .frame(minWidth: Stitch.Size.touch, minHeight: Stitch.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(Stitch.Space.xs)
        .accessibilityLabel("Nächstes Foto, \(front + 1) von \(photos.count)")
        .accessibilityIdentifier("Foto-Zähler")
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Nur waagrechte Züge gehören dem Stapel; senkrechte scrollen weiter die Seite.
                if horizontal == nil {
                    horizontal = abs(value.translation.width) > abs(value.translation.height)
                    if horizontal == true, flying != nil { landFlyingCard() }
                }
                guard horizontal == true else { return }
                drag = value.translation.width
            }
            .onEnded { value in
                defer { horizontal = nil }
                guard horizontal == true else { return }
                let projected = value.predictedEndTranslation.width
                if abs(drag) >= threshold || abs(projected) > 220 {
                    advance(drag == 0 ? projected : drag)
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) { drag = 0 }
                }
            }
    }

    /// Blättert eine Karte weiter. Das Vorzeichen bestimmt, auf welcher Seite die Karte hinausfliegt.
    private func advance(_ direction: CGFloat) {
        guard photos.count > 1 else { return }
        if order.isEmpty { order = Array(photos.indices) }
        flip += 1
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { order.append(order.removeFirst()) }
            return
        }
        if flying != nil { landFlyingCard() }
        let sign: CGFloat = direction < 0 ? -1 : 1
        let from = drag
        flying = order[0]
        drag = from
        // Die vorderste Karte fliegt weg, die nächste rückt gleichzeitig nach vorn.
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            order.append(order.removeFirst())
            drag = sign * (frame.width + 40)
        } completion: {
            // Dann gleitet sie von hinten wieder in den Stapel.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { flying = nil; drag = 0 }
        }
    }

    /// Wer noch fliegt, wenn ein neuer Zug beginnt, landet sofort hinten.
    private func landFlyingCard() {
        var instant = Transaction(animation: nil); instant.disablesAnimations = true
        withTransaction(instant) { flying = nil; drag = 0 }
    }
}

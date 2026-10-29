import SwiftUI

// Gemeinsame Bausteine der Hauptansichten (Welle A): Kopf, Umschalter, Aktionszeile, Chips, Leerzustand.

/// Runder weißer Knopf mit Symbol, als Label für `Menu` (gleiche Optik wie `HeaderIconButton`).
struct HeaderIconLabel: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
            .background(Stitch.card, in: Circle())
            .stitchElevation(.pinned)
    }
}

/// Kopf jeder Registerkarte: links runder Zurück-Knopf zur Reisebibliothek, Titel, rechts optional Mehr, dann „+“.
struct TabHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    let onAdd: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            Button(action: onBack) { Image(systemName: "chevron.left") }
                .buttonStyle(HeaderIconButton())
                .accessibilityLabel("Album-Übersicht")
                .accessibilityIdentifier("trip-back-library")
            Text(title)
                .font(Stitch.Face.title()).foregroundStyle(Stitch.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Stitch.Space.xs)
            trailing
            Button(action: onAdd) { Image(systemName: "plus") }
                .buttonStyle(HeaderIconButton())
                .accessibilityLabel("Neue Idee")
                .accessibilityIdentifier("native-new-place")
        }
        .padding(.horizontal, Stitch.Space.page)
        .padding(.vertical, Stitch.Space.xs)
        .background(Stitch.paper)
    }
}

/// Zwei gleich breite Pillen als Umschalter (Stapel | Liste). Die gewählte ist Tinte mit Kartenschrift.
struct SegmentPair: View {
    let titles: [String]
    let identifiers: [String]
    @Binding var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(reduceMotion ? nil : Stitch.Motion.press) { selection = index }
                } label: {
                    Text(title)
                        .font(Stitch.Face.headline)
                        .foregroundStyle(selection == index ? Stitch.card : Stitch.ink)
                        .frame(maxWidth: .infinity, minHeight: Stitch.Size.button)
                        .background(selection == index ? Stitch.ink : Stitch.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Stitch.line, lineWidth: selection == index ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifiers[index])
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
    }
}

/// Filter-Chip: waagerecht scrollbar, nie abgeschnitten. Gewählt ist Tinte mit Kartenschrift.
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Stitch.Face.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Stitch.card : Stitch.ink)
                .padding(.horizontal, Stitch.Space.m)
                .frame(minHeight: Stitch.Size.touch)
                .background(selected ? Stitch.ink : Stitch.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Stitch.line, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Leerzustand nach Muster: ein Symbol, ein Satz, ein Knopf (der Knopf kommt vom Aufrufer).
struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Stitch.inkSoft)
                .padding(.bottom, Stitch.Space.xs)
            Text(title).font(Stitch.Face.section).foregroundStyle(Stitch.ink)
            Text(message).font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Stitch.Space.l)
        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
        .stitchElevation(.pinned)
    }
}

/// Aktionszeile in einer Karte: Symbol in Markenfarbe, Titel, Zusatzzeile, Pfeil. Mindestens 44 hoch.
struct ActionRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var mat: Color = Stitch.paper
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Stitch.Space.s) {
                Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(Stitch.Stamp.ink)
                    .frame(width: 40, height: 40).background(mat, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Stitch.Face.headline).foregroundStyle(Stitch.ink)
                    Text(subtitle).font(Stitch.Face.footnote).foregroundStyle(Stitch.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Zettel: gelb, leicht schief, handschriftlich (Caveat). Nur für das „Warum du hin willst“.
struct NoteSlip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Stitch.Face.note).foregroundStyle(Stitch.Stamp.ink)
            .multilineTextAlignment(.leading)
            .padding(Stitch.Space.m)
            .frame(maxWidth: 240, alignment: .leading)
            .background(Stitch.Stamp.note, in: RoundedRectangle(cornerRadius: Stitch.Radius.photo, style: .continuous))
            .stitchElevation(.object)
            .rotationEffect(.degrees(-3))
    }
}

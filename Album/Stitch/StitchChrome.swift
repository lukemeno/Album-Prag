import SwiftUI
import UIKit

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

// MARK: Löschen bestätigen (Figma 36) und Änderungen verwerfen (Welle B)

/// Bestätigung im Briefmarke-Stil: Vorschau, Papierkorb-Symbol, „<Name>“ löschen?, rote Pille „Löschen“, weiße Pille „Behalten“.
struct DeleteConfirmSheet<Preview: View>: View {
    let title: String
    let message: String
    let onDelete: () -> Void
    let onKeep: () -> Void
    @ViewBuilder var preview: Preview

    var body: some View {
        ScrollView {
            VStack(spacing: Stitch.Space.m) {
                preview
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Image(systemName: "trash").font(.title2).foregroundStyle(Stitch.action).accessibilityHidden(true)
                    Text(title).font(Stitch.Face.section).foregroundStyle(Stitch.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(message).font(Stitch.Face.subheadline).foregroundStyle(Stitch.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Löschen", action: onDelete)
                        .buttonStyle(StitchButton(primary: true))
                        .accessibilityIdentifier("delete-confirm")
                    Button("Behalten", action: onKeep)
                        .buttonStyle(StitchButton())
                        .accessibilityIdentifier("delete-keep")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .stitchCard(.pinned, padding: Stitch.Space.m)
            }
            .padding(Stitch.Space.page)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PaperBackground())
        .presentationDetents([.large])
    }
}

extension View {
    /// Fragt vor dem Löschen nach. „Behalten“ und Wegwischen lassen alles, wie es war.
    func deleteConfirmation<Preview: View>(
        isPresented: Binding<Bool>, name: String, message: String,
        onDelete: @escaping () -> Void,
        @ViewBuilder preview: @escaping () -> Preview = { EmptyView() }
    ) -> some View {
        sheet(isPresented: isPresented) {
            DeleteConfirmSheet(title: "„\(name)“ löschen?", message: message,
                               onDelete: { isPresented.wrappedValue = false; onDelete() },
                               onKeep: { isPresented.wrappedValue = false },
                               preview: preview)
        }
    }

    /// Schützt ein Formular mit Eingaben: kein Wegwischen, Abbrechen fragt „Änderungen verwerfen?“.
    /// Ein leeres Formular schließt ohne Rückfrage. `requestClose` ist die Abbrechen-Aktion des Formulars.
    func discardGuard(hasChanges: Bool, isPresented: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        self
            .interactiveDismissDisabled(hasChanges)
            .background(DismissAttemptObserver(isActive: hasChanges) { isPresented.wrappedValue = true })
            .confirmationDialog("Änderungen verwerfen?", isPresented: isPresented, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive, action: onDiscard)
                // Ohne .cancel-Rolle: Als Popover blendet SwiftUI Abbrechen-Schaltflächen sonst aus.
                Button("Weiter bearbeiten") {}
            }
    }
}

/// Meldet den Versuch, ein gesperrtes Sheet nach unten wegzuwischen (SwiftUI selbst bietet dafür keinen Rückruf).
struct DismissAttemptObserver: UIViewControllerRepresentable {
    let isActive: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Probe { Probe() }
    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.onAttempt = isActive ? onAttempt : nil
        probe.attachIfNeeded()
    }

    final class Probe: UIViewController {
        var onAttempt: (() -> Void)?
        private var proxy: Proxy?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); attachIfNeeded() }
        func attachIfNeeded() {
            var top: UIViewController = self
            while let parent = top.parent { top = parent }
            guard let controller = top.presentationController, proxy == nil || controller.delegate !== proxy else { return }
            let new = Proxy(original: controller.delegate) { [weak self] in self?.onAttempt?() }
            proxy = new
            controller.delegate = new
        }
    }

    /// Leitet alles an den SwiftUI-eigenen Delegate weiter, fängt nur den Wisch-Versuch ab.
    final class Proxy: NSObject, UIAdaptivePresentationControllerDelegate {
        weak var original: UIAdaptivePresentationControllerDelegate?
        let attempt: () -> Void
        init(original: UIAdaptivePresentationControllerDelegate?, attempt: @escaping () -> Void) {
            self.original = original; self.attempt = attempt
        }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            attempt()
            original?.presentationControllerDidAttemptToDismiss?(presentationController)
        }
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (original as AnyObject?)?.responds(to: selector) == true
        }
        override func forwardingTarget(for selector: Selector!) -> Any? {
            (original as AnyObject?)?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}

/// Kurze Bestätigung oben („Idee hinzugefügt“), verschwindet nach etwa zwei Sekunden.
struct ConfirmationToast: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(Stitch.Face.subheadline.weight(.semibold))
            .foregroundStyle(Stitch.card)
            .padding(.horizontal, Stitch.Space.m)
            .frame(minHeight: Stitch.Size.touch)
            .background(Stitch.ink, in: Capsule())
            .stitchElevation(.floating)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
            .accessibilityIdentifier("idea-added-toast")
    }
}

/// „Neu“-Marke an frisch gespeicherten Ideen.
struct NewBadge: View {
    var body: some View {
        Text("Neu")
            .font(Stitch.Face.caption).foregroundStyle(Stitch.onAction)
            .padding(.horizontal, Stitch.Space.xs).padding(.vertical, Stitch.Space.xxs)
            .background(Stitch.actionFill, in: Capsule())
            .accessibilityLabel("Neu")
            .accessibilityIdentifier("idea-new-badge")
    }
}

// MARK: Orte-Seiten (Welle B, Figma 10–18)

/// Kopf der Orte-Seiten: runder Zurück-Knopf, Titel, runder Schließen-Knopf. `dark` für die Galerie auf Scrim.
struct PlaceSheetHeader: View {
    let title: String
    var dark = false
    var backLabel = "Zurück"
    var closeLabel = "Schließen"
    var onBack: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: Stitch.Space.s) {
            if let onBack {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .buttonStyle(HeaderIconButton())
                    .accessibilityLabel(backLabel)
            }
            Text(title)
                .font(Stitch.Face.place()).foregroundStyle(dark ? Stitch.onAction : Stitch.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Stitch.Space.xs)
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(HeaderIconButton())
                .accessibilityLabel(closeLabel)
        }
        .padding(.horizontal, Stitch.Space.page)
        .padding(.vertical, Stitch.Space.xs)
    }
}

/// Feld mit kleiner Beschriftung oben, weißer Fläche, feiner Linie, Radius 16 (Figma 13, 14, 15).
struct LabeledFieldBox<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Stitch.Face.caption).foregroundStyle(Stitch.inkSoft)
            content.font(Stitch.Face.body).foregroundStyle(Stitch.ink)
        }
        .frame(maxWidth: .infinity, minHeight: Stitch.Size.button, alignment: .leading)
        .padding(.horizontal, Stitch.Space.s).padding(.vertical, Stitch.Space.xs)
        .background(Stitch.paper, in: RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous).strokeBorder(Stitch.line, lineWidth: 1))
    }
}

/// Kachel mit Symbol und Beschriftung (Route, Plan, Teilen, Website). `selected`: Himmelblau.
struct TileFace: View {
    let title: String
    let symbol: String
    var selected = false
    var body: some View {
        VStack(spacing: Stitch.Space.xs) {
            Image(systemName: symbol).font(.title3.weight(.medium)).frame(height: 24)
            Text(title).font(Stitch.Face.caption)
        }
        .foregroundStyle(Stitch.ink)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(selected ? Stitch.Stamp.sky : Stitch.paper, in: RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Stitch.Radius.small, style: .continuous))
    }
}

/// Hauptknopf unten am Blatt: dunkle Pille (Tinte, Kartenschrift), 52 hoch. Bewusst Tinte, nicht Rot (Figma 13–18).
struct InkPillButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Stitch.Face.headline).foregroundStyle(Stitch.card)
            .frame(maxWidth: .infinity, minHeight: Stitch.Size.button)
            .background(Stitch.ink, in: Capsule())
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: configuration.isPressed)
    }
}

import SwiftUI
import UIKit

/// Gemeinsames Album: dein Name und genau ein Weg, die andere Person dazuzuholen.
/// Abgeglichen wird von selbst und per Herunterziehen auf „Reise“.
struct AlbumSettings: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var preparing = false
    @State private var localError: String?
    @State private var copied = false
    @State private var joinText = ""
    @State private var joining = false
    @FocusState private var nameFocused: Bool
    @FocusState private var joinFocused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        Text("Album")
                            .font(Stitch.Face.display(30, relativeTo: .largeTitle))
                            .foregroundStyle(Stitch.ink)
                        Text(store.isShared ? "Ihr teilt dieses Album" : "Zu zweit planen")
                            .font(Stitch.Face.title(24, relativeTo: .title2)).foregroundStyle(Stitch.ink)
                        Text("Ideen, Orte und Unterlagen landen auf beiden iPhones. Der Link gilt nur für diese Reise.")
                            .font(.body).foregroundStyle(Stitch.inkSoft)
                    }

                    VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                        Text("Dein Name").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                        StitchTextField(placeholder: "Vorname", text: Binding(get: { store.myName }, set: { store.myName = $0 }),
                                        focused: $nameFocused) { nameFocused = false }
                            .textContentType(.givenName)
                    }

                    VStack(alignment: .leading, spacing: Stitch.Space.s) {
                        if let inviteURL = store.inviteURL {
                            ShareLink(item: inviteURL, subject: Text("Prag 2026"), message: Text("Komm in unser Prag-Album")) {
                                Label("Einladung senden", systemImage: "paperplane")
                            }
                            .buttonStyle(AlbumActionButtonStyle(primary: true))
                            // Manche Messenger machen „album://“-Links nicht antippbar. Dann kopieren und drüben einfügen.
                            Button {
                                UIPasteboard.general.string = inviteURL.absoluteString
                                copied = true
                            } label: {
                                Label(copied ? "Link kopiert" : "Link kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(AlbumActionButtonStyle())
                            .sensoryFeedback(.success, trigger: copied) { _, now in now }
                            .animation(.snappy, value: copied)
                            .accessibilityHint("Den Link in einer Nachricht einfügen. Auf dem anderen iPhone unter „Einladung bekommen?“ einfügen.")
                        } else if !store.isShared {
                            Button {
                                preparing = true
                                Task {
                                    defer { preparing = false }
                                    do { _ = try await store.createSharedTrip() }
                                    catch { localError = error.localizedDescription }
                                }
                            } label: {
                                if preparing { ProgressView().tint(Stitch.onAccent) } else { Label("Einladung erstellen", systemImage: "link") }
                            }
                            .buttonStyle(AlbumActionButtonStyle(primary: true)).disabled(preparing || store.syncing)
                        }
                        Label(store.syncStatus, systemImage: store.isShared ? "arrow.triangle.2.circlepath" : "iphone")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }

                    if !store.isShared {
                        VStack(alignment: .leading, spacing: Stitch.Space.s) {
                            Text("Einladung bekommen?").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                            Text("Lässt sich der Link nicht antippen, kopiere ihn und füge ihn hier ein.")
                                .font(.footnote).foregroundStyle(Stitch.inkSoft)
                            StitchTextField(placeholder: "album://join/…", text: $joinText, focused: $joinFocused, onSubmit: join)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .accessibilityLabel("Einladungslink")
                            Button(action: join) {
                                if joining { ProgressView() } else { Label("Album beitreten", systemImage: "person.2") }
                            }
                            .buttonStyle(AlbumActionButtonStyle())
                            .disabled(joinURL == nil || joining || store.syncing)
                        }
                    }
                }
                .padding(Stitch.Space.page)
            }
            .background(PaperBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen", systemImage: "xmark") { dismiss() } } }
            .alert("Einladung hat nicht geklappt", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) { Button("OK") { localError = nil } } message: { Text(localError ?? "") }
        }
    }

    /// Erkennt den Einladungslink auch mitten in einer weitergeleiteten Nachricht.
    private var joinURL: URL? {
        guard let start = joinText.range(of: "album://", options: .caseInsensitive) else { return nil }
        let link = joinText[start.lowerBound...].prefix { !$0.isWhitespace && !$0.isNewline }
        guard let url = URL(string: String(link)), InvitationLink.token(from: url) != nil else { return nil }
        return url
    }

    private func join() {
        guard let url = joinURL, !joining else { return }
        joinFocused = false
        joining = true
        Task {
            defer { joining = false }
            do {
                try await store.joinSharedTrip(url: url)
                joinText = ""
            } catch { localError = error.localizedDescription }
        }
    }
}

/// Die unterstützenden Screens teilen dieselbe ruhige Aktionssprache wie die
/// Referenz: Navy für die wichtigste Aktion, helles Blau für sekundäre Flächen.
/// Die Styles bleiben lokal in der nativen App, damit bestehende Tokens und
/// die bereits verwendeten Store-Aktionen unverändert bleiben.
struct AlbumActionButtonStyle: ButtonStyle {
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
            .background(primary ? Stitch.actionFill : Stitch.selection, in: Capsule())
            .overlay(Capsule().strokeBorder(primary ? .clear : Stitch.rule, lineWidth: 1))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : Stitch.Motion.press, value: configuration.isPressed)
    }
}

struct AlbumTextActionButtonStyle: ButtonStyle {
    var tint: Color = Stitch.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: Stitch.Size.touch, minHeight: Stitch.Size.touch, alignment: .center)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

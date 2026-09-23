import SwiftUI

/// Briefkasten-Schlitz: Die neue Idee wird eingeworfen, die Klappe schlägt zu.
struct LetterSlotDrop: View {
    let place: Place
    let root: URL
    var onDone: () -> Void
    @State private var phase = Phase.shown
    @State private var clack = 0

    enum Phase { case shown, rising, inside, closed }

    var body: some View {
        GeometryReader { geo in
            let slotY: CGFloat = 150
            ZStack(alignment: .top) {
                LinenBackground().opacity(0.96)

                VStack(spacing: 8) {
                    ZStack(alignment: .top) {
                        Capsule().fill(Color.black.opacity(0.85)).frame(width: 220, height: 20)
                            .overlay(Capsule().strokeBorder(Stitch.red, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).padding(-6))
                        // Klappe
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Stitch.red)
                            .frame(width: 236, height: 30)
                            .overlay(Text("Ideen").font(.footnote.weight(.bold)).foregroundStyle(Stitch.onAccent))
                            .rotation3DEffect(.degrees(phase == .rising || phase == .inside ? -70 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
                            .offset(y: -10)
                    }
                    Text(phase == .closed ? "Eingeworfen" : " ")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                        .padding(.top, 14)
                }
                .padding(.top, slotY - 10)
                .zIndex(2)

                ZStack(alignment: .top) {
                    card
                        .scaleEffect(phase == .shown ? 1 : 0.42, anchor: .top)
                        .offset(y: cardY(height: geo.size.height, slotY: slotY))
                        .rotation3DEffect(.degrees(phase == .shown ? 0 : 18), axis: (x: 1, y: 0, z: 0))
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                // Was über den Schlitz hinausgeht, ist im Briefkasten verschwunden.
                .mask(alignment: .top) { Rectangle().padding(.top, slotY + 4) }
                .zIndex(1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: clack)
        .task { await run() }
        .accessibilityElement().accessibilityLabel("Idee eingeworfen")
    }

    private func cardY(height: CGFloat, slotY: CGFloat) -> CGFloat {
        switch phase {
        case .shown: height * 0.34
        case .rising: slotY + 8
        case .inside, .closed: slotY - 150
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            AlbumPhoto(asset: place.image, root: root).frame(width: 236, height: 200)
            Text(place.title).font(.title3.weight(.bold)).foregroundStyle(Stitch.ink).lineLimit(2)
                .frame(width: 236, alignment: .leading)
        }
        .padding(12)
        .background(Stitch.card)
        .overlay(alignment: .topLeading) { TackStitch(size: 14).offset(x: 6, y: 6) }
        .overlay(alignment: .topTrailing) { TackStitch(size: 14).offset(x: -6, y: 6) }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    private func run() async {
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeIn(duration: 0.38)) { phase = .rising }
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.easeIn(duration: 0.2)) { phase = .inside }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { phase = .closed }
        clack += 1
        try? await Task.sleep(for: .milliseconds(520))
        onDone()
    }
}

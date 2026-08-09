import SwiftUI

struct GlassPanel<Content: View>: View {
    private let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

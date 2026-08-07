import SwiftUI

/// Step-up prompt (screen 5b). Shown **only** after a clean week at the current length, immediately
/// after a session, never as a push. Compares NOW → SUGGESTED, one reassuring line, then move-up /
/// keep-it. Declining is a first-class choice and is not asked again that week.
struct StepUpView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    private var session: SessionCoordinator { services.session }
    private var now: Int { services.settings.defaultLength }
    private var suggested: Int { services.settings.nextLengthUp ?? now }
    private var bookTitle: String { services.books.currentReading?.title ?? "your book" }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.3))
            VStack(spacing: 24) {
                Spacer()
                Text("Seven days at \(now) minutes. You haven't missed once. Want to make it \(suggested)?")
                    .font(BGFont.serif(27, .medium))
                    .foregroundStyle(palette.ink(.hero))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                HStack(alignment: .center, spacing: 18) {
                    compare("\(now)", "now")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.ink(.secondary))
                    compare("\(suggested)", "suggested")
                }

                Text("\(suggested) minutes is still less than one chapter of \(bookTitle).")
                    .font(BGFont.aside(15))
                    .foregroundStyle(palette.ink(.body))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer()
                VStack(spacing: 12) {
                    Button("Move to \(suggested) minutes") { session.acceptStepUp() }
                        .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                    Button("\(now) is working — keep it") { session.declineStepUp() }
                        .buttonStyle(GlassButtonStyle(minHeight: 52))
                }
                Text("Either way, tonight is already read.")
                    .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
            }
            .padding(.horizontal, 26)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
    }

    private func compare(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(BGFont.serif(38, .medium)).foregroundStyle(palette.ink(.hero))
            Text(label).sectionLabel(color: palette.ink(.secondary))
        }
    }
}

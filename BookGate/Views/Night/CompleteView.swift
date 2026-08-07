import SwiftUI

/// Session complete → takeaway (screen 9). "You read today." with minutes + streak in a glass
/// panel, a brass-tinted prompt explaining why to record, then Record a Takeaway / Not now.
/// Recording is optional every single time; skipping never breaks the streak.
struct CompleteView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    private var session: SessionCoordinator { services.session }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.28))
            VStack(spacing: 22) {
                Spacer()
                Bookmark(width: 38, height: 52)
                Text("You read today.")
                    .font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
                Text("You showed up for your book.")
                    .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))

                statsPanel
                promptPanel

                Spacer()
                VStack(spacing: 12) {
                    Button("Record a Takeaway") { session.recordTakeaway() }
                        .buttonStyle(PrimaryActionButtonStyle(minHeight: 52))
                    Button("Not now") { session.skipTakeaway() }
                        .buttonStyle(TextButtonStyle(ink: .secondary))
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
    }

    private var statsPanel: some View {
        HStack(spacing: 0) {
            stat("\(session.completedMinutes)", "minutes read")
            Hairline(axis: .vertical).frame(height: 40)
            stat("\(session.completedStreak)", "day streak")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glass(.card, cornerRadius: 22)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(BGFont.serif(30, .medium)).foregroundStyle(palette.ink(.hero))
            Text(label).sectionLabel(color: palette.ink(.secondary))
        }
        .frame(maxWidth: .infinity)
    }

    private var promptPanel: some View {
        VStack(spacing: 6) {
            Text("While it's fresh").sectionLabel(color: palette.brassValue)
            Text("A takeaway in your own voice is worth more than a page of notes you'll never reopen.")
                .font(BGFont.aside(14))
                .foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0xE9B872, opacity: 0.14))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(hex: 0xB87A2E, opacity: 0.22), lineWidth: 1))
        }
    }
}

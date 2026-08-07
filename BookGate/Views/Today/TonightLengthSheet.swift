import SwiftUI

/// Tonight's length sheet (screen 5c). **Length only** — apps and time live in Settings. Seven
/// durations as a chip grid; the selection is filled brass with dark ink, others hairline. Changes
/// **tonight only** (resets after the session).
struct TonightLengthSheet: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var selected: Int { services.settings.effectiveTonightLength }

    var body: some View {
        ZStack {
            BGAmbientBackground(showGlow: false)
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tonight's reading")
                        .font(BGFont.serif(24, .medium))
                        .foregroundStyle(palette.ink(.hero))
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(BGFont.ui(15, .semibold)).foregroundStyle(palette.brassValue)
                }
                Text("How long").sectionLabel()

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ReadingSettings.lengthOptions, id: \.self) { value in
                        chip(value)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }

    private func chip(_ value: Int) -> some View {
        let isOn = value == selected
        let label = value == 60 ? "1h" : "\(value)m"
        return Button {
            services.settings.tonightLength = value
            dismiss()
        } label: {
            Text(label)
                .font(BGFont.serif(20, .medium))
                .foregroundStyle(isOn ? palette.actionText : palette.ink(.strong))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isOn ? AnyShapeStyle(palette.brassObject) : AnyShapeStyle(Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isOn ? Color.clear : palette.hairline, lineWidth: 1))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == 60 ? "1 hour" : "\(value) minutes")
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

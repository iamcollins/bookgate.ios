import SwiftUI
import FamilyControls

/// A themed row that shows how many apps are shielded and opens the system FamilyActivityPicker to
/// change the selection. Used in onboarding (shielded apps step) and Settings. The picker itself is
/// Apple's — app tokens are opaque, so we never see which apps the user picked (privacy by design).
struct ShieldAppsRow: View {
    @Bindable var shield: ShieldManager
    @Environment(\.bgPalette) private var palette
    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shielded apps").sectionLabel()
                    Text(countLabel)
                        .font(BGFont.row)
                        .foregroundStyle(palette.ink(.strong))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.ink(.secondary))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .familyActivityPicker(isPresented: $showPicker, selection: $shield.selection)
    }

    private var countLabel: String {
        let n = shield.shieldedCount
        if n == 0 { return String(localized: "Choose apps to lock during reading") }
        return String(localized: "\(n) selected")
    }
}

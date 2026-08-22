import SwiftUI
import FamilyControls
import UIKit

extension View {
    /// The system apps picker, with Screen Time authorization asked for **first**.
    ///
    /// Every presentation of `FamilyActivityPicker` in the app goes through here. Presented
    /// directly it renders the category rows regardless of authorization, and each one opens
    /// empty — which reads as "BookGate can't see my apps" rather than "BookGate was never
    /// allowed to". Onboarding made that certain rather than likely: its `apps` step comes
    /// *before* its `permissions` step, so the first picker a reader ever opened was always
    /// unauthorized.
    func shieldPicker(isPresented: Binding<Bool>, shield: ShieldManager) -> some View {
        modifier(ShieldPickerModifier(isPresented: isPresented, shield: shield))
    }
}

private struct ShieldPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Bindable var shield: ShieldManager
    @State private var showPicker = false
    @State private var denied = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, wants in
                guard wants else { return }
                isPresented = false                       // the request is the gate, not the flag
                Task {
                    if await shield.authorizeForPicker() { showPicker = true } else { denied = true }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $shield.selection)
            .alert("Screen Time access needed", isPresented: $denied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("BookGate can only list your apps once Screen Time access is allowed.")
            }
    }
}

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
        .shieldPicker(isPresented: $showPicker, shield: shield)
    }

    private var countLabel: String {
        let n = shield.shieldedCount
        if n == 0 { return String(localized: "Choose apps to lock during reading") }
        return String(localized: "\(n) selected")
    }
}

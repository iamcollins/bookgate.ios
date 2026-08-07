import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The custom barrier UI drawn over a shielded app (screen 1g). Vellum-dark panel, the brass
/// bookmark, "Reading time is active.", a Return-to-BookGate primary button, and **Emergency access
/// always present** as the secondary — never styled as a punishment.
///
/// Not compiled into the app target yet — see ../README.md.
final class ReadingShieldConfiguration: ShieldConfigurationDataSource {

    private var barrier: ShieldConfiguration {
        let ink = UIColor(red: 0xF7/255, green: 0xEF/255, blue: 0xE4/255, alpha: 1)
        let inkBody = UIColor(red: 0xF7/255, green: 0xEF/255, blue: 0xE4/255, alpha: 0.62)
        let inkQuiet = UIColor(red: 0xF7/255, green: 0xEF/255, blue: 0xE4/255, alpha: 0.5)
        let base = UIColor(red: 0x10/255, green: 0x0C/255, blue: 0x09/255, alpha: 1)
        let brass = UIColor(red: 0xE0/255, green: 0xA8/255, blue: 0x62/255, alpha: 1)
        let actionInk = UIColor(red: 0x24/255, green: 0x16/255, blue: 0x06/255, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: base.withAlphaComponent(0.6),
            icon: UIImage(named: "ShieldBookmark"),   // add a brass-bookmark PDF/PNG to the extension assets
            title: .init(text: "Reading time is active.", color: ink),
            subtitle: .init(text: "Finish your session before opening this app.", color: inkBody),
            primaryButtonLabel: .init(text: "Return to BookGate", color: actionInk),
            primaryButtonBackgroundColor: brass,
            secondaryButtonLabel: .init(text: "Emergency access", color: inkQuiet))
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { barrier }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { barrier }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { barrier }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { barrier }
}

import SwiftUI

/// Settings → Reading (screen 6a). Grouped exactly as the design: EVERY NIGHT (minimum length,
/// alarm time, days), HOW IT ADAPTS (the two rules stated plainly), DURING A SESSION (shielded apps,
/// emergency access). Appearance is added below (the README's manual theme override). The Settings
/// *root* is a flagged open item; the Today header dots open this sub-page directly.
struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    private var schedule: Schedule? { services.store.schedule(for: nil) }

    var body: some View {
        @Bindable var settings = services.settings
        ZStack {
            BGAmbientBackground(showGlow: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Reading").font(BGFont.screenTitle).foregroundStyle(palette.ink(.hero))
                    everyNightCard(settings: settings)
                    howItAdaptsCard
                    duringSessionCard
                    appearanceCard(settings: settings)
                    SubscriptionCard()
                    aboutCard
                    footer
                }
                .padding(.horizontal, 20).padding(.vertical, 20)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)   // no rubber-band on a screen whose content already fits
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.tint(palette.brassValue)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(label).sectionLabel()
            VStack(spacing: 12) { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).glass(.card, cornerRadius: 20)
    }

    // MARK: EVERY NIGHT

    private func everyNightCard(settings: ReadingSettings) -> some View {
        card("Every night") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minimum length").font(BGFont.row).foregroundStyle(palette.ink(.strong))
                    Text("The same for every book").font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                }
                Spacer()
                Picker("", selection: Binding(get: { settings.defaultLength }, set: { settings.defaultLength = $0 })) {
                    ForEach(ReadingSettings.lengthOptions, id: \.self) { Text($0 == 60 ? "1 hour" : "\($0) min").tag($0) }
                }.pickerStyle(.menu).tint(palette.brassValue)
            }
            if let schedule {
                Divider().overlay(palette.hairline)
                DatePicker(selection: alarmBinding(schedule), displayedComponents: .hourAndMinute) {
                    Text("Alarm time").font(BGFont.row).foregroundStyle(palette.ink(.strong))
                }.tint(palette.brassValue)
                Divider().overlay(palette.hairline)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days").font(BGFont.row).foregroundStyle(palette.ink(.strong))
                    HStack(spacing: 6) { ForEach(0..<7, id: \.self) { dayToggle(schedule, $0) } }
                    Text("Uncheck a night for a rest day.").font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                }
            }
        }
    }

    private func dayToggle(_ schedule: Schedule, _ i: Int) -> some View {
        let on = schedule.days[i]
        return Button {
            var d = schedule.days; d[i].toggle(); schedule.days = d
            Task { await services.resync() }
        } label: {
            Text(Schedule.dayLetters[i])
                .font(BGFont.ui(13, .semibold))
                .foregroundStyle(on ? palette.actionText : palette.ink(.secondary))
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? AnyShapeStyle(palette.brassObject) : AnyShapeStyle(Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Color.clear : palette.hairline, lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    // MARK: HOW IT ADAPTS

    private var howItAdaptsCard: some View {
        card("How it adapts") {
            ruleRow("Offer the next step up", "After a full week at your minimum. One step, and only as an offer.")
            Divider().overlay(palette.hairline)
            ruleRow("One rest day a week", "A missed night keeps your streak, once every seven days.")
        }
    }

    private func ruleRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(BGFont.row).foregroundStyle(palette.ink(.strong))
            Text(body).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: DURING A SESSION

    private var duringSessionCard: some View {
        card("During a session") {
            ShieldAppsRow(shield: services.shield)
            Divider().overlay(palette.hairline)
            ruleRow("Emergency access", "Ten-second wait, then anything opens.")
        }
    }

    // MARK: Appearance (README manual theme override; not in the design's 6a)

    private func appearanceCard(settings: ReadingSettings) -> some View {
        card("Appearance") {
            Picker("Theme", selection: Binding(get: { settings.theme }, set: { settings.theme = $0 })) {
                ForEach(ThemePreference.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
        }
    }

    // MARK: About

    /// Where the app says what it is and what it does with your things. The privacy line is not
    /// marketing — it is the one claim this app makes that a reader is entitled to see restated
    /// somewhere calmer than onboarding.
    private var aboutCard: some View {
        card("About") {
            HStack {
                Text("Version").font(BGFont.row).foregroundStyle(palette.ink(.strong))
                Spacer()
                Text(versionLabel).font(BGFont.mono(13)).foregroundStyle(palette.ink(.secondary))
            }
            Divider().overlay(palette.hairline)
            ruleRow("Everything stays on this phone",
                    "Your photos, your recordings and your reading history are never uploaded.")
        }
    }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Link("Terms", destination: Legal.termsURL).font(BGFont.ui(12, .medium)).tint(palette.ink(.secondary))
            Link("Privacy", destination: Legal.privacyURL).font(BGFont.ui(12, .medium)).tint(palette.ink(.secondary))
            Spacer()
        }
        .padding(.top, 4)
    }

    private func alarmBinding(_ schedule: Schedule) -> Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = schedule.readingMin / 60; c.minute = schedule.readingMin % 60
                return Calendar.current.date(from: c) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                schedule.readingMin = (c.hour ?? 21) * 60 + (c.minute ?? 0)
                Task { await services.resync() }
            })
    }
}

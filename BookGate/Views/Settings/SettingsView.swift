import SwiftUI

/// Settings → Reading (screen 6a). Default length, alarm time, active nights (rest day), shielded
/// apps, appearance, and the two rules stated plainly. The Settings *root* is a flagged open item;
/// the Today header dots open this sub-page directly, so it dismisses back to Today.
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

                    lengthCard(settings: settings)
                    if let schedule { alarmCard(schedule) }
                    appsCard
                    appearanceCard(settings: settings)
                    rulesCard
                    footer
                }
                .padding(.horizontal, 20).padding(.vertical, 20)
            }
            .scrollContentBackground(.hidden)
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
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).glass(.card, cornerRadius: 20)
    }

    private func lengthCard(settings: ReadingSettings) -> some View {
        card("Default length") {
            Picker("Default length", selection: Binding(
                get: { settings.defaultLength },
                set: { settings.defaultLength = $0 })) {
                ForEach(ReadingSettings.lengthOptions, id: \.self) { v in
                    Text(v == 60 ? "1 hour" : "\(v) min").tag(v)
                }
            }
            .pickerStyle(.menu).tint(palette.brassValue)
        }
    }

    private func alarmCard(_ schedule: Schedule) -> some View {
        card("Alarm") {
            DatePicker("Time", selection: alarmBinding(schedule), displayedComponents: .hourAndMinute)
                .tint(palette.brassValue)
                .foregroundStyle(palette.ink(.strong))
            Divider().overlay(palette.hairline)
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in dayToggle(schedule, i) }
            }
            Text("Uncheck a night for a rest day.")
                .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
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

    private var appsCard: some View {
        card("Shielded apps") { ShieldAppsRow(shield: services.shield) }
    }

    private func appearanceCard(settings: ReadingSettings) -> some View {
        card("Appearance") {
            Picker("Theme", selection: Binding(get: { settings.theme }, set: { settings.theme = $0 })) {
                ForEach(ThemePreference.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var rulesCard: some View {
        card("How BookGate works") {
            ruleRow("The default earns its way up", "After a clean week, we offer one increment — once. You can always keep what's working.")
            Divider().overlay(palette.hairline)
            ruleRow("A miss is stated once", "No red, no reset, no catch-up. A missed night is just an outline.")
        }
    }

    private func ruleRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(BGFont.ui(14.5, .semibold)).foregroundStyle(palette.ink(.strong))
            Text(body).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
        }
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

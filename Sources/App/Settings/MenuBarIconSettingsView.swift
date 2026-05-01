import SwiftUI

struct MenuBarIconSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Display") {
                Picker("Mode", selection: $settings.menuBarIconDisplayMode) {
                    Text("Percentage Only").tag("percentageOnly")
                    Text("Icon Only").tag("iconOnly")
                    Text("Both").tag("both")
                }
                .pickerStyle(.segmented)
            }

            Section("Style") {
                Picker("Color", selection: $settings.menuBarIconStyleMode) {
                    Text("Monochrome").tag("monochrome")
                    Text("Color (Translucent)").tag("colorTranslucent")
                    Text("Color (With Background)").tag("colorWithBackground")
                }
                .pickerStyle(.segmented)
            }

            Section("Show These Limits") {
                limitToggle(label: "5-hour session",   value: "fiveHour")
                limitToggle(label: "7-day weekly",     value: "sevenDay")
                limitToggle(label: "Opus weekly",      value: "opusWeekly")
                limitToggle(label: "Sonnet weekly",    value: "sonnetWeekly")
            }
        }
        .padding()
    }

    private func limitToggle(label: String, value: String) -> some View {
        Toggle(label, isOn: Binding(
            get: { settings.menuBarIconActiveTypes.contains(value) },
            set: { isOn in
                var types = settings.menuBarIconActiveTypes
                if isOn {
                    if !types.contains(value) { types.append(value) }
                } else {
                    types.removeAll { $0 == value }
                }
                settings.menuBarIconActiveTypes = types
            }
        ))
    }
}

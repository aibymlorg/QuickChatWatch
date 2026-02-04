import SwiftUI

/// View for selecting language
struct LanguagePickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(UserSettings.supportedLanguages, id: \.code) { language in
                    LanguageButton(
                        name: language.name,
                        code: language.code,
                        isSelected: viewModel.settings?.language == language.name,
                        onSelect: {
                            viewModel.updateLanguage(language.name)
                            dismiss()
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Language")
    }
}

/// Individual language selection button
struct LanguageButton: View {
    let name: String
    let code: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(code)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cyan)
                }
            }
            .padding(10)
            .background(isSelected ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Flag emoji for language (simplified)
struct LanguageFlag: View {
    let code: String

    var body: some View {
        Text(flag)
            .font(.title3)
    }

    private var flag: String {
        switch code.prefix(2) {
        case "en": return "🇺🇸"
        case "es": return "🇪🇸"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "it": return "🇮🇹"
        case "pt": return "🇧🇷"
        case "hi", "ta", "te", "bn": return "🇮🇳"
        case "ar": return "🇸🇦"
        case "zh": return "🇨🇳"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        default: return "🌐"
        }
    }
}

#Preview {
    NavigationStack {
        LanguagePickerView(viewModel: SettingsViewModel())
    }
}

import SwiftUI

/// View for selecting response mode / environment
struct ResponseModeView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var customScenario: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Choose the environment to get context-aware phrases")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                ForEach(UserSettings.responseModes, id: \.name) { mode in
                    ResponseModeButton(
                        name: mode.name,
                        description: mode.description,
                        isSelected: viewModel.settings?.responseMode == mode.name,
                        onSelect: {
                            viewModel.updateResponseMode(mode.name)
                            if mode.name != "custom" {
                                dismiss()
                            }
                        }
                    )
                }

                // Custom scenario input
                if viewModel.settings?.responseMode == "custom" {
                    VStack(spacing: 8) {
                        TextField("e.g., Doctor's appointment", text: $customScenario)
                            .font(.caption)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)

                        Button {
                            if !customScenario.isEmpty {
                                // Generate context pack for custom scenario
                                dismiss()
                            }
                        } label: {
                            Text("Apply")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(customScenario.isEmpty ? Color.gray : Color.yellow)
                                .foregroundColor(customScenario.isEmpty ? .white : .black)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(customScenario.isEmpty)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Environment")
    }
}

/// Individual response mode button
struct ResponseModeButton: View {
    let name: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
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

/// Icon for each response mode
struct ResponseModeIcon: View {
    let mode: String

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 20))
    }

    private var iconName: String {
        switch mode {
        case "public_transport": return "bus.fill"
        case "shopping": return "cart.fill"
        case "school": return "graduationcap.fill"
        case "hospital": return "cross.fill"
        case "office": return "briefcase.fill"
        case "custom": return "sparkles"
        default: return "bubble.left.fill"
        }
    }
}

#Preview {
    NavigationStack {
        ResponseModeView(viewModel: SettingsViewModel())
    }
}

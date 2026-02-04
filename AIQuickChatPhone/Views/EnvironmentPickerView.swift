import SwiftUI

/// Full screen picker for all environment types
struct EnvironmentPickerView: View {
    @EnvironmentObject var environmentDetector: EnvironmentDetectionService
    @Environment(\.dismiss) var dismiss

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(EnvironmentContext.EnvironmentType.allCases, id: \.self) { type in
                        EnvironmentTypeCard(type: type) {
                            environmentDetector.setManualContext(type)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EnvironmentTypeCard: View {
    let type: EnvironmentContext.EnvironmentType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(.cyan)
                }

                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    EnvironmentPickerView()
        .environmentObject(EnvironmentDetectionService.shared)
}

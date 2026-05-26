import SwiftUI

struct OnboardingSurveyQuestion: Identifiable {
    struct Option: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
    }

    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let options: [Option]
}

struct OnboardingSurveyQuestionView: View {
    let question: OnboardingSurveyQuestion
    @Binding var selection: String
    let onContinue: () -> Void
    @State private var contentVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            surveyHeader
            VStack(spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        selection = option.id
                    } label: {
                        SurveyOptionRow(option: option, isSelected: selection == option.id)
                    }
                    .buttonStyle(.plain)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 18)
                    .animation(.easeOut(duration: 0.34).delay(0.1 + Double(index) * 0.055), value: contentVisible)
                }
            }
            Spacer(minLength: 10)
            PrimaryButton(title: selection.isEmpty ? "Choose one" : "Continue", action: onContinue)
                .disabled(selection.isEmpty)
                .opacity(selection.isEmpty ? 0.45 : 1)
                .offset(y: contentVisible ? 0 : 14)
                .animation(.easeOut(duration: 0.3).delay(0.26), value: contentVisible)
        }
        .onAppear {
            contentVisible = false
            withAnimation(.easeOut(duration: 0.32)) {
                contentVisible = true
            }
        }
    }

    private var surveyHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(question.eyebrow)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.14), in: Capsule())
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.28), value: contentVisible)

            VStack(alignment: .leading, spacing: 8) {
                Text(question.title)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(question.subtitle)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.34).delay(0.04), value: contentVisible)
        }
    }
}

private struct SurveyOptionRow: View {
    let option: OnboardingSurveyQuestion.Option
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppTheme.accent : AppTheme.surfaceSecondary)
                    .frame(width: 46, height: 46)
                Image(systemName: option.icon)
                    .font(.headline.bold())
                    .foregroundStyle(isSelected ? .black : AppTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(option.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.bold())
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.border)
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.86) : AppTheme.border, lineWidth: isSelected ? 1.4 : 1)
        )
        .shadow(color: isSelected ? AppTheme.accent.opacity(0.14) : .clear, radius: 16, y: 8)
    }
}

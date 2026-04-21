import SwiftUI

struct HeaderFormView: View {
    @ObservedObject var viewModel: ReportViewModel

    private let labelWidth: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("入力")
                .font(.title2)
                .bold()

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("氏名")
                    .font(.title3)
                    .frame(width: labelWidth, alignment: .leading)
                TextField("山田 太郎", text: $viewModel.authorName)
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.authorName) { _ in
                        viewModel.persistAuthorName()
                        viewModel.requestPreviewRefresh()
                    }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("日付")
                    .font(.title3)
                    .frame(width: labelWidth, alignment: .leading)
                DatePicker(
                    "",
                    selection: $viewModel.date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .font(.title3)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .onChange(of: viewModel.date) { _ in
                    viewModel.requestPreviewRefresh()
                }

                Text(viewModel.weekdayLabel)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title3)
    }
}

#Preview {
    HeaderFormView(viewModel: ReportViewModel())
        .padding()
        .frame(width: 480)
}

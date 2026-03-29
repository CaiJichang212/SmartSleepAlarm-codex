import SwiftUI

public struct WatchRuntimeView: View {
    @StateObject private var viewModel: WatchRuntimeViewModel

    public init(viewModel: WatchRuntimeViewModel = .init()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(viewModel.stateText.capitalized)
                .font(.headline)
            Text(viewModel.detailText)
                .font(.caption2)
                .multilineTextAlignment(.center)

            Button("模拟响铃") {
                viewModel.simulatePrewarmAndRing()
            }
            .buttonStyle(.borderedProminent)

            Button("翻腕贪睡") {
                viewModel.triggerSnooze()
            }

            Button("手动关闭") {
                viewModel.dismiss()
            }
        }
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
    }
}

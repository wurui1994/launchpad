import SwiftUI
import AppKit

struct ContentView: View {
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("搜索应用", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 300)
                    .focused($isSearchFocused)
            }
            .padding()

            Text("输入内容将显示在下面：")
            Text(searchText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(minWidth: 420, minHeight: 160)
        .onAppear {
            // 延迟确保底层 NSViews 已建立
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true

                // 兼容做法：如果包装为 .app 并由系统启动，这段会成功把底层 NSTextField 设为 first responder
                if let window = NSApplication.shared.windows.first {
                    if let textField = findNSTextField(in: window.contentView) {
                        window.makeFirstResponder(textField)
                    }
                }
            }
        }
    }

    private func findNSTextField(in view: NSView?) -> NSTextField? {
        guard let view = view else { return nil }
        if let tf = view as? NSTextField { return tf }
        for sub in view.subviews {
            if let found = findNSTextField(in: sub) { return found }
        }
        return nil
    }
}
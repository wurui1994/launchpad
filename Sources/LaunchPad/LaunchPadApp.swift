import SwiftUI
import AppKit
import Carbon

import Foundation

func getAppDisplayName(at appPath: String) -> String? {
    let url = URL(fileURLWithPath: appPath)
    guard FileManager.default.fileExists(atPath: url.path),
          let bundle = Bundle(path: appPath) else {
        return nil
    }
    

    // Fallback: 使用 bundle.localizedInfoDictionary（当前 Locale）
    return bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        ?? bundle.localizedInfoDictionary?["CFBundleName"] as? String
        ?? (bundle.bundleURL.lastPathComponent as NSString).deletingPathExtension
}
    

// MARK: - BorderlessFullscreenWindow
final class BorderlessFullscreenWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        commonInit()
    }

    convenience init(screen: NSScreen) {
        self.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        self.setFrame(screen.frame, display: false, animate: false)
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isMovableByWindowBackground = false

        // 重要：不要包含任何 full screen 相关的 collectionBehavior
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // 让窗口可以成为 key 和 main
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.canHide = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Intercept cancelOperation (ESC) from responder chain as a safety net
    override func cancelOperation(_ sender: Any?) {
        LaunchpadState.shared.hide()
        // Do not call super — prevent default behavior
    }
}

// MARK: - LaunchpadState 单例（窗口与状态管理）
final class LaunchpadState: ObservableObject {
    static let shared = LaunchpadState()

    @Published private(set) var isVisible: Bool = false

    // 启动时是否自动显示（可在 App init 前设置或持久化到 UserDefaults）
    var showOnLaunch: Bool = false

    private var _mainWindow: BorderlessFullscreenWindow?
    var mainWindow: BorderlessFullscreenWindow? { _mainWindow }

    weak var searchField: NSSearchField?

    // Hotkey (Carbon)
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyId = EventHotKeyID(signature: OSType("LPad".fourCharCodeValue), id: 1)

    // local key monitor
    private var localKeyMonitor: Any?

    private init() {
        // 读 UserDefaults（可选）
        showOnLaunch = UserDefaults.standard.bool(forKey: "LaunchpadShowOnLaunch")
        // 不在 init 中创建窗口（延迟创建以便主屏信息可用）
        registerHotKey()
        startLocalKeyMonitor()
    }

    deinit {
        stopLocalKeyMonitor()
        unregisterHotKey()
    }

    // 创建（或返回）主窗口
    func ensureMainWindowCreated() {
        if _mainWindow != nil { return }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            // fallback: use a default frame
            let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
            let w = BorderlessFullscreenWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            _mainWindow = w
            setupContent(for: w)
            return
        }

        let w = BorderlessFullscreenWindow(screen: screen)
        // Put window above normal windows but below system alerts — choose appropriate level
        w.level = .screenSaver
        _mainWindow = w
        setupContent(for: w)
    }

    private func setupContent(for window: BorderlessFullscreenWindow) {
        // Host SwiftUI view inside NSHostingView
        let hosting = NSHostingView(rootView: LaunchpadRootView().environmentObject(self))
        hosting.frame = window.contentView?.bounds ?? window.frame
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        // Ensure exact frame to avoid macOS auto-fullscreen behavior
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.frame, display: false, animate: false)
        }
    }

    // 显示窗口
    func show() {
        DispatchQueue.main.async {
            self.ensureMainWindowCreated()
            guard let window = self._mainWindow else { return }

            // Ensure we set the frame to the actual screen to avoid any system full-screen
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(screen.frame, display: true, animate: false)
            }

            window.level = .screenSaver
            // Bring our app to front and present the window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)

            // Delay focusing search field to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                if let sf = self.searchField {
                    _ = window.makeFirstResponder(sf)
                }
            }

            self.isVisible = true
        }
    }

    // 隐藏窗口
    func hide() {
        DispatchQueue.main.async {
            guard let window = self._mainWindow else { return }
            window.orderOut(nil)
            self.isVisible = false
        }
    }

    func toggleVisibility() {
        if isVisible { hide() } else { show() }
    }

    // MARK: - Hotkey 注册（Command+Control+F）
    private func registerHotKey() {
        let virtualKey: UInt32 = UInt32(kVK_ANSI_F)
        let modifiers: UInt32 = UInt32(controlKey | cmdKey)

        let status = RegisterEventHotKey(
            virtualKey,
            modifiers,
            hotKeyId,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            installHotKeyHandler()
        } else {
            print("RegisterEventHotKey failed with status \(status)")
        }
    }

    private func unregisterHotKey() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
    }

    private func installHotKeyHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, theEvent, _) -> OSStatus in
                var hkID = EventHotKeyID()
                guard GetEventParameter(
                    theEvent,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                ) == noErr else {
                    return OSStatus(eventNotHandledErr)
                }

                if hkID.signature == "LPad".fourCharCodeValue && hkID.id == 1 {
                    DispatchQueue.main.async {
                        LaunchpadState.shared.toggleVisibility()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    // MARK: - 本地按键监听（用于拦截 ESC）
    private func startLocalKeyMonitor() {
        // Add local monitor that runs when events are delivered to this app.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // ESC key code is 53
            if event.keyCode == 53 {
                if self.isVisible {
                    self.hide()
                    // Return nil to indicate the event was handled and should not be forwarded.
                    return nil
                }
            }
            return event
        }
    }

    private func stopLocalKeyMonitor() {
        if let m = localKeyMonitor {
            NSEvent.removeMonitor(m)
            localKeyMonitor = nil
        }
    }
}

// MARK: - AppDelegate Bridge (handle Dock clicks)
final class AppDelegateBridge: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LaunchpadState.shared.toggleVisibility()
        return true
    }
}

// Keep a global instance of delegate to avoid being freed
private let appDelegate = AppDelegateBridge()

// MARK: - Main App
@main
struct LaunchpadXApp: App {
    @StateObject private var state = LaunchpadState.shared

    init() {
        // 如果你想在启动前通过代码启用「启动时显示」，可以在这里设置：
        // e.g. 
        LaunchpadState.shared.showOnLaunch = true
        // 或使用 UserDefaults 设置持久化选项。

        // Ensure NSApplication delegate is set on main thread
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.delegate = appDelegate

            // 1) 立刻确保我们的自定义窗口被创建并完全配置（但不要显示）
            //    这样可以尽早占有将要显示的 frame & content，避免系统创建并显示默认窗口内容。
            LaunchpadState.shared.ensureMainWindowCreated()

            // 2) 隐藏所有非我们自定义的窗口（尽可能即时）
            //    直接遍历当前已经存在的窗口并 orderOut，以防短暂可见。
            for w in NSApp.windows {
                if !(w is BorderlessFullscreenWindow) {
                    w.orderOut(nil)
                }
            }

            // 3) 如果需要启动时自动显示，则立即显示自定义窗口（同步调用，避免再用较长延迟）
            if LaunchpadState.shared.showOnLaunch {
                // 直接调用 show()，show() 内部会确保 window frame 已设置并 makeKeyAndOrderFront
                LaunchpadState.shared.show()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            // Keep a minimal invisible view — real UI is hosted inside our BorderlessFullscreenWindow.
            EmptyView()
                .onAppear {
                    // 隐藏 SwiftUI 自动创建的 window（更保险）
                    if let w = NSApp.windows.first(where: { !($0 is BorderlessFullscreenWindow) }) {
                        w.orderOut(nil)
                    }
                    // Ensure our window is created (but do not show immediately unless showOnLaunch is true)
                    state.ensureMainWindowCreated()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("关于 启动台") { showAbout() }
            }
            CommandGroup(before: .toolbar) {
                Button(state.isVisible ? "隐藏 启动台" : "显示 启动台") {
                    state.toggleVisibility()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }

    private func showAbout() {
        let a = NSAlert()
        a.messageText = "启动台"
        a.informativeText = "版本 1.0 — 自建 borderless 窗口，不使用系统原生全屏"
        a.addButton(withTitle: "确定")
        a.runModal()
    }
}

// MARK: - UI: LaunchpadRootView（主视图）
struct LaunchpadRootView: View {
    @EnvironmentObject private var state: LaunchpadState

    @State private var allApps: [AppInfo] = []
    @State private var filteredApps: [AppInfo] = []
    @State private var searchText: String = ""
    @State private var loading = true

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 18) {
                SearchFieldView(text: $searchText) { field in
                    // Hold weak reference so LaunchpadState can focus it when showing
                    state.searchField = field
                }
                .padding(.top, 40)
                .padding(.horizontal, 40)

                if loading {
                    ProgressView("加载应用…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if filteredApps.isEmpty {
                        Text("未找到应用")
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: gridColumns(screenWidth: NSScreen.main?.frame.width ?? 1440), spacing: 24) {
                                ForEach(filteredApps) { app in
                                    AppIconView(app: app)
                                        .onTapGesture {
                                            openApp(path: app.path)
                                            state.hide()
                                        }
                                }
                            }
                            .padding(40)
                        }
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            if loading { loadApplications() }
        }
        .onChange(of: searchText) { _ in
            filterApps()
        }
    }

    private func gridColumns(screenWidth: CGFloat) -> [GridItem] {
        let itemMinWidth: CGFloat = 120
        let count = max(4, Int(screenWidth / itemMinWidth))
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    private func getAppNameFromSpotlight(from appPath: String) -> String? {
        guard let item = MDItemCreate(nil, appPath as CFString) else {
            return nil
        }
        
        guard let displayName = MDItemCopyAttribute(item, kMDItemDisplayName) else {
            return nil
        }
        
        return displayName as? String
    }

    private func loadApplications() {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [AppInfo] = []
            let searchDirs = [
                "/Applications",
                "/System/Applications",
                "/System/Applications/Utilities",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
            ]

            for dir in searchDirs where FileManager.default.fileExists(atPath: dir) {
                do {
                    let names = try FileManager.default.contentsOfDirectory(atPath: dir)
                    for name in names where name.hasSuffix(".app") {
                        print("name", name)
                        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
                        print("url", url.path)
                        // let displayName = url.deletingPathExtension().lastPathComponent
                        let displayName = getAppDisplayName(at: url.path)!
                        // let displayName = getAppNameFromSpotlight(from: url.path)!
                        print("displayName", displayName)
                        let icon = NSWorkspace.shared.icon(forFile: url.path)
                        icon.size = NSSize(width: 128, height: 128)
                        results.append(AppInfo(name: displayName, path: url.path, icon: icon))
                    }
                } catch {
                    // ignore
                }
            }

            // Unique & sort
            let unique = results.uniqued().sorted { $0.name.lowercased() < $1.name.lowercased() }

            DispatchQueue.main.async {
                self.allApps = unique
                self.filteredApps = unique
                self.loading = false
            }
        }
    }

    private func filterApps() {
        if searchText.isEmpty {
            filteredApps = allApps
        } else {
            let q = searchText.lowercased()
            filteredApps = allApps.filter { $0.name.lowercased().contains(q) }
        }
    }

    private func openApp(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let err = error {
                DispatchQueue.main.async {
                    let a = NSAlert()
                    a.messageText = "打开失败"
     a.informativeText = err.localizedDescription
                    a.addButton(withTitle: "确定")
                    a.runModal()
                }
            }
        }
    }
}

// MARK: - App data & views
struct AppInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.path == rhs.path
    }
}

extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        var seen: [Element] = []
        for e in self where !seen.contains(e) {
            seen.append(e)
        }
        return seen
    }
}

struct AppIconView: View {
    let app: AppInfo

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(12)
                .shadow(radius: 6)

            Text(app.name)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 90)
        }
        .padding(6)
        .background(Color.white.opacity(0.02))
        .cornerRadius(10)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - SearchFieldView (NSViewRepresentable)
struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    let onSetup: (NSSearchField) -> Void

    init(text: Binding<String>, onSetup: @escaping (NSSearchField) -> Void = { _ in }) {
        _text = text
        self.onSetup = onSetup
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField(frame: .zero)
        field.placeholderString = "搜索应用…"
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel

        if let cell = field.cell as? NSSearchFieldCell {
            cell.cancelButtonCell?.isBordered = false
            cell.searchButtonCell?.isBordered = false
        }

        onSetup(field)
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldView
        init(_ parent: SearchFieldView) {
            self.parent = parent
            super.init()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        // Do NOT override cancelOperation here — Coordinator is not in responder chain as NSResponder subclass.
    }
}

// MARK: - Visual Effect Background
struct VisualEffectBackground: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
            VisualEffectNSView(material: .hudWindow, blendingMode: .behindWindow)
        }
    }
}

struct VisualEffectNSView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Utilities
extension String {
    var fourCharCodeValue: OSType {
        var result: OSType = 0
        for ch in utf8 {
            result = (result << 8) + OSType(ch)
        }
        return result
    }
}

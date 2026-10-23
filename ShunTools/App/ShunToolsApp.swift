import SwiftUI
import AppIntents

@main struct ShunToolsApp: App {
    @UIApplicationDelegateAdaptor(QuickActionDelegate.self) private var delegate
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("appLanguage") private var language = "system"
    @State private var library = LibraryStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(library).tint(Color.accentColor)
                .environment(\.locale, Locale(identifier: AppLanguage.resolved)).id(language)
                .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
                .task { FileStore.prune(); QuickActionDelegate.refresh(); await SupportStore.shared.load(); ShunBoxShortcuts.updateAppShortcutParameters() }
        }
    }
}
struct RootView: View {
    @State private var router = ToolRouter.shared
    @State private var previews = PreviewRouter.shared
    @AppStorage("welcomeCompleted") private var welcomeCompleted = false
    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(L("首页"), systemImage: "square.grid.2x2.fill", value: 0) { NavigationStack(path: $router.path) { HomeView() } }
            Tab(L("工具"), systemImage: "wrench.and.screwdriver", value: 1) { NavigationStack { CatalogView() } }
            Tab(L("媒体库"), systemImage: "photo.stack", value: 2) { NavigationStack { MediaLibraryView() } }
        }.fullScreenCover(isPresented: Binding(get: { !welcomeCompleted }, set: { _ in })) {
            WelcomeView { welcomeCompleted = true }
        }.task { _ = AdPolicy.shared
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("-uitest-media") { await PreviewFixtures.prepare() }
            #endif
        }
        .sheet(item: $previews.item) { FilePreviewView(item: $0) }
        .alert(L("无法读取文件"), isPresented: Binding(get: { previews.error != nil }, set: { if !$0 { previews.error = nil } })) { Button(L("好"), role: .cancel) {} } message: { Text(previews.error ?? "") }
    }
}
struct ToolDestination: View {
    let tool: Tool
    var body: some View {
        Group { switch tool { case .image: ImageToolView(); case .audio: AudioToolView(ringtone: false); case .ringtone: AudioToolView(ringtone: true); case .files: FileToolView(); case .pdf: PDFToolView(); case .imagePDF: ImageToolView(initialFormat: "pdf"); case .videoAudio: AudioToolView(ringtone: false, videoMode: true); case .deviceInfo: DeviceInfoView(); case .deviceCheck: DeviceCheckView(); case .qr: QRCodeToolView() } }
            .navigationTitle(tool.title).navigationBarTitleDisplayMode(.inline)
    }
}

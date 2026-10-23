import SwiftUI
struct WelcomeView: View {
    let complete: () -> Void
    @State private var showPurchase = false
    @State private var store = SupportStore.shared
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 16) {
                        Image("Mascot").resizable().scaledToFit().frame(width: 84, height: 84).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("欢迎使用顺匣")).font(.largeTitle.bold())
                            Text(L("小工具，大从容。")).foregroundStyle(.secondary)
                        }
                    }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(L("图片转换、压缩与相机水印"), systemImage: "photo")
                            Label(L("铃声剪辑、视频提取声音"), systemImage: "waveform")
                            Label(L("PDF 整理、二维码与设备自检"), systemImage: "square.grid.2x2")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(L("免费使用，也需要你的支持"), systemImage: "heart").font(.headline)
                        if BuildDistribution.isSideload {
                            Text(L("开源版本，所有功能免费且无广告。欢迎在 GitHub 反馈问题或参与改进。"))
                        } else {
                        Text(L("所有功能免费，不限次数。首次使用享 7 天无广告体验；之后转换完成时可能显示广告，用于支持开发与维护。"))
                        Text(L("一次购买可永久去广告，不订阅、不自动续费。不购买也能继续完整使用所有工具。"))
                        if !AdPolicy.shared.configured {
                            Text(L("当前版本暂未启用广告。启用后的广告规则如上，广告加载失败不会影响结果。"))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("权限由你决定")).font(.headline)
                        Text(L("照片：通过系统选择器导入，只在保存图片时申请添加照片。麦克风：仅在你开始录音自检时申请。iCloud：仅访问你主动选择的文件夹。"))
                        Text(L("现在不会集中索取权限。拒绝某项权限，只影响对应功能。广告跟踪需要另行征得同意，拒绝不影响工具使用。"))
                    }.font(.subheadline).foregroundStyle(.secondary)
                    Button(L("继续免费使用"), action: complete).buttonStyle(.glassProminent).tint(.brandButton).controlSize(.large).frame(maxWidth: .infinity).accessibilityIdentifier("welcome.continue")
                    if !BuildDistribution.isSideload {
                    Button(store.product.map { L("永久去广告 · {0}", $0.displayPrice) } ?? L("了解永久去广告")) { showPurchase = true }
                        .frame(maxWidth: .infinity)
                    Button(L("恢复购买")) { Task { await store.restore() } }.disabled(store.busy).frame(maxWidth: .infinity)
                    if !store.message.isEmpty { Text(store.message).font(.footnote) }
                    } else { Link(L("访问 GitHub"), destination: BuildDistribution.repository).frame(maxWidth: .infinity) }
                }.padding(24)
            }.background(BrandBackground())
                .sheet(isPresented: $showPurchase) { NavigationStack { SupportView().toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("关闭")) { showPurchase = false } } } } }
                .task { await store.load() }
        }.interactiveDismissDisabled()
    }
}
struct BrandBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(colors: scheme == .dark ? [Color(red: 0.08, green: 0.08, blue: 0.15), Color(red: 0.14, green: 0.09, blue: 0.14), Color(.systemGroupedBackground)] : [Color(red: 0.92, green: 0.93, blue: 1), Color(red: 1, green: 0.94, blue: 0.93), Color(red: 0.91, green: 0.97, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

extension Color { static let brandButton = Color(red: 0.36, green: 0.34, blue: 0.73) }

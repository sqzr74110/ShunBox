import SwiftUI
import StoreKit

@MainActor @Observable final class SupportStore {
    static let shared = SupportStore()
    static let productID = "com.shuntools.removeads.lifetime"
    var product: Product?
    var supported = false
    var entitlementsLoaded = false
    var busy = false
    var message = ""
    private var entitlementRevision = 0
    private var updates: Task<Void, Never>?
    private init() {
        guard !BuildDistribution.isSideload else { entitlementsLoaded = true; return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result, transaction.productID == Self.productID {
                    await self.refreshEntitlement(); await transaction.finish()
                }
            }
        }
    }
    func refreshEntitlement() async {
        entitlementRevision += 1
        let revision = entitlementRevision
        var valid = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID, transaction.revocationDate == nil, !transaction.isUpgraded { valid = true }
        }
        guard revision == entitlementRevision else { return }
        supported = valid; entitlementsLoaded = true
    }
    func load() async {
        guard !BuildDistribution.isSideload else { entitlementsLoaded = true; return }
        await refreshEntitlement()
        do { product = try await Product.products(for: [Self.productID]).first }
        catch { message = L("暂时无法连接 App Store，请稍后重试。") }
    }
    func purchase() async {
        guard !BuildDistribution.isSideload, !busy, let product else { return }
        busy = true; message = ""; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { message = L("无法验证购买，请稍后恢复购买。"); return }
                await refreshEntitlement(); await transaction.finish()
                message = L("谢谢支持！已永久去广告。")
            case .pending: message = L("购买等待批准，完成后将自动更新。")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = error.localizedDescription }
    }
    func restore() async {
        guard !BuildDistribution.isSideload, !busy else { return }; busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refreshEntitlement(); message = supported ? L("已恢复永久去广告。") : L("当前 Apple 账户没有可恢复的购买。") }
        catch { message = error.localizedDescription }
    }
}
struct SupportView: View {
    @State private var store = SupportStore.shared
    var body: some View {
        Form {
            if BuildDistribution.isSideload {
                Section {
                    Label(L("顺匣"), systemImage: "heart.fill").font(.title2.bold()).foregroundStyle(.pink)
                    Text(L("开源版本，所有功能免费且无广告。欢迎在 GitHub 反馈问题或参与改进。"))
                    Link(L("访问 GitHub"), destination: BuildDistribution.repository)
                }
            } else {
            Section {
                Label(L("永久去广告，支持独立创作"), systemImage: "heart.fill").font(.title2.bold()).foregroundStyle(.pink)
                Text(L("所有工具永久免费，不限使用次数。支持完全自愿，不影响任何功能。"))
                Text(L("一次购买，永久去广告，不订阅、不自动续费。当前版本广告尚未启用。可使用同一 Apple 账户恢复购买。"))
            }
            Section {
                if store.supported { Label(L("感谢你的支持"), systemImage: "checkmark.seal.fill") }
                else if let product = store.product {
                    Button(L("永久去广告 · {0}", product.displayPrice)) { Task { await store.purchase() } }.disabled(store.busy)
                } else {
                    Text(L("支持商品暂不可用，请稍后重试。所有工具仍可正常使用。"))
                    Button(L("重新加载")) { Task { await store.load() } }.disabled(store.busy)
                }
                Button(L("恢复购买")) { Task { await store.restore() } }.disabled(store.busy)
                if store.busy { ProgressView() }
                if !store.message.isEmpty { Text(store.message).foregroundStyle(.secondary) }
            }
            }
        }.navigationTitle(L("支持作者")).task { await store.load() }
    }
}
struct SupportCard: View {
    @State private var store = SupportStore.shared
    var body: some View {
        if !store.supported {
            NavigationLink { SupportView() } label: {
                HStack(spacing: 14) {
                    Image(systemName: "heart").font(.title2).foregroundStyle(.pink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("喜欢顺匣？支持一下作者")).font(.subheadline.bold())
                        Text(L("工具永久免费 · 自愿支持")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                }.padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)
        }
    }
}

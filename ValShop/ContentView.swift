import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var shopModel: ShopViewModel
    @StateObject private var watchlist = WatchlistStore()
    @State private var showingAccount = false
    @State private var showingWatchlist = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if accountStore.credential == nil {
                            welcomeCard
                        } else {
                            shopContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await shopModel.reload(using: accountStore.credential)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAccount) {
                AccountView()
                    .environmentObject(accountStore)
                    .environmentObject(shopModel)
            }
            .sheet(isPresented: $showingWatchlist) {
                WatchlistView(items: shopModel.items)
                    .environmentObject(watchlist)
            }
            .task(id: accountStore.credential) {
                if accountStore.credential != nil, shopModel.items.isEmpty {
                    await shopModel.reload(using: accountStore.credential)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("VALORANT SHOP")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(-0.7)
                Text(Date.now, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showingAccount = true } label: {
                ZStack {
                    Circle().fill(.white).shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                    Image(systemName: accountStore.credential == nil ? "person.crop.circle.badge.plus" : "person.crop.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles.tv.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text("每天换一套心情")
                    .font(.title2.bold())
                Text("绑定你的无畏契约账号，查看今日商店与心愿清单。所有数据只保存在本机。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { showingAccount = true } label: {
                Label("绑定账号", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(22)
        .glassCard()
    }

    private var shopContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日上架")
                        .font(.title2.bold())
                    if let lastUpdated = shopModel.lastUpdated {
                        Text("更新于 \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { showingWatchlist = true } label: {
                    Label("心愿", systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }

            if shopModel.isLoading && shopModel.items.isEmpty {
                LoadingCard()
            } else if let error = shopModel.errorMessage {
                ErrorCard(message: error) {
                    Task { await shopModel.reload(using: accountStore.credential) }
                }
            } else if shopModel.items.isEmpty {
                EmptyCard()
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(shopModel.items) { item in
                        ShopItemCard(item: item, isFavorite: watchlist.contains(item.name)) {
                            watchlist.toggle(item.name)
                        }
                    }
                }
            }
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white, Color(red: 0.98, green: 0.98, blue: 0.97), Color(red: 0.94, green: 0.96, blue: 0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppTheme.red.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 45)
                .offset(x: 90, y: -80)
        }
    }
}

private struct ShopItemCard: View {
    let item: ShopItem
    let isFavorite: Bool
    let onFavorite: () -> Void
    @State private var revealed = false
    @State private var opening = false

    var body: some View {
        Button(action: reveal) {
            ZStack {
                if revealed {
                    revealedCard
                } else {
                    mysteryCard
                }
                if opening { RevealBurst(color: qualityColor) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 176)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(qualityColor.opacity(0.55), lineWidth: revealed ? 1.5 : 1))
            .shadow(color: qualityColor.opacity(revealed ? 0.20 : 0.08), radius: revealed ? 14 : 5, y: 6)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isFavorite ? AppTheme.red : .white.opacity(0.9))
                    .padding(12)
            }
            .buttonStyle(.plain)
        }
    }

    private var mysteryCard: some View {
        ZStack {
            Color(red: 0.12, green: 0.18, blue: 0.24)
            MysteryGrid()
            VStack(spacing: 9) {
                Image(systemName: "questionmark")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(16)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.82), lineWidth: 2).rotationEffect(.degrees(45)))
                Text("点击揭晓").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var revealedCard: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.backgroundURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() }
                else { Color(red: 0.11, green: 0.18, blue: 0.25) }
            }
            .overlay(.black.opacity(0.15))
            .clipped()
            AsyncImage(url: item.imageURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFit().padding(.horizontal, 34).padding(.top, 8) }
                else { Image(systemName: "shippingbox.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.35)) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.headline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.category).font(.caption).foregroundStyle(.white.opacity(0.78))
                    Text("¥\(item.price)").font(.subheadline.bold()).foregroundStyle(.white)
                }
            }
            .padding(15)
        }
    }

    private func reveal() {
        guard !revealed, !opening else { return }
        opening = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) { revealed = true }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.2)) { opening = false }
        }
    }

    private var qualityColor: Color {
        let value = (item.rarity + item.category).lowercased()
        if value.contains("限定") || value.contains("exclusive") { return Color(red: 0.98, green: 0.34, blue: 0.42) }
        if value.contains("卓越") || value.contains("premium") { return Color(red: 0.72, green: 0.40, blue: 0.92) }
        if value.contains("豪华") || value.contains("deluxe") { return Color(red: 0.30, green: 0.57, blue: 0.94) }
        if value.contains("精选") || value.contains("select") { return Color(red: 0.30, green: 0.76, blue: 0.58) }
        return Color(red: 0.58, green: 0.67, blue: 0.74)
    }
}

private struct MysteryGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let step: CGFloat = 42
                for x in stride(from: -proxy.size.height, through: proxy.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x + proxy.size.height, y: proxy.size.height))
                }
                for x in stride(from: 0, through: proxy.size.width + proxy.size.height, by: step) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x - proxy.size.height, y: proxy.size.height))
                }
            }
            .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct RevealBurst: View {
    let color: Color
    @State private var scale = 0.2
    @State private var opacity = 0.9

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 3).scaleEffect(scale).opacity(opacity)
            ForEach(0..<8, id: \.self) { index in
                Capsule().fill(color).frame(width: 3, height: 24).offset(y: -42).rotationEffect(.degrees(Double(index) * 45)).scaleEffect(scale)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) { scale = 2.6; opacity = 0 }
        }
    }
}

private struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(AppTheme.accent).scaleEffect(1.2)
            Text("正在同步今日商店…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 56).glassCard()
    }
}

private struct EmptyCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill").font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text("今天还没有可用商品").font(.headline)
            Text("下拉刷新试试").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 45).glassCard()
    }
}

private struct ErrorCard: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.orange)
            Text(message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("重新加载", action: retry).buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity).padding(.vertical, 34).glassCard()
    }
}

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var shopModel: ShopViewModel
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 16) {
                    if let credential = accountStore.credential {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(AppTheme.accent)
                            Text(credential.nickname ?? "已绑定账号").font(.title3.bold())
                            Text("ID  \(credential.userId)").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 18)
                        Button { Task { await shopModel.reload(using: credential); dismiss() } } label: {
                            Label("立即刷新商店", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }.buttonStyle(PrimaryButtonStyle())
                        Button("解除绑定") { accountStore.clear(); shopModel.errorMessage = nil; dismiss() }
                            .foregroundStyle(.red.opacity(0.85)).padding(.top, 8)
                    } else {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 54)).foregroundStyle(AppTheme.accent)
                        Text("绑定无畏契约账号").font(.title2.bold())
                        Text("扫码登录后，商店数据会直接从官方接口同步。")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button { showingLogin = true } label: {
                            Label("QQ 扫码登录", systemImage: "qrcode")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }.buttonStyle(PrimaryButtonStyle())
                        Text("登录参数只保存在本机，不会上传到第三方服务器。")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 8)
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showingLogin) { QRLoginView().environmentObject(accountStore) }
        }
    }
}

private struct QRLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @StateObject private var model = QRLoginViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 20) {
                    if let payload = model.payload, let image = UIImage(data: payload.imageData) {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 230, height: 230)
                            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
                        Text("请使用 QQ 扫码并确认").font(.headline)
                    } else {
                        Image(systemName: "qrcode").font(.system(size: 130, weight: .thin)).foregroundStyle(.secondary.opacity(0.35))
                    }
                    Text(model.message).font(.subheadline).foregroundStyle(.secondary)
                    if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center) }
                    Button { model.begin(accountStore: accountStore) } label: {
                        if model.isWorking { ProgressView().tint(.black) } else { Text(model.payload == nil ? "生成二维码" : "重新生成") }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(model.isWorking)
                    Text("二维码有效期有限，失效后请重新生成。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Spacer()
                }.padding(24)
            }
            .navigationTitle("QQ 扫码登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
            .onDisappear { model.cancel() }
            .onChange(of: model.didLogin) { _, didLogin in
                if didLogin { dismiss() }
            }
        }
    }
}

@MainActor
private final class QRLoginViewModel: ObservableObject {
    @Published private(set) var payload: QRLoginPayload?
    @Published private(set) var isWorking = false
    @Published private(set) var message = "点击下方生成二维码"
    @Published private(set) var error: String?
    @Published private(set) var didLogin = false

    private let service = QRLoginService()
    private var task: Task<Void, Never>?

    func begin(accountStore: AccountStore) {
        task?.cancel()
        isWorking = true
        error = nil
        didLogin = false
        message = "正在生成二维码…"
        task = Task { [weak self, weak accountStore] in
            guard let self else { return }
            do {
                let newPayload = try await service.makeQRCode()
                try Task.checkCancellation()
                payload = newPayload
                message = "等待扫码确认…"
                let result = try await service.waitForScan(newPayload)
                try Task.checkCancellation()
                accountStore?.save(ShopCredential(userId: result.userID, tid: result.tid, nickname: nil, openID: result.openID, uin: result.uin))
                message = "登录成功"
                didLogin = true
            } catch is CancellationError {
                return
            } catch {
                self.error = error.localizedDescription
                message = "登录未完成"
            }
            isWorking = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isWorking = false
    }

    deinit {
        task?.cancel()
    }
}

struct WatchlistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlist: WatchlistStore
    let items: [ShopItem]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    if watchlist.names.isEmpty {
                        Text("还没有收藏商品").foregroundStyle(.secondary).listRowBackground(Color.clear)
                    } else {
                        ForEach(watchlist.names, id: \.self) { name in
                            HStack { Image(systemName: "heart.fill").foregroundStyle(AppTheme.accent); Text(name); Spacer(); if items.contains(where: { $0.name == name }) { Text("今日上架").font(.caption).foregroundStyle(AppTheme.accent) } }
                                .listRowBackground(Color.white.opacity(0.06))
                        }.onDelete { offsets in offsets.map { watchlist.names[$0] }.forEach(watchlist.toggle) }
                    }
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("心愿清单")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

private enum AppTheme {
    static let red = Color(red: 0.95, green: 0.18, blue: 0.28)
    static let accent = red
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.foregroundStyle(.black).background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous)).opacity(configuration.isPressed ? 0.75 : 1).animation(.easeOut(duration: 0.15), value: configuration.isPressed) }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.foregroundStyle(.primary).background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 15, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.black.opacity(0.10))).opacity(configuration.isPressed ? 0.75 : 1) }
}

private extension View {
    @ViewBuilder
    func glassCard() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.08)))
        }
    }
}

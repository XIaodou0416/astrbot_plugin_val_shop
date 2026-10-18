import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var shopModel: ShopViewModel
    @StateObject private var watchlist = WatchlistStore()
    @State private var showingAccount = false
    @State private var showingWatchlist = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

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
                    .foregroundStyle(.white.opacity(0.56))
            }
            Spacer()
            Button { showingAccount = true } label: {
                ZStack {
                    Circle().fill(.white.opacity(0.10))
                    Image(systemName: accountStore.credential == nil ? "person.crop.circle.badge.plus" : "person.crop.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.62))
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
                            .foregroundStyle(.white.opacity(0.45))
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
                LazyVGrid(columns: columns, spacing: 14) {
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
            colors: [Color(red: 0.06, green: 0.07, blue: 0.12), Color(red: 0.13, green: 0.08, blue: 0.20), Color(red: 0.05, green: 0.06, blue: 0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppTheme.accent.opacity(0.16))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit().padding(10)
                    default: Image(systemName: "shippingbox.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.25))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background {
                    AsyncImage(url: item.backgroundURL) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                    }
                    .overlay(.black.opacity(0.30))
                    .clipped()
                }
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isFavorite ? AppTheme.accent : .white)
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .frame(minHeight: 38, alignment: .topLeading)
                HStack {
                    Text(item.category)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("¥\(item.price)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(12)
        }
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(AppTheme.accent).scaleEffect(1.2)
            Text("正在同步今日商店…").foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 56).glassCard()
    }
}

private struct EmptyCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill").font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text("今天还没有可用商品").font(.headline)
            Text("下拉刷新试试").font(.subheadline).foregroundStyle(.white.opacity(0.48))
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
            Text(message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.72))
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
    @State private var showingManual = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 16) {
                    if let credential = accountStore.credential {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(AppTheme.accent)
                            Text(credential.nickname ?? "已绑定账号").font(.title3.bold())
                            Text("ID  \(credential.userId)").font(.caption).foregroundStyle(.white.opacity(0.5))
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
                            .font(.subheadline).foregroundStyle(.white.opacity(0.58)).multilineTextAlignment(.center)
                        Button { showingLogin = true } label: {
                            Label("QQ 扫码登录", systemImage: "qrcode")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }.buttonStyle(PrimaryButtonStyle())
                        Button { showingManual = true } label: {
                            Label("手动填写凭证", systemImage: "key.horizontal")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }.buttonStyle(SecondaryButtonStyle())
                        Text("登录参数只保存在本机，不会上传到第三方服务器。")
                            .font(.caption).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).padding(.top, 8)
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showingLogin) { QRLoginView().environmentObject(accountStore) }
            .sheet(isPresented: $showingManual) { ManualCredentialView().environmentObject(accountStore) }
        }
    }
}

private struct QRLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @State private var payload: QRLoginPayload?
    @State private var isWorking = false
    @State private var message = "点击下方生成二维码"
    @State private var error: String?
    private let service = QRLoginService()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 20) {
                    if let payload, let image = UIImage(data: payload.imageData) {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 230, height: 230)
                            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
                        Text("请使用 QQ 扫码并确认").font(.headline)
                    } else {
                        Image(systemName: "qrcode").font(.system(size: 130, weight: .thin)).foregroundStyle(.white.opacity(0.25))
                    }
                    Text(message).font(.subheadline).foregroundStyle(.white.opacity(0.62))
                    if let error { Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center) }
                    Button { begin() } label: {
                        if isWorking { ProgressView().tint(.black) } else { Text(payload == nil ? "生成二维码" : "重新生成") }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(isWorking)
                    Text("二维码有效期有限。若登录参数发生变化，可返回账号页使用手动凭证。")
                        .font(.caption).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center)
                    Spacer()
                }.padding(24)
            }
            .navigationTitle("QQ 扫码登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
        }
    }

    private func begin() {
        isWorking = true; error = nil; message = "正在生成二维码…"
        Task {
            do {
                let newPayload = try await service.makeQRCode()
                payload = newPayload; message = "等待扫码确认…"
                let result = try await service.waitForScan(newPayload)
                accountStore.save(ShopCredential(userId: result.userID, tid: result.tid, nickname: nil, openID: result.openID, uin: result.uin))
                message = "登录成功"
                dismiss()
            } catch {
                self.error = error.localizedDescription
                message = "登录未完成"
            }
            isWorking = false
        }
    }
}

private struct ManualCredentialView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @State private var userID = ""
    @State private var tid = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 18) {
                    Text("如果扫码链路暂时不可用，可以从插件或已登录设备中填入这两个值。")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.58))
                    TextField("userId", text: $userID).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(ValTextFieldStyle())
                    SecureField("tid", text: $tid).textInputAutocapitalization(.never).textFieldStyle(ValTextFieldStyle())
                    Button("保存并查询") {
                        accountStore.save(ShopCredential(userId: userID.trimmingCharacters(in: .whitespacesAndNewlines), tid: tid.trimmingCharacters(in: .whitespacesAndNewlines), nickname: nil, openID: nil, uin: nil))
                        dismiss()
                    }.buttonStyle(PrimaryButtonStyle()).disabled(userID.isEmpty || tid.isEmpty)
                    Spacer()
                }.padding(24)
            }
            .navigationTitle("手动凭证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
        }
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

private enum AppTheme { static let accent = Color(red: 0.95, green: 0.68, blue: 0.32) }

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.foregroundStyle(.black).background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous)).opacity(configuration.isPressed ? 0.75 : 1).animation(.easeOut(duration: 0.15), value: configuration.isPressed) }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.foregroundStyle(.white).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 15, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.10))).opacity(configuration.isPressed ? 0.75 : 1) }
}

private struct ValTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { configuration.padding(15).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(.white).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10))) }
}

private extension View {
    func glassCard() -> some View { background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.09))) }
}

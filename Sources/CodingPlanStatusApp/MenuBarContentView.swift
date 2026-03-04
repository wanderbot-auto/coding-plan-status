import SwiftUI
import AppKit
import CodingPlanStatusCore

struct MenuBarContentView: View {
    @ObservedObject var appState: AppState
    @State private var isCredentialExpanded = false

    private var overallSeverity: StatusSeverity {
        StatusAggregator.overallSeverity(from: appState.latestStatuses)
    }

    private var credentialReadyCount: Int {
        [appState.glmToken, appState.minimaxToken, appState.minimaxGroupId]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .count
    }

    private var glmConfigured: Bool {
        appState.glmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var minimaxConfigured: Bool {
        appState.minimaxToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && appState.minimaxGroupId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.primary300.opacity(0.58), AppTheme.bg100],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Circle()
                    .fill(AppTheme.primary100.opacity(0.15))
                    .frame(width: 240, height: 240)
                    .blur(radius: 36)
                    .offset(x: -100, y: -180)
            )
            .overlay(
                Circle()
                    .fill(AppTheme.accent100.opacity(0.14))
                    .frame(width: 220, height: 220)
                    .blur(radius: 34)
                    .offset(x: 150, y: 230)
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                headerSection
                providerSection
                credentialSection
                if let message = appState.lastErrorMessage, message.isEmpty == false {
                    errorSection(message)
                }
                footerSection
            }
            .padding(14)
        }
        .frame(width: 392)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coding Plan 监控")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text100)
                    Text("GLM + MiniMAX")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.text200)
                }
                Spacer()
                StatusPill(severity: overallSeverity)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await appState.refreshNow() }
                } label: {
                    Label("立即刷新", systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Spacer()

                if let refreshAt = appState.lastRefreshAt {
                    Text("更新于 \(refreshAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.text200)
                        .monospacedDigit()
                } else {
                    Text("尚未刷新")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.text200)
                }
            }
        }
        .padding(12)
        .frostedPanel(stroke: AppTheme.primary200.opacity(0.35))
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("平台状态")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.text100)

            ForEach(appState.providerSummaries, id: \.provider) { summary in
                ProviderCard(summary: summary)
            }
        }
    }

    private var credentialSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCredentialExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.primary100)
                        .frame(width: 20, height: 20)
                        .background(AppTheme.primary300.opacity(0.65))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("凭据配置")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.text100)
                        Text("已配置 \(credentialReadyCount)/3 · Keychain 安全存储")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.text200)
                    }

                    Spacer()

                    Text(isCredentialExpanded ? "收起" : "展开")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.text200)
                    Image(systemName: isCredentialExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.text200)
                }
            }
            .buttonStyle(.plain)

            if isCredentialExpanded {
                HStack(spacing: 6) {
                    TinyBadge(text: glmConfigured ? "GLM 已配置" : "GLM 未配置", tint: glmConfigured ? AppTheme.accent100 : AppTheme.bg300)
                    TinyBadge(text: minimaxConfigured ? "MiniMAX 已配置" : "MiniMAX 未配置", tint: minimaxConfigured ? AppTheme.accent100 : AppTheme.bg300)
                    TinyBadge(text: "仅本机可见", tint: AppTheme.primary200)
                }

                VStack(alignment: .leading, spacing: 8) {
                    CredentialInputField(
                        title: "GLM Token",
                        subtitle: "用于读取 GLM coding plan 使用状态",
                        icon: "bolt.horizontal.circle",
                        statusText: glmConfigured ? "已填" : "未填",
                        statusTint: glmConfigured ? AppTheme.accent100 : AppTheme.bg300
                    ) {
                        SecureField("输入 GLM Token", text: $appState.glmToken)
                    }
                    CredentialInputField(
                        title: "MiniMAX Token",
                        subtitle: "用于读取 MiniMAX 计划余量",
                        icon: "waveform.path.ecg.rectangle",
                        statusText: appState.minimaxToken.isEmpty ? "未填" : "已填",
                        statusTint: appState.minimaxToken.isEmpty ? AppTheme.bg300 : AppTheme.accent100
                    ) {
                        SecureField("输入 MiniMAX Token", text: $appState.minimaxToken)
                    }
                    CredentialInputField(
                        title: "MiniMAX GroupId",
                        subtitle: "账号归属组标识，通常与 Token 配套",
                        icon: "person.2.circle",
                        statusText: appState.minimaxGroupId.isEmpty ? "未填" : "已填",
                        statusTint: appState.minimaxGroupId.isEmpty ? AppTheme.bg300 : AppTheme.accent100
                    ) {
                        TextField("输入 GroupId", text: $appState.minimaxGroupId)
                    }
                }

                HStack {
                    Button {
                        appState.saveCredentials()
                        Task { await appState.refreshNow() }
                    } label: {
                        Label("保存并刷新", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        appState.glmToken = ""
                        appState.minimaxToken = ""
                        appState.minimaxGroupId = ""
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .buttonStyle(TertiaryActionButtonStyle())

                    Spacer()
                }
            }
        }
        .padding(12)
        .frostedPanel(stroke: AppTheme.bg300.opacity(0.55))
    }

    private func errorSection(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.accent200)
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.text100)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedPanel(stroke: AppTheme.primary200.opacity(0.4), cornerRadius: 12)
    }

    private var footerSection: some View {
        HStack {
            Text("本地存储 90 天历史数据")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.text200)
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent200)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }
}

private struct ProviderCard: View {
    let summary: ProviderSummary

    private var status: PlanStatus? { summary.status }

    var body: some View {
        let severity = status?.severity ?? .unsupported
        let tint = AppTheme.statusTint(severity)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                ZStack {
                    Circle()
                        .fill(AppTheme.providerTint(summary.provider).opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: AppTheme.providerSymbol(summary.provider))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.providerTint(summary.provider))
                }

                Text(summary.provider.rawValue.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.text100)

                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.text200)
                    .help(interfaceHelpText(for: summary.provider))
                Spacer()
                StatusPill(severity: severity)
            }

            if let status {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("已用")
                        Spacer()
                        Text("\(Int(status.usedPercent))%")
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.text100)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.bg300.opacity(0.35))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tint)
                                .frame(width: max(8, geo.size.width * max(0, min(1, status.usedPercent / 100))), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Label("剩余", systemImage: "circle.grid.2x2")
                        Spacer()
                        Text("\(NSDecimalNumber(decimal: status.remaining).stringValue) \(status.remainingUnit)")
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.text200)

                    if let reset = status.resetAt {
                        HStack {
                            Label("重置", systemImage: "clock")
                            Spacer()
                            Text(reset.formatted(date: .abbreviated, time: .shortened))
                                .monospacedDigit()
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.text200)
                    }
                }
            } else {
                Text("暂无数据")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.text200)
            }
        }
        .padding(10)
        .frostedPanel(stroke: tint.opacity(0.5), cornerRadius: 12)
    }

    private func interfaceHelpText(for provider: ProviderID) -> String {
        switch provider {
        case .glm:
            return "GLM 域名:\napi.z.ai"
        case .minimax:
            return "MiniMAX 域名:\nwww.minimaxi.com"
        }
    }
}

private struct CredentialInputField<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let statusText: String
    let statusTint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent200)
                    .frame(width: 20, height: 20)
                    .background(AppTheme.primary300.opacity(0.45))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.text100)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.text200)
                }

                Spacer()
                TinyBadge(text: statusText, tint: statusTint)
            }

            content
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(AppTheme.bg100.opacity(0.62))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(AppTheme.primary200.opacity(0.22), lineWidth: 1)
                )
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.bg100.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.bg300.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct TinyBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.bg100)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.96))
            .clipShape(Capsule())
    }
}

private struct TertiaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.text200)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? AppTheme.bg300.opacity(0.30) : AppTheme.bg100.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.bg300.opacity(0.55), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatusPill: View {
    let severity: StatusSeverity

    var body: some View {
        Text(AppTheme.statusText(severity))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(AppTheme.bg100)
            .background(AppTheme.statusTint(severity))
            .clipShape(Capsule())
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.bg100)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? AppTheme.accent200 : AppTheme.primary100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.accent200)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? AppTheme.bg300.opacity(0.28) : AppTheme.bg100.opacity(0.52))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.primary200.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension View {
    func frostedPanel(stroke: Color, cornerRadius: CGFloat = 14) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.bg100.opacity(0.25))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: AppTheme.accent200.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

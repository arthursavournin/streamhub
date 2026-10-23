import SwiftUI

// Éléments de dessin des réglages et du compte, calqués sur le site (styles.css : .auth-card, .social-btn,
// .action-list, .settings-nav-item…) pour que les deux versions se ressemblent.

extension Color {
    static let appBorder = Color(red: 0x23 / 255, green: 0x33 / 255, blue: 0x52 / 255)
    static let appMuted = Color(red: 0x98 / 255, green: 0xa2 / 255, blue: 0xb6 / 255)
    static let appAccent = Color(red: 0x3a / 255, green: 0x7b / 255, blue: 0xf2 / 255)
    static let appDanger = Color(red: 1, green: 0x6b / 255, blue: 0x6b / 255)
}

extension LinearGradient {
    // Dégradé des boutons principaux (--accent-gradient du site)
    static let accent = LinearGradient(
        colors: [Color(red: 0x5e / 255, green: 0xa2 / 255, blue: 1), Color(red: 0x2a / 255, green: 0x63 / 255, blue: 0xe6 / 255)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// Carte : fond, bord, coins arrondis
struct Card<Content: View>: View {
    var spacing: CGFloat = 14
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface, in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.appBorder))
    }
}

// Champ avec son libellé au-dessus (et un lien à droite du libellé : « Oublié ? »)
struct FieldBox<Aside: View>: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var secure = false
    var content: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var monospaced = false
    @ViewBuilder var aside: Aside

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(loc(label)).font(.subheadline.weight(.semibold))
                Spacer()
                aside
            }
            Group {
                if secure {
                    SecureField(loc(placeholder), text: $text)
                } else {
                    TextField(loc(placeholder), text: $text)
                        .keyboardType(keyboard)
                }
            }
            .textContentType(content)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(monospaced ? .body.monospaced() : .body)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.appBackground, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.appBorder))
        }
    }
}

extension FieldBox where Aside == EmptyView {
    init(label: String, text: Binding<String>, placeholder: String = "", secure: Bool = false, content: UITextContentType? = nil,
         keyboard: UIKeyboardType = .default, monospaced: Bool = false) {
        self.init(label: label, text: text, placeholder: placeholder, secure: secure, content: content, keyboard: keyboard,
                  monospaced: monospaced) { EmptyView() }
    }
}

// Bouton principal (dégradé), secondaire (fond de carte) ou dangereux
struct WideButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(kind == .secondary ? Color.primary : .white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                switch kind {
                case .primary: RoundedRectangle(cornerRadius: 12).fill(LinearGradient.accent)
                case .secondary: RoundedRectangle(cornerRadius: 12).fill(Color.appBackground)
                case .danger: RoundedRectangle(cornerRadius: 12).fill(Color(red: 0xc0 / 255, green: 0x39 / 255, blue: 0x2b / 255))
                }
            }
            .overlay { if kind == .secondary { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.appBorder) } }
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

// « Continuer avec Google » (fond blanc, logo en couleurs, comme le demande Google) / « Continuer avec GitHub » (fond noir)
struct SocialButton: View {
    let provider: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if provider == "google" {
                    Image(.googleLogo).resizable().frame(width: 20, height: 20)
                } else {
                    Image(.gitHubLogo).resizable().renderingMode(.template).frame(width: 20, height: 20)
                }
                Text(loc("Continuer avec \(AccountService.providers[provider] ?? provider)")).font(.body.weight(.semibold))
            }
            .foregroundStyle(provider == "google" ? Color(white: 0.12) : .white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(provider == "google" ? Color.white : Color(red: 0x0d / 255, green: 0x11 / 255, blue: 0x17 / 255), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(provider == "google" ? Color(white: 0.86) : Color(red: 0x30 / 255, green: 0x36 / 255, blue: 0x3d / 255)))
        }
        .buttonStyle(.plain)
    }
}

// Trait « ou » entre deux façons de se connecter
struct OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.appBorder).frame(height: 1)
            Text(loc("ou")).font(.footnote).foregroundStyle(Color.appMuted)
            Rectangle().fill(Color.appBorder).frame(height: 1)
        }
    }
}

// Icône d'une section des réglages (carré arrondi teinté, comme .group-icon du site)
struct SectionIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color.mine)
            .frame(width: 36, height: 36)
            .background(Color.appAccent.opacity(0.16), in: .rect(cornerRadius: 10))
    }
}

// Ligne de la liste des réglages : icône, titre, résumé, chevron
struct SettingsRowLabel: View {
    let icon: String
    let title: String
    var summary: String?

    var body: some View {
        HStack(spacing: 14) {
            SectionIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc(title)).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if let summary, !summary.isEmpty {
                    Text(loc(summary)).font(.subheadline).foregroundStyle(Color.appMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.appMuted)
        }
        .padding(12)
        .background(Color.appSurface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.appBorder))
        .contentShape(.rect)
    }
}

// Liste d'actions du compte (une carte, des lignes séparées par un trait)
struct ActionList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Rectangle().fill(Color.appBorder).frame(height: 1) }
                    row
                }
            }
        }
        .background(Color.appSurface, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.appBorder))
        .clipShape(.rect(cornerRadius: 18))
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    var danger = false
    var chevron = false
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 18)).frame(width: 24).foregroundStyle(danger ? Color.appDanger : Color.mine)
                Text(loc(title)).foregroundStyle(danger ? Color.appDanger : .primary)
                Spacer()
                if busy { ProgressView() } else if chevron {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.appMuted)
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// En-tête d'une section des réglages (sous le titre de la barre de navigation), comme .panel-head p du site
struct PanelIntro: View {
    let text: String
    var body: some View {
        Text(loc(text)).font(.subheadline).foregroundStyle(Color.appMuted).frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Message d'état sous une action (vert : réussi ; rouge : erreur)
struct StatusText: View {
    let message: (text: String, ok: Bool)?
    var body: some View {
        if let message {
            Text(loc(message.text)).font(.footnote).foregroundStyle(message.ok ? Color.mine : Color.appDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

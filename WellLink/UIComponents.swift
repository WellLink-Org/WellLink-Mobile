// UIComponents.swift
// Small reusable views used across auth screens.
// Matches your web Logo + SocialButton + Divider components.

import UIKit

// ── MARK: LogoView ─────────────────────────────────────────────────────────────
/// Renders the WellLink logo (SVG‑equivalent drawn with CoreGraphics) + wordmark.
final class LogoView: UIView {

    private let iconView  = WellLinkIconView()
    private let wordmark  = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        wordmark.translatesAutoresizingMaskIntoConstraints = false

        wordmark.text      = "WellLink"
        wordmark.font      = .systemFont(ofSize: 22, weight: .bold)
        wordmark.textColor = UIColor(red: 0.12, green: 0.36, blue: 0.18, alpha: 1) // #1f5c2e

        addSubview(iconView)
        addSubview(wordmark)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            wordmark.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            wordmark.trailingAnchor.constraint(equalTo: trailingAnchor),
            wordmark.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}

/// Draws the circle + wave + dot icon using CoreGraphics (matches your SVG).
private final class WellLinkIconView: UIView {
    private let green     = UIColor(red: 0.12, green: 0.36, blue: 0.18, alpha: 1) // #1f5c2e
    private let dotGreen  = UIColor(red: 0.24, green: 0.62, blue: 0.33, alpha: 1) // #3d9e55

    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { super.init(coder: coder); backgroundColor = .clear }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let s = rect.width / 28   // scale factor (SVG was 28×28)

        // Outer circle
        let circleRect = CGRect(x: 1*s, y: 1*s, width: 26*s, height: 26*s)
        ctx.setStrokeColor(green.cgColor)
        ctx.setLineWidth(2 * s)
        ctx.addEllipse(in: circleRect)
        ctx.strokePath()

        // ECG wave: M8,14 Q11,8 14,14 Q17,20 20,14
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 8*s, y: 14*s))
        path.addQuadCurve(to: CGPoint(x: 14*s, y: 14*s),
                          controlPoint: CGPoint(x: 11*s, y: 8*s))
        path.addQuadCurve(to: CGPoint(x: 20*s, y: 14*s),
                          controlPoint: CGPoint(x: 17*s, y: 20*s))
        green.setStroke()
        path.lineWidth      = 2.2 * s
        path.lineCapStyle   = .round
        path.stroke()

        // Centre dot
        let dotRect = CGRect(x: 11.5*s, y: 11.5*s, width: 5*s, height: 5*s)
        dotGreen.setFill()
        UIBezierPath(ovalIn: dotRect).fill()
    }
}

// ── MARK: SocialLoginButton ────────────────────────────────────────────────────
enum SocialProvider { case google, apple }

final class SocialLoginButton: UIButton {

    private let provider: SocialProvider

    init(provider: SocialProvider) {
        self.provider = provider
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        var config                 = UIButton.Configuration.bordered()
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .secondarySystemBackground
        config.cornerStyle         = .medium
        config.imagePadding        = 10

        switch provider {
        case .google:
            config.title = "Continue with Google"
            config.image = googleIcon()
        case .apple:
            config.title = "Continue with Apple"
            config.image = UIImage(systemName: "apple.logo")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            )
        }
        self.configuration = config
        layer.borderWidth  = 1
        layer.borderColor  = UIColor.separator.cgColor
        layer.cornerRadius = 10
    }

    private func googleIcon() -> UIImage? {
        // Simple coloured "G" badge (no external assets needed)
        let size   = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        let label         = UILabel(frame: CGRect(origin: .zero, size: size))
        label.text        = "G"
        label.font        = .systemFont(ofSize: 16, weight: .bold)
        label.textColor   = UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1)
        label.textAlignment = .center
        label.drawHierarchy(in: label.bounds, afterScreenUpdates: true)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// ── MARK: PrimaryButton ────────────────────────────────────────────────────────
final class PrimaryButton: UIButton {

    init(title: String) {
        super.init(frame: .zero)
        var config                 = UIButton.Configuration.filled()
        config.title               = title
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(red: 0.24, green: 0.62, blue: 0.33, alpha: 1)
        config.cornerStyle         = .medium
        configuration              = config
        layer.cornerRadius         = 10
    }
    required init?(coder: NSCoder) { fatalError() }
}

// ── MARK: DividerView ──────────────────────────────────────────────────────────
final class DividerView: UIView {

    init(label: String) {
        super.init(frame: .zero)
        let left   = hairline()
        let right  = hairline()
        let lbl    = UILabel()
        lbl.text   = label
        lbl.font   = .systemFont(ofSize: 13)
        lbl.textColor = .tertiaryLabel

        [left, lbl, right].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: centerYAnchor),
            lbl.topAnchor.constraint(equalTo: topAnchor),
            lbl.bottomAnchor.constraint(equalTo: bottomAnchor),

            left.trailingAnchor.constraint(equalTo: lbl.leadingAnchor, constant: -8),
            left.leadingAnchor.constraint(equalTo: leadingAnchor),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            left.heightAnchor.constraint(equalToConstant: 0.5),

            right.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            right.trailingAnchor.constraint(equalTo: trailingAnchor),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        return v
    }
}

// ── MARK: FooterLinkLabel ─────────────────────────────────────────────────────
/// "Already have an account? Log in" — the link part is tappable.
final class FooterLinkLabel: UIView {

    var onLinkTap: (() -> Void)?

    init(text: String, linkText: String) {
        super.init(frame: .zero)

        let full = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        let link = NSAttributedString(
            string: linkText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor(red: 0.24, green: 0.62, blue: 0.33, alpha: 1)
            ]
        )
        full.append(link)

        let label              = UILabel()
        label.attributedText   = full
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onLinkTap?() }
}

// ── MARK: LoadingOverlay ───────────────────────────────────────────────────────
enum LoadingOverlay {
    private static weak var overlay: UIView?

    static func show(in view: UIView) {
        let bg               = UIView(frame: view.bounds)
        bg.backgroundColor   = UIColor.black.withAlphaComponent(0.35)
        bg.autoresizingMask  = [.flexibleWidth, .flexibleHeight]
        bg.tag               = 9_999

        let spinner          = UIActivityIndicatorView(style: .large)
        spinner.color        = .white
        spinner.center       = bg.center
        bg.addSubview(spinner)
        spinner.startAnimating()

        view.addSubview(bg)
        overlay = bg
    }

    static func hide() {
        overlay?.removeFromSuperview()
    }
}

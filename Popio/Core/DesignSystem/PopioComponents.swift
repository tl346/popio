import SwiftUI
import UIKit

struct KeyboardDismissRegistrar: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = RegistrarView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.onMoveToWindow = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: uiView.window)
        }
    }

    final class RegistrarView: UIView {
        var onMoveToWindow: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onMoveToWindow?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        func attach(to window: UIWindow?) {
            guard let window, self.window !== window else { return }

            if let recognizer {
                self.window?.removeGestureRecognizer(recognizer)
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.window = window
            self.recognizer = recognizer
        }

        @objc private func dismissKeyboard() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view

            while let currentView = view {
                if currentView is UIControl || currentView is UITextField || currentView is UITextView {
                    return false
                }
                view = currentView.superview
            }

            return true
        }
    }
}

struct MiniMenuSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(PopioTheme.ink.opacity(0.14))
                .frame(width: 42, height: 5)

            Text(title)
                .font(PopioFont.custom(size: 17, weight: .semibold))
                .foregroundStyle(PopioTheme.ink)

            VStack(spacing: 8) {
                content
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [
                    PopioTheme.backgroundElevated,
                    PopioTheme.gold.opacity(0.10),
                    PopioTheme.coralSoft.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

struct MiniMenuActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())

                Text(title)
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)

                Spacer()

                Image(systemName: "checkmark")
                    .font(PopioFont.custom(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .opacity(0)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MiniMenuChoiceRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())

                Text(title)
                    .font(PopioFont.custom(size: 15, weight: .semibold))
                    .foregroundStyle(PopioTheme.ink)

                Spacer()

                Image(systemName: "checkmark")
                    .font(PopioFont.custom(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(isSelected ? tint.opacity(0.13) : Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.34) : PopioTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryBadge: View {
    let category: EventCategory

    var body: some View {
        Text(category.rawValue)
            .font(PopioFont.caption2(.heavy))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.26), lineWidth: 1)
            }
    }

    private var color: Color {
        switch category {
        case .food:
            return PopioTheme.coral
        case .matcha:
            return PopioTheme.accent
        case .cards:
            return PopioTheme.gold
        case .farmersMarket:
            return PopioTheme.accent
        }
    }
}

struct RemoteImagePlaceholder: View {
    let category: EventCategory

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PopioTheme.gold.opacity(0.84),
                    PopioTheme.gold.opacity(0.74),
                    PopioTheme.accent.opacity(0.72),
                    PopioTheme.coral.opacity(0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: iconName)
                .font(PopioFont.custom(size: 36, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var iconName: String {
        switch category {
        case .food:
            return "fork.knife"
        case .matcha:
            return "cup.and.saucer.fill"
        case .cards:
            return "rectangle.stack.fill"
        case .farmersMarket:
            return "basket.fill"
        }
    }
}

struct ProfileAvatarView: View {
    let user: PopioUser?
    var size: CGFloat = 74

    var body: some View {
        Group {
            if let data = user?.profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = user?.profilePictureURL {
                CachedRemoteImage(url: url) {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(PopioTheme.backgroundElevated, lineWidth: max(2, size * 0.035))
        }
        .shadow(color: PopioTheme.shadow.opacity(0.55), radius: 10, y: 5)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PopioTheme.gold,
                    PopioTheme.gold.opacity(0.82),
                    PopioTheme.coralSoft
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.18))
                .padding(size * 0.12)

            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white.opacity(0.94))
                .padding(size * 0.28)
        }
    }
}

private final class RemoteImageMemoryCache {
    static let shared = RemoteImageMemoryCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

private struct CachedRemoteImage<Fallback: View>: View {
    let url: URL
    let fallback: Fallback
    @State private var image: UIImage?
    @State private var didLoad = false

    init(url: URL, @ViewBuilder fallback: () -> Fallback) {
        self.url = url
        self.fallback = fallback()
        _image = State(initialValue: RemoteImageMemoryCache.shared.image(for: url))
        _didLoad = State(initialValue: RemoteImageMemoryCache.shared.image(for: url) != nil)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .onAppear {
            loadIfNeeded()
        }
        .onChange(of: url) { _, _ in
            image = RemoteImageMemoryCache.shared.image(for: url)
            didLoad = image != nil
            loadIfNeeded()
        }
    }

    private func loadIfNeeded() {
        if let cachedImage = RemoteImageMemoryCache.shared.image(for: url) {
            image = cachedImage
            didLoad = true
            return
        }

        guard !didLoad else { return }
        didLoad = true

        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let loadedImage = UIImage(data: data) else {
                return
            }

            RemoteImageMemoryCache.shared.set(loadedImage, for: url)
            await MainActor.run {
                image = loadedImage
            }
        }
    }
}

struct EventBannerImageView: View {
    let event: PopioEvent

    var body: some View {
        BannerImageView(
            imageData: event.imageData,
            imageURL: event.imageURL,
            category: event.category,
            focusY: event.bannerFocusY
        )
    }
}

struct EventMenuImageView: View {
    let event: PopioEvent

    var body: some View {
        MenuPhotoView(
            imageData: event.menuImageData,
            imageURL: event.menuImageURL,
            category: event.category
        )
    }
}

struct MenuPhotoView: View {
    let imageData: Data?
    let imageURL: URL?
    let category: EventCategory

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        RemoteImagePlaceholder(category: category)
                    }
                }
            } else {
                RemoteImagePlaceholder(category: category)
            }
        }
    }
}

struct EventMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: PopioEvent

    var body: some View {
        NavigationStack {
            ScrollView {
                EventMenuImageView(event: event)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(16)
            }
            .background(PopioTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BannerImageView: View {
    let imageData: Data?
    let imageURL: URL?
    let category: EventCategory
    let focusY: Double

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    fittedImage(Image(uiImage: uiImage), in: proxy.size)
                } else if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            fittedImage(image, in: proxy.size)
                        default:
                            RemoteImagePlaceholder(category: category)
                        }
                    }
                } else {
                    RemoteImagePlaceholder(category: category)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private func fittedImage(_ image: Image, in size: CGSize) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .offset(y: bannerOffset(for: size.height))
            .clipped()
    }

    private func bannerOffset(for height: CGFloat) -> CGFloat {
        CGFloat(0.5 - min(max(focusY, 0), 1)) * height * 0.75
    }
}

enum LikeButtonSize {
    case compact
    case regular

    var iconSize: CGFloat {
        switch self {
        case .compact:
            return 13
        case .regular:
            return 16
        }
    }

    var font: Font {
        switch self {
        case .compact:
            return PopioFont.caption(.bold)
        case .regular:
            return PopioFont.subheadline(.bold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact:
            return 8
        case .regular:
            return 12
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact:
            return 5
        case .regular:
            return 8
        }
    }
}

struct LikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let size: LikeButtonSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: size.iconSize, weight: .bold))
                Text("\(likeCount)")
                    .font(size.font)
                    .monospacedDigit()
            }
            .foregroundStyle(isLiked ? PopioTheme.gold : PopioTheme.muted)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                (isLiked ? PopioTheme.gold.opacity(0.18) : PopioTheme.surface.opacity(0.72)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike event" : "Like event")
        .accessibilityValue("\(likeCount) likes")
    }
}

struct MetricPill: View {
    let systemImage: String
    let text: String
    var tint: Color = PopioTheme.accent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 12, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(PopioFont.caption(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 28, weight: .bold))
                .foregroundStyle(PopioTheme.gold)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [
                            PopioTheme.gold.opacity(0.18),
                            PopioTheme.accent.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(spacing: 5) {
                Text(title)
                    .font(PopioFont.headline(.bold))
                    .foregroundStyle(PopioTheme.ink)

                Text(message)
                    .font(PopioFont.subheadline(.medium))
                    .foregroundStyle(PopioTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
    }
}

private struct PopioCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
            .shadow(color: PopioTheme.shadow.opacity(0.22), radius: 14, y: 6)
    }
}

private struct PopioPrimaryButtonModifier: ViewModifier {
    var tint: Color

    func body(content: Content) -> some View {
        content
            .font(PopioFont.headline(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(tint, in: Capsule())
            .contentShape(Capsule())
    }
}

private struct PopioSecondaryButtonModifier: ViewModifier {
    var tint: Color

    func body(content: Content) -> some View {
        content
            .font(PopioFont.subheadline(.bold))
            .foregroundStyle(tint)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

private struct PopioFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(PopioFont.body(.semibold))
            .foregroundStyle(PopioTheme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(PopioTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PopioTheme.line, lineWidth: 1)
            }
    }
}

extension View {
    func popioCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(PopioCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func popioPrimaryButton(tint: Color = PopioTheme.gold) -> some View {
        modifier(PopioPrimaryButtonModifier(tint: tint))
    }

    func popioSecondaryButton(tint: Color = PopioTheme.gold) -> some View {
        modifier(PopioSecondaryButtonModifier(tint: tint))
    }

    func popioField() -> some View {
        modifier(PopioFieldModifier())
    }

    func popioScreenFont() -> some View {
        self.font(PopioFont.body())
    }

    @ViewBuilder
    func popioPlainTextInput() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func popioEmailInput() -> some View {
        #if os(iOS)
        self
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func popioInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

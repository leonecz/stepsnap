import AppKit
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

extension NSImage {
    /// CGImage нужен и для миниатюры, и для отчёта: у NSImage он ленивый.
    func stepSnapCGImage() -> CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

/// Принимает снимок ожидаемого результата извне.
///
/// Скриншот из правого нижнего угла macOS и файл из Finder приходят по-разному:
/// первый — картинкой, второй — ссылкой на файл. Поддерживаем оба варианта.
enum ExpectedResultDrop {
    @MainActor
    static func loadImage(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor (CGImage) -> Void
    ) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = url(from: item), let image = NSImage(contentsOf: url)?.stepSnapCGImage() else {
                    return
                }
                Task { @MainActor in completion(image) }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = NSImage(data: data)?.stepSnapCGImage() else { return }
                Task { @MainActor in completion(image) }
            }
            return true
        }

        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let nsImage = object as? NSImage, let image = nsImage.stepSnapCGImage() else { return }
                Task { @MainActor in completion(image) }
            }
            return true
        }

        return false
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }
}

/// Строка «ожидаемый результат» в панели записи: перетаскивание, выбор файла, замена.
struct ExpectedResultDropView: View {
    let image: CGImage?
    let onDropImage: (CGImage) -> Void
    let onChooseFile: () -> Void
    let onRemove: () -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Ожидаемый результат")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if image != nil {
                    Button("Убрать") { onRemove() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 72, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { onChooseFile() }
                    .help("Нажмите, чтобы заменить; можно перетащить новый скриншот")
            } else {
                Button(action: onChooseFile) {
                    Text("Перетащите скриншот сюда\nили выберите файл")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(.secondary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
            ExpectedResultDrop.loadImage(from: providers) { onDropImage($0) }
        }
    }
}

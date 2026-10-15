import CoreGraphics
import Foundation

/// Геометрия страницы отчёта.
public struct PageSetup: Equatable, Sendable {
    public var pageSize: CGSize
    public var margin: CGFloat
    public var captionHeight: CGFloat
    public var captionGap: CGFloat
    public var blockGap: CGFloat
    public var maxImageHeight: CGFloat

    public init(
        pageSize: CGSize,
        margin: CGFloat,
        captionHeight: CGFloat,
        captionGap: CGFloat,
        blockGap: CGFloat,
        maxImageHeight: CGFloat
    ) {
        self.pageSize = pageSize
        self.margin = margin
        self.captionHeight = captionHeight
        self.captionGap = captionGap
        self.blockGap = blockGap
        self.maxImageHeight = maxImageHeight
    }

    /// Ограничение высоты подобрано так, чтобы самый высокий снимок ещё влезал
    /// на первую страницу вместе с шапкой: иначе отчёт начинается пустой страницей.
    public static let a4 = PageSetup(
        pageSize: CGSize(width: 595, height: 842),
        margin: 48,
        captionHeight: 26,
        captionGap: 6,
        blockGap: 24,
        maxImageHeight: 580
    )
}

/// Всё, что раскладке нужно знать про шаг, не видя картинки.
public struct LayoutInput: Equatable, Sendable {
    public var index: Int
    public var caption: String
    public var imagePixelSize: PixelSize?

    public init(index: Int, caption: String, imagePixelSize: PixelSize?) {
        self.index = index
        self.caption = caption
        self.imagePixelSize = imagePixelSize
    }
}

/// Куда на какой странице попали подпись и снимок.
public struct Placement: Equatable, Sendable {
    public var pageIndex: Int
    public var captionRect: CGRect
    public var imageRect: CGRect?
}

public enum ReportLayout {
    public static func caption(index: Int, name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Шаг \(index)" : "Шаг \(index). \(trimmed)"
    }

    /// Раскладывает шаги по страницам сверху вниз, разрывая страницу так,
    /// чтобы снимок никогда не оказался разрезан.
    public static func placements(
        for inputs: [LayoutInput],
        setup: PageSetup,
        firstPageHeaderHeight: CGFloat
    ) -> [Placement] {
        let textWidth = setup.pageSize.width - 2 * setup.margin

        var pageIndex = 0
        var cursorY = setup.pageSize.height - setup.margin - firstPageHeaderHeight
        var placements: [Placement] = []

        for input in inputs {
            let imageSize = scaledImageSize(
                for: input.imagePixelSize,
                maxWidth: textWidth,
                maxHeight: setup.maxImageHeight
            )
            let imageHeight = imageSize?.height ?? 0
            let needed = setup.captionHeight
                + (imageHeight > 0 ? setup.captionGap + imageHeight : 0)
                + setup.blockGap

            if cursorY - needed < setup.margin {
                pageIndex += 1
                cursorY = setup.pageSize.height - setup.margin
            }

            let captionRect = CGRect(
                x: setup.margin,
                y: cursorY - setup.captionHeight,
                width: textWidth,
                height: setup.captionHeight
            )

            let imageRect: CGRect? = imageSize.map { size in
                CGRect(
                    x: setup.margin + (textWidth - size.width) / 2,
                    y: cursorY - setup.captionHeight - setup.captionGap - size.height,
                    width: size.width,
                    height: size.height
                )
            }

            placements.append(Placement(pageIndex: pageIndex, captionRect: captionRect, imageRect: imageRect))
            cursorY -= needed
        }

        return placements
    }

    /// Вписывает снимок в ширину блока и ограничивает по высоте, сохраняя пропорции.
    static func scaledImageSize(for pixelSize: PixelSize?, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize? {
        guard let pixelSize, pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let width = CGFloat(pixelSize.width)
        let height = CGFloat(pixelSize.height)
        let heightByWidth = maxWidth * height / width

        if heightByWidth <= maxHeight {
            return CGSize(width: maxWidth, height: heightByWidth)
        }
        return CGSize(width: maxHeight * width / height, height: maxHeight)
    }
}

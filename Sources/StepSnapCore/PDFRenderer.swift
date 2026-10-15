import CoreGraphics
import CoreText
import Foundation

/// Шаг, готовый к отрисовке в отчёте.
public struct ReportStep {
    public var index: Int
    public var name: String
    public var image: CGImage?
    public var pointNormalized: NormalizedPoint?
    public var errorText: String?

    public init(
        index: Int,
        name: String,
        image: CGImage?,
        pointNormalized: NormalizedPoint?,
        errorText: String?
    ) {
        self.index = index
        self.name = name
        self.image = image
        self.pointNormalized = pointNormalized
        self.errorText = errorText
    }
}

public enum PDFRendererError: Error, Equatable {
    case cannotCreateContext
}

public enum PDFRenderer {
    public struct Options {
        /// Рисовать кружок в точке клика поверх снимка.
        public var markClickPoint: Bool
        public var firstPageHeaderHeight: CGFloat
        public var locale: Locale

        public init() {
            markClickPoint = true
            firstPageHeaderHeight = 90
            locale = Locale(identifier: "ru_RU")
        }
    }

    public static func render(
        scenarioName: String,
        startedAt: Date,
        steps: [ReportStep],
        setup: PageSetup,
        options: Options,
        to url: URL
    ) throws {
        var mediaBox = CGRect(origin: .zero, size: setup.pageSize)
        guard
            let consumer = CGDataConsumer(url: url as CFURL),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw PDFRendererError.cannotCreateContext
        }

        let inputs = steps.map { step in
            LayoutInput(
                index: step.index,
                caption: ReportLayout.caption(index: step.index, name: step.name),
                imagePixelSize: step.image.map { PixelSize(width: $0.width, height: $0.height) }
            )
        }
        let placements = ReportLayout.placements(
            for: inputs,
            setup: setup,
            firstPageHeaderHeight: options.firstPageHeaderHeight
        )

        let pageCount = (placements.map(\.pageIndex).max() ?? 0) + 1

        for pageIndex in 0..<pageCount {
            context.beginPDFPage(nil)

            if pageIndex == 0 {
                drawHeader(
                    scenarioName: scenarioName,
                    startedAt: startedAt,
                    stepCount: steps.count,
                    setup: setup,
                    options: options,
                    context: context
                )
            }

            for (step, placement) in zip(steps, placements) where placement.pageIndex == pageIndex {
                drawCaption(placement.captionRect, text: ReportLayout.caption(index: step.index, name: step.name), context: context)

                if let image = step.image, let imageRect = placement.imageRect {
                    context.draw(image, in: imageRect)
                    if options.markClickPoint, let normalized = step.pointNormalized {
                        drawClickMarker(normalized: normalized, in: imageRect, context: context)
                    }
                } else {
                    drawError(step.errorText ?? "Снимок отсутствует", below: placement.captionRect, context: context)
                }
            }

            context.endPDFPage()
        }

        context.closePDF()
    }

    // MARK: - Отрисовка

    private static func drawHeader(
        scenarioName: String,
        startedAt: Date,
        stepCount: Int,
        setup: PageSetup,
        options: Options,
        context: CGContext
    ) {
        let left = setup.margin
        let top = setup.pageSize.height - setup.margin

        draw(
            scenarioName,
            font: font(size: 18, emphasized: true),
            color: black,
            at: CGPoint(x: left, y: top - 20),
            context: context
        )

        let formatter = DateFormatter()
        formatter.locale = options.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        draw(
            formatter.string(from: startedAt),
            font: font(size: 12),
            color: grey,
            at: CGPoint(x: left, y: top - 46),
            context: context
        )
        draw(
            "Шагов: \(stepCount)",
            font: font(size: 12),
            color: grey,
            at: CGPoint(x: left, y: top - 66),
            context: context
        )
    }

    private static func drawCaption(_ rect: CGRect, text: String, context: CGContext) {
        draw(text, font: font(size: 13, emphasized: true), color: black, at: CGPoint(x: rect.minX, y: rect.minY + 6), context: context)
    }

    private static func drawError(_ text: String, below captionRect: CGRect, context: CGContext) {
        draw(
            text,
            font: font(size: 11),
            color: grey,
            at: CGPoint(x: captionRect.minX, y: captionRect.minY - 16),
            context: context
        )
    }

    /// Кружок в точке клика: сначала белая подложка, поверх красная обводка,
    /// чтобы отметку было видно и на светлом, и на тёмном фоне.
    private static func drawClickMarker(normalized: NormalizedPoint, in imageRect: CGRect, context: CGContext) {
        let radius = 0.03 * imageRect.width
        let center = CGPoint(
            x: imageRect.minX + CGFloat(normalized.x) * imageRect.width,
            y: imageRect.maxY - CGFloat(normalized.y) * imageRect.height
        )
        let markerRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.setLineWidth(6)
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        context.strokeEllipse(in: markerRect)

        context.setLineWidth(3)
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.strokeEllipse(in: markerRect)
    }

    private static func draw(
        _ text: String,
        font: CTFont,
        color: CGColor,
        at point: CGPoint,
        context: CGContext
    ) {
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
        ]
        guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else {
            return
        }

        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private static func font(size: CGFloat, emphasized: Bool = false) -> CTFont {
        let type: CTFontUIFontType = emphasized ? .emphasizedSystem : .system
        if let system = CTFontCreateUIFontForLanguage(type, size, "ru" as CFString) {
            return system
        }
        return CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    private static let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    private static let grey = CGColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
}

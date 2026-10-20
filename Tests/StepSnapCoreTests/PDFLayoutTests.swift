import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct PDFLayoutTests {
    private let headerHeight: CGFloat = 90

    private func input(
        index: Int,
        name: String = "",
        width: Int? = nil,
        height: Int? = nil,
        expectedWidth: Int? = nil,
        expectedHeight: Int? = nil
    ) -> LayoutInput {
        let size = (width != nil && height != nil) ? PixelSize(width: width!, height: height!) : nil
        let expectedSize = (expectedWidth != nil && expectedHeight != nil)
            ? PixelSize(width: expectedWidth!, height: expectedHeight!)
            : nil
        return LayoutInput(
            index: index,
            caption: ReportLayout.caption(index: index, name: name),
            imagePixelSize: size,
            expectedResultPixelSize: expectedSize
        )
    }

    @Test func captionsIncludeNameWhenPresent() {
        #expect(ReportLayout.caption(index: 3, name: "Открыть меню") == "Шаг 3. Открыть меню")
        #expect(ReportLayout.caption(index: 3, name: "") == "Шаг 3")
        #expect(ReportLayout.caption(index: 3, name: "   ") == "Шаг 3")
    }

    @Test func placesSingleStepOnFirstPage() {
        let placements = ReportLayout.placements(
            for: [input(index: 1, name: "Вход", width: 400, height: 200)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements.count == 1)
        #expect(placements[0].pageIndex == 0)
        #expect(placements[0].captionRect == CGRect(x: 48, y: 678, width: 499, height: 26))
        #expect(placements[0].imageRect == CGRect(x: 48, y: 422.5, width: 499, height: 249.5))
    }

    @Test func capsTallImageAndCentersIt() {
        let placements = ReportLayout.placements(
            for: [input(index: 1, width: 400, height: 4000)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements[0].imageRect?.height == 580)
        #expect(placements[0].imageRect?.width == 58)
        #expect(placements[0].imageRect?.minX == 268.5)
    }

    @Test func startsNewPageWhenImageDoesNotFit() {
        let placements = ReportLayout.placements(
            for: [input(index: 1, width: 400, height: 480), input(index: 2, width: 400, height: 480)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements[0].pageIndex == 0)
        #expect(placements[1].pageIndex == 1)
    }

    @Test func stepWithoutImageNeedsNoImageSpace() {
        let placements = ReportLayout.placements(
            for: [input(index: 1), input(index: 2)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements.map(\.pageIndex) == [0, 0])
        #expect(placements[0].imageRect == nil)
        #expect(placements[1].imageRect == nil)
    }

    @Test func emptyReportProducesNoPlacements() {
        #expect(ReportLayout.placements(for: [], setup: .a4, firstPageHeaderHeight: headerHeight).isEmpty)
    }

    @Test func expectedResultSitsBesideStepImage() {
        let placements = ReportLayout.placements(
            for: [input(index: 1, width: 400, height: 300, expectedWidth: 400, expectedHeight: 300)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        let placement = placements[0]
        let imageRect = try! #require(placement.imageRect)
        let expectedRect = try! #require(placement.expectedResultRect)

        // Две равные колонки, без наложений, обе внутри полей страницы.
        #expect(imageRect.width == expectedRect.width)
        #expect(imageRect.maxX <= expectedRect.minX)
        #expect(expectedRect.maxX <= 595 - 48)
        #expect(imageRect.minX == 48)

        // Верх картинок выровнен.
        #expect(imageRect.maxY == expectedRect.maxY)

        // Подписи стоят над своими картинками.
        let actualLabel = try! #require(placement.imageLabelRect)
        let expectedLabel = try! #require(placement.expectedResultLabelRect)
        #expect(actualLabel.minY >= imageRect.maxY)
        #expect(expectedLabel.minY >= expectedRect.maxY)
        #expect(actualLabel.minX == imageRect.minX)
        #expect(expectedLabel.minX == expectedRect.minX)
    }

    @Test func stepWithoutExpectedResultKeepsFullWidthImage() {
        let placements = ReportLayout.placements(
            for: [input(index: 1, width: 400, height: 300)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements[0].imageRect?.width == 499)
        #expect(placements[0].expectedResultRect == nil)
        #expect(placements[0].imageLabelRect == nil)
        #expect(placements[0].expectedResultLabelRect == nil)
    }

    @Test func expectedResultPairStaysOnOnePage() {
        let placements = ReportLayout.placements(
            for: [
                input(index: 1, width: 400, height: 800, expectedWidth: 400, expectedHeight: 800),
                input(index: 2, width: 400, height: 800, expectedWidth: 400, expectedHeight: 800),
            ],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements[0].pageIndex == 0)
        #expect(placements[1].pageIndex == 1)
    }

    @Test func tallestStepStillFitsUnderHeaderOnFirstPage() {
        // Самый высокий возможный снимок должен попадать на первую страницу вместе с шапкой:
        // иначе каждый отчёт начинается почти пустой страницей.
        let placements = ReportLayout.placements(
            for: [input(index: 1, width: 400, height: 4000)],
            setup: .a4,
            firstPageHeaderHeight: headerHeight
        )

        #expect(placements[0].pageIndex == 0)
    }
}

import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct PDFRendererTests {
    private let startedAt = Date(timeIntervalSince1970: 1_763_000_000)

    private func makeTempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func step(index: Int, name: String = "", width: Int = 400, height: Int = 200, failed: Bool = false) -> ReportStep {
        ReportStep(
            index: index,
            name: name,
            image: failed ? nil : ImageFixture.makeImage(width: width, height: height),
            pointNormalized: failed ? nil : NormalizedPoint(x: 0.5, y: 0.5),
            errorText: failed ? "Снимок не получился" : nil
        )
    }

    @Test func writesPdfWithExpectedPageCount() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent(StepFileNames.reportFileName)

        let steps = [
            step(index: 1, name: "Открыть меню"),
            step(index: 2, name: "Войти"),
            step(index: 3),
        ]
        try PDFRenderer.render(
            scenarioName: "Проверка входа",
            startedAt: startedAt,
            steps: steps,
            setup: .a4,
            options: PDFRenderer.Options(),
            to: url
        )

        let document = CGPDFDocument(url as CFURL)
        // Два снимка по 249.5 pt влезают на первую страницу, третий уходит на вторую.
        #expect(document?.numberOfPages == 2)
    }

    @Test func writesPdfForStepsThatFailedCapture() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent(StepFileNames.reportFileName)

        let steps = [step(index: 1, name: "Работает"), step(index: 2, failed: true)]
        try PDFRenderer.render(
            scenarioName: "Проверка входа",
            startedAt: startedAt,
            steps: steps,
            setup: .a4,
            options: PDFRenderer.Options(),
            to: url
        )

        let document = CGPDFDocument(url as CFURL)
        #expect(document?.numberOfPages == 1)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func writesHeaderOnlyPdfWhenThereAreNoSteps() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent(StepFileNames.reportFileName)

        try PDFRenderer.render(
            scenarioName: "Пустой сценарий",
            startedAt: startedAt,
            steps: [],
            setup: .a4,
            options: PDFRenderer.Options(),
            to: url
        )

        let document = CGPDFDocument(url as CFURL)
        #expect(document?.numberOfPages == 1)

        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 1024)
    }

    @Test func markingClickPointIsOptional() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        var options = PDFRenderer.Options()
        options.markClickPoint = false

        let withMark = folder.appendingPathComponent("with.pdf")
        let withoutMark = folder.appendingPathComponent("without.pdf")

        try PDFRenderer.render(scenarioName: "Сценарий", startedAt: startedAt, steps: [step(index: 1)], setup: .a4, options: PDFRenderer.Options(), to: withMark)
        try PDFRenderer.render(scenarioName: "Сценарий", startedAt: startedAt, steps: [step(index: 1)], setup: .a4, options: options, to: withoutMark)

        // Обе версии — валидные PDF с одинаковым числом страниц, отличаются только кружком:
        // без сравнения содержимого тест прошёл бы, даже если бы тумблер ничего не делал.
        #expect(CGPDFDocument(withMark as CFURL)?.numberOfPages == 1)
        #expect(CGPDFDocument(withoutMark as CFURL)?.numberOfPages == 1)
        #expect(try Data(contentsOf: withMark) != (try Data(contentsOf: withoutMark)))
    }
}

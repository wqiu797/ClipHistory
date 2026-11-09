import AppKit
import XCTest

@testable import ClipHistory

final class ImageStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipHistory-ImageStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
        try super.tearDownWithError()
    }

    func testEncodeWriteAndLoadPNGRoundTrip() throws {
        let store = ImageStore(directory: directory)
        let imageData = try makePNGData()

        let first = try XCTUnwrap(store.encode(imageData))
        let second = try XCTUnwrap(store.encode(imageData))
        XCTAssertFalse(first.contentHash.isEmpty)
        XCTAssertEqual(first.contentHash, second.contentHash)
        XCTAssertEqual(first.pngData, second.pngData)
        XCTAssertFalse(first.thumbnailPNGData.isEmpty)

        let names = try XCTUnwrap(store.write(first))
        XCTAssertEqual(
            try XCTUnwrap(store.loadPNGData(fileName: names.imageName)),
            first.pngData
        )
        XCTAssertNotNil(store.loadThumbnail(fileName: names.thumbnailName))

        let imagePath = directory.appendingPathComponent(names.imageName).path
        let attributes = try FileManager.default.attributesOfItem(atPath: imagePath)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)

        store.deleteImages(imageName: names.imageName, thumbName: names.thumbnailName)
        XCTAssertNil(store.loadPNGData(fileName: names.imageName))
    }

    private func makePNGData() throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 8,
            pixelsHigh: 8,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}

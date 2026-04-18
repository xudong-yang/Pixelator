//
//  CoordinateMapperTests.swift
//  PixelatorTests
//
//  Created by Xudong Yang on 2026/4/18.
//

import Testing
import CoreGraphics
@testable import Pixelator

// MARK: - Helpers

private let accuracy: CGFloat = 0.001

private func assertPoint(
    _ result: CGPoint,
    x expectedX: CGFloat,
    y expectedY: CGFloat,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    #expect(abs(result.x - expectedX) < accuracy, sourceLocation: sourceLocation)
    #expect(abs(result.y - expectedY) < accuracy, sourceLocation: sourceLocation)
}

// MARK: - Tests

struct CoordinateMapperTests {

    // -------------------------------------------------------------------------
    // 1. Square image in square canvas — no letterboxing, no pillarboxing.
    //    scale = 1.0, offset = (0, 0).
    //    viewPoint should map 1-to-1 to image coordinates.
    // -------------------------------------------------------------------------
    @Test func squareImageInSquareCanvas_centre() {
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 50),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        assertPoint(result, x: 50, y: 50)
    }

    @Test func squareImageInSquareCanvas_origin() {
        let result = viewToImageCoordinates(
            viewPoint: .zero,
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        assertPoint(result, x: 0, y: 0)
    }

    @Test func squareImageInSquareCanvas_corner() {
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 100, y: 100),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        assertPoint(result, x: 100, y: 100)
    }

    // -------------------------------------------------------------------------
    // 2. Landscape image (200×100) in square canvas (100×100).
    //    scale = min(100/200, 100/100) = 0.5
    //    scaledSize = 100×50
    //    offsetX = 0, offsetY = (100-50)/2 = 25   ← letterbox top/bottom
    // -------------------------------------------------------------------------
    @Test func landscapeImage_centreOfImage() {
        // View centre of the image area is (50, 25+25) = (50, 50).
        // That should map to image centre (100, 50).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 50),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        assertPoint(result, x: 100, y: 50)
    }

    @Test func landscapeImage_topLeftOfImageArea() {
        // Image area starts at view (0, 25).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 0, y: 25),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        assertPoint(result, x: 0, y: 0)
    }

    @Test func landscapeImage_bottomRightOfImageArea() {
        // Image area ends at view (100, 75).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 100, y: 75),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        assertPoint(result, x: 200, y: 100)
    }

    // -------------------------------------------------------------------------
    // 3. Portrait image (100×200) in square canvas (100×100).
    //    scale = min(100/100, 100/200) = 0.5
    //    scaledSize = 50×100
    //    offsetX = (100-50)/2 = 25, offsetY = 0   ← pillarbox left/right
    // -------------------------------------------------------------------------
    @Test func portraitImage_centreOfImage() {
        // Image area centre in view: (25+25, 50) = (50, 50) → image (50, 100).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 50),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 200)
        )
        assertPoint(result, x: 50, y: 100)
    }

    @Test func portraitImage_topLeftOfImageArea() {
        // Image area starts at view (25, 0).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 25, y: 0),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 200)
        )
        assertPoint(result, x: 0, y: 0)
    }

    // -------------------------------------------------------------------------
    // 4. Point exactly at image boundary — must not crash, must clamp.
    // -------------------------------------------------------------------------
    @Test func pointAtExactImageBoundary_doesNotCrash() {
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 100, y: 100),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        // Should be exactly (100, 100), clamped.
        assertPoint(result, x: 100, y: 100)
    }

    // -------------------------------------------------------------------------
    // 5. Point in the letterbox area → clamps to nearest image edge.
    //    Landscape image: letterbox is y ∈ [0, 25) and y ∈ (75, 100].
    // -------------------------------------------------------------------------
    @Test func pointInTopLetterbox_clampsToTopEdge() {
        // y = 10 is above the image area (which starts at y = 25).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 10),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        // imageY = (10 - 25) / 0.5 = -30 → clamped to 0
        assertPoint(result, x: 100, y: 0)
    }

    @Test func pointInBottomLetterbox_clampsToBottomEdge() {
        // y = 90 is below the image area (which ends at y = 75).
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 90),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        // imageY = (90 - 25) / 0.5 = 130 → clamped to 100
        assertPoint(result, x: 100, y: 100)
    }

    @Test func pointInLeftPillarbox_clampsToLeftEdge() {
        // Portrait image, pillarbox left. x = 5 is in the left pillarbox.
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 5, y: 50),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 200)
        )
        // imageX = (5 - 25) / 0.5 = -40 → clamped to 0
        assertPoint(result, x: 0, y: 100)
    }

    // -------------------------------------------------------------------------
    // 6. Zero-size guards — must not crash, must return .zero.
    // -------------------------------------------------------------------------
    @Test func zeroViewSize_returnsZero() {
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 50),
            viewSize:  .zero,
            imageSize: CGSize(width: 100, height: 100)
        )
        assertPoint(result, x: 0, y: 0)
    }

    @Test func zeroImageSize_returnsZero() {
        let result = viewToImageCoordinates(
            viewPoint: CGPoint(x: 50, y: 50),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: .zero
        )
        assertPoint(result, x: 0, y: 0)
    }

    // -------------------------------------------------------------------------
    // 7. viewToImageRect — canonical rect with both corners mapped correctly.
    // -------------------------------------------------------------------------
    @Test func viewToImageRect_landscapeImage() {
        // Landscape 200×100 in 100×100 view: scale=0.5, offsetY=25.
        // Drag from view (0,25) to view (100,75) → full image rect.
        let rect = viewToImageRect(
            viewRect: CGRect(x: 0, y: 25, width: 100, height: 50),
            viewSize:  CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        #expect(abs(rect.origin.x)      < accuracy)
        #expect(abs(rect.origin.y)      < accuracy)
        #expect(abs(rect.width  - 200)  < accuracy)
        #expect(abs(rect.height - 100)  < accuracy)
    }
}

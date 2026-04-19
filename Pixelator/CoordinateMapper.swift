//
//  CoordinateMapper.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import CoreGraphics

// MARK: - Coordinate mapping

/// Converts a point in SwiftUI Canvas (view) space to image pixel space.
///
/// The image is aspect-ratio scaled to fit inside `viewSize`, then centred.
/// This function computes the uniform scale factor, the pillarbox/letterbox
/// offsets, and maps the view point back to image coordinates, clamping the
/// result to image bounds.
///
/// - Parameters:
///   - viewPoint: A point in the canvas's local coordinate space (origin top-left).
///   - viewSize:  The size of the canvas view.
///   - imageSize: The size of the source image in pixels.
/// - Returns: The corresponding pixel coordinate, clamped to [0, imageSize].
func viewToImageCoordinates(
    viewPoint: CGPoint,
    viewSize: CGSize,
    imageSize: CGSize
) -> CGPoint {
    guard viewSize.width > 0, viewSize.height > 0,
          imageSize.width > 0, imageSize.height > 0 else {
        return .zero
    }

    // Uniform scale factor so the image fits entirely within the view.
    let scale = min(viewSize.width / imageSize.width,
                    viewSize.height / imageSize.height)

    // Size the image occupies inside the view after scaling.
    let scaledWidth  = imageSize.width  * scale
    let scaledHeight = imageSize.height * scale

    // Top-left origin of the scaled image within the view (centred).
    let offsetX = (viewSize.width  - scaledWidth)  / 2.0
    let offsetY = (viewSize.height - scaledHeight) / 2.0

    // Shift the view point so (0,0) aligns with the image origin.
    let localX = viewPoint.x - offsetX
    let localY = viewPoint.y - offsetY

    // Divide by scale to get image-pixel coordinates.
    let imageX = localX / scale
    let imageY = localY / scale

    // Clamp to valid image bounds.
    let clampedX = min(max(imageX, 0), imageSize.width)
    let clampedY = min(max(imageY, 0), imageSize.height)

    return CGPoint(x: clampedX, y: clampedY)
}

/// Converts a rect in view space to a rect in image space.
///
/// Both corners are mapped independently and a new `CGRect` is formed,
/// so the returned rect is always canonical (positive width and height).
func viewToImageRect(
    viewRect: CGRect,
    viewSize: CGSize,
    imageSize: CGSize
) -> CGRect {
    let origin = viewToImageCoordinates(
        viewPoint: viewRect.origin,
        viewSize: viewSize,
        imageSize: imageSize
    )
    let corner = viewToImageCoordinates(
        viewPoint: CGPoint(x: viewRect.maxX, y: viewRect.maxY),
        viewSize: viewSize,
        imageSize: imageSize
    )
    return CGRect(
        x: origin.x,
        y: origin.y,
        width: corner.x - origin.x,
        height: corner.y - origin.y
    )
}

// MARK: - Zoom/Pan-aware coordinate mapping

func viewToImageCoordinates(
    viewPoint: CGPoint,
    viewSize: CGSize,
    imageSize: CGSize,
    zoomScale: CGFloat,
    panOffset: CGSize
) -> CGPoint {
    guard viewSize.width > 0, viewSize.height > 0,
          imageSize.width > 0, imageSize.height > 0,
          zoomScale > 0 else {
        return .zero
    }

    let unpanX = viewPoint.x - panOffset.width
    let unpanY = viewPoint.y - panOffset.height

    let unzoomedX = unpanX / zoomScale
    let unzoomedY = unpanY / zoomScale

    return viewToImageCoordinates(
        viewPoint: CGPoint(x: unzoomedX, y: unzoomedY),
        viewSize: viewSize,
        imageSize: imageSize
    )
}

func viewToImageRect(
    viewRect: CGRect,
    viewSize: CGSize,
    imageSize: CGSize,
    zoomScale: CGFloat,
    panOffset: CGSize
) -> CGRect {
    let origin = viewToImageCoordinates(
        viewPoint: viewRect.origin,
        viewSize: viewSize,
        imageSize: imageSize,
        zoomScale: zoomScale,
        panOffset: panOffset
    )
    let corner = viewToImageCoordinates(
        viewPoint: CGPoint(x: viewRect.maxX, y: viewRect.maxY),
        viewSize: viewSize,
        imageSize: imageSize,
        zoomScale: zoomScale,
        panOffset: panOffset
    )
    return CGRect(
        x: origin.x,
        y: origin.y,
        width: corner.x - origin.x,
        height: corner.y - origin.y
    )
}

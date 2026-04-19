//
//  ContentView.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import SwiftUI
import CoreGraphics

struct ContentView: View {
    @ObservedObject var document: PixelatorDocument
    @Environment(\.undoManager) private var undoManager

    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    @State private var pixelSize: Double = 20

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var scrollPosition: CGPoint = .zero

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 20.0

    private var liveViewRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size
            let imageSize = CGSize(
                width: document.sourceImage.width,
                height: document.sourceImage.height
            )
            let baseRect = fittingRect(imageSize: imageSize, in: viewSize)
            let zoomedContentSize = CGSize(
                width: baseRect.width * zoomScale,
                height: baseRect.height * zoomScale
            )
            let _ = document.regions

            ZStack {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Color.clear
                        .frame(width: zoomedContentSize.width, height: zoomedContentSize.height)
                }
                .onScrollGeometryChange(for: CGPoint.self) { geometry in
                    geometry.contentOffset
                } action: { oldOffset, newOffset in
                    guard zoomScale > 1.0 else { return }
                    let delta = CGSize(
                        width: newOffset.x - scrollPosition.x,
                        height: newOffset.y - scrollPosition.y
                    )
                    scrollPosition = newOffset

                    if delta.width != 0 || delta.height != 0 {
                        panOffset = CGSize(
                            width: panOffset.width - delta.width,
                            height: panOffset.height - delta.height
                        )
                        panOffset = clampPanOffset(panOffset, viewSize: viewSize, imageSize: imageSize)
                    }
                }

                Canvas { ctx, size in
                    drawImage(ctx: ctx, size: size, viewSize: viewSize)
                    drawOverlay(ctx: ctx, size: size)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        dragCurrent = value.location
                    }
                    .onEnded { _ in
                        commitDrag(viewSize: viewSize, imageSize: imageSize)
                        dragStart = nil
                        dragCurrent = nil
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / max(lastMagnification, 0.001)
                        lastMagnification = value

                        let baseRectInner = fittingRect(imageSize: imageSize, in: viewSize)
                        let pinchCentre = CGPoint(
                            x: baseRectInner.midX + panOffset.width,
                            y: baseRectInner.midY + panOffset.height
                        )

                        let newScale = min(max(zoomScale * delta, minZoom), maxZoom)
                        let scaleRatio = newScale / zoomScale

                        let adjustedPanX = pinchCentre.x - scaleRatio * (pinchCentre.x - panOffset.width)
                        let adjustedPanY = pinchCentre.y - scaleRatio * (pinchCentre.y - panOffset.height)

                        zoomScale = newScale
                        panOffset = CGSize(width: adjustedPanX, height: adjustedPanY)
                    }
                    .onEnded { _ in
                        lastMagnification = 1.0
                    }
            )
            .onChange(of: zoomScale) { _, _ in
                panOffset = clampPanOffset(panOffset, viewSize: viewSize, imageSize: imageSize)
            }
            .onChange(of: zoomScale) { oldValue, newValue in
                if newValue == 1.0 {
                    scrollPosition = .zero
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack {
                    Text("Pixel Size: \(Int(pixelSize))")
                        .font(.caption)
                        .padding(.leading)
                    Slider(value: $pixelSize, in: 1...50)
                        .frame(width: 150.0)
                        .accessibilityLabel("Pixel Size")
                }
            }
            ToolbarItemGroup {
                Button("Fit") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        zoomScale = 1.0
                        panOffset = .zero
                        scrollPosition = .zero
                    }
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Undo") {
                    undoManager?.undo()
                }
                .disabled(!(undoManager?.canUndo ?? false))
                .keyboardShortcut("z", modifiers: .command)
            }
        }
    }

    private func drawImage(ctx: GraphicsContext, size: CGSize, viewSize: CGSize) {
        let image = document.renderedImage
        let imageSize = CGSize(width: document.sourceImage.width, height: document.sourceImage.height)
        let baseRect = fittingRect(imageSize: imageSize, in: viewSize)

        let transformedRect = CGRect(
            x: baseRect.origin.x * zoomScale + panOffset.width,
            y: baseRect.origin.y * zoomScale + panOffset.height,
            width: baseRect.width * zoomScale,
            height: baseRect.height * zoomScale
        )

        let resolved = ctx.resolve(
            Image(decorative: image, scale: 1, orientation: .up)
        )
        ctx.draw(resolved, in: transformedRect)
    }

    private func drawOverlay(ctx: GraphicsContext, size: CGSize) {
        guard let rect = liveViewRect, rect.width > 0, rect.height > 0 else { return }

        ctx.fill(
            Path(rect),
            with: .color(.accentColor.opacity(0.15))
        )

        ctx.stroke(
            Path(rect),
            with: .color(.accentColor),
            lineWidth: 1
        )
    }

    private func commitDrag(viewSize: CGSize, imageSize: CGSize) {
        guard let rect = liveViewRect,
              rect.width > 1, rect.height > 1 else { return }

        let imageRect = viewToImageRect(
            viewRect: rect,
            viewSize: viewSize,
            imageSize: imageSize,
            zoomScale: zoomScale,
            panOffset: panOffset
        )

        let region = PixelatedRegion(rect: imageRect, pixelSize: CGFloat(pixelSize))
        document.addRegion(region, undoManager: undoManager)
    }

    private func clampPanOffset(_ offset: CGSize, viewSize: CGSize, imageSize: CGSize) -> CGSize {
        let baseRect = fittingRect(imageSize: imageSize, in: viewSize)
        let scaledWidth = baseRect.width * zoomScale
        let scaledHeight = baseRect.height * zoomScale

        let minOverlap = min(100.0, min(scaledWidth, scaledHeight) / 2)

        let maxOffsetX = max(0, (scaledWidth - minOverlap) - (viewSize.width - minOverlap))
        let maxOffsetY = max(0, (scaledHeight - minOverlap) - (viewSize.height - minOverlap))

        let clampedX = min(max(offset.width, -maxOffsetX), maxOffsetX)
        let clampedY = min(max(offset.height, -maxOffsetY), maxOffsetY)

        return CGSize(width: clampedX, height: clampedY)
    }
}

func fittingRect(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0,
          viewSize.width > 0, viewSize.height > 0 else {
        return CGRect(origin: .zero, size: viewSize)
    }
    let scale = min(viewSize.width / imageSize.width,
                    viewSize.height / imageSize.height)
    let w = imageSize.width * scale
    let h = imageSize.height * scale
    let x = (viewSize.width - w) / 2
    let y = (viewSize.height - h) / 2
    return CGRect(x: x, y: y, width: w, height: h)
}

private func makePreviewDocument() -> PixelatorDocument {
    let size = 1
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let image = context.makeImage() else {
        fatalError("Failed to create preview image")
    }

    return PixelatorDocument(image: image)
}

#Preview {
    ContentView(document: makePreviewDocument())
        .frame(width: 800, height: 600)
}
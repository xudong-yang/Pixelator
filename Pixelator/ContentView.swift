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

    // Drag state — both points are in Canvas local (view) space.
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil

    @State private var pixelSize: Double = 20

    // The live rubber-band rect in view space, or nil when no drag is active.
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
                width:  document.sourceImage.width,
                height: document.sourceImage.height
            )
            let _ = document.regions // Track for canvas invalidation

            Canvas { ctx, size in
                drawImage(ctx: ctx, size: size)
                drawOverlay(ctx: ctx, size: size)
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        dragCurrent = value.location
                    }
                    .onEnded { value in
                        commitDrag(viewSize: viewSize, imageSize: imageSize)
                        dragStart   = nil
                        dragCurrent = nil
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Button("Undo") {
                    undoManager?.undo()
                }
                .disabled(!(undoManager?.canUndo ?? false))
                .keyboardShortcut("z", modifiers: .command)
            }
        }
    }

    // MARK: - Drawing

    private func drawImage(ctx: GraphicsContext, size: CGSize) {
        let image = document.renderedImage
        let imageSize = CGSize(width: document.sourceImage.width, height: document.sourceImage.height)
        let destRect  = fittingRect(imageSize: imageSize, in: size)

        let resolved = ctx.resolve(
            Image(decorative: image, scale: 1, orientation: .up)
        )
        ctx.draw(resolved, in: destRect)
    }

    private func drawOverlay(ctx: GraphicsContext, size: CGSize) {
        guard let rect = liveViewRect, rect.width > 0, rect.height > 0 else { return }

        // Semi-transparent fill.
        ctx.fill(
            Path(rect),
            with: .color(.accentColor.opacity(0.15))
        )

        // 1 pt stroke.
        ctx.stroke(
            Path(rect),
            with: .color(.accentColor),
            lineWidth: 1
        )
    }

    // MARK: - Gesture → Document

    private func commitDrag(viewSize: CGSize, imageSize: CGSize) {
        guard let rect = liveViewRect,
              rect.width > 1, rect.height > 1 else { return }

        let imageRect = viewToImageRect(
            viewRect:  rect,
            viewSize:  viewSize,
            imageSize: imageSize
        )

        let region = PixelatedRegion(rect: imageRect, pixelSize: CGFloat(pixelSize))
        document.addRegion(region, undoManager: undoManager)
    }
}

// MARK: - Layout helper

/// Returns the CGRect that centres `imageSize` aspect-ratio-fitted inside `viewSize`.
/// This is the canonical source of truth for image placement; the Canvas draw call
/// and the gesture handler must both use this function.
func fittingRect(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0,
          viewSize.width  > 0, viewSize.height  > 0 else {
        return CGRect(origin: .zero, size: viewSize)
    }
    let scale = min(viewSize.width  / imageSize.width,
                    viewSize.height / imageSize.height)
    let w = imageSize.width  * scale
    let h = imageSize.height * scale
    let x = (viewSize.width  - w) / 2
    let y = (viewSize.height - h) / 2
    return CGRect(x: x, y: y, width: w, height: h)
}

// MARK: - Preview

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

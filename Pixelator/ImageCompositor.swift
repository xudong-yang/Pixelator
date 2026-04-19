//
//  ImageCompositor.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageCompositor {
    private let ciContext: CIContext

    init() {
        self.ciContext = CIContext()
    }

    func flatten(sourceImage: CGImage, regions: [PixelatedRegion]) -> CGImage? {
        guard !regions.isEmpty else { return sourceImage }

        let width = sourceImage.width
        let height = sourceImage.height
        let colorSpace = sourceImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(sourceImage, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))

        for region in regions {
            guard let pixelated = applyPixellate(to: sourceImage, region: region) else { continue }
            ctx.draw(pixelated, in: region.rect)
        }

        return ctx.makeImage()
    }

    private func applyPixellate(to image: CGImage, region: PixelatedRegion) -> CGImage? {
        let full = CIImage(cgImage: image)

        let filter = CIFilter.pixellate()
        filter.inputImage = full.cropped(to: region.rect)
        filter.scale = Float(region.pixelSize)
        filter.center = CGPoint(
            x: region.rect.midX,
            y: region.rect.midY
        )

        guard let output = filter.outputImage else { return nil }
        return ciContext.createCGImage(output, from: region.rect)
    }
}

//
//  PixelatorDocument.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

final class PixelatorDocument: ObservableObject, ReferenceFileDocument {
    typealias Snapshot = CGImage
    
    @Published var regions: [PixelatedRegion] = []
    private(set) var sourceImage: CGImage
    
    static var readableContentTypes: [UTType] {
        [.png, .jpeg, .tiff, .bmp, .gif]
    }
    
    static var writableContentTypes: [UTType] { [.png] }
    
    /// New-document init (unused for now but required by the protocol)
    required init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let image = Self.cgImage(from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.sourceImage = image
    }
    
    init(image: CGImage) {
        self.sourceImage = image
    }
    
    func snapshot(contentType: UTType) throws -> Snapshot {
        guard let flattenedImage = flatten() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return flattenedImage
    }
    
    func fileWrapper(
        snapshot: Snapshot,
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        let data = try writeImage(snapshot, as: configuration.contentType)
        return FileWrapper(regularFileWithContents: data)
    }
    
    func addRegion(_ region: PixelatedRegion, undoManager: UndoManager?) {
        regions.append(region)
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.removeLastRegion(undoManager: undoManager)
        }
    }
    
    private func removeLastRegion(undoManager: UndoManager?) {
        guard !regions.isEmpty else { return }
        let removed = regions.removeLast()
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.addRegion(removed, undoManager: undoManager)
        }
    }
    
    func flatten() -> CGImage? {
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
        
        let ciContext = CIContext()
        for region in regions {
            guard let pixelated = applyPixellate(to: sourceImage, region: region, ciContext: ciContext) else { continue }
            ctx.draw(pixelated, in: region.rect)
        }
        
        return ctx.makeImage()
    }
    
    private func applyPixellate(
        to image: CGImage,
        region: PixelatedRegion,
        ciContext: CIContext
    ) -> CGImage? {
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
    
    private func writeImage(_ image: CGImage, as type: UTType) throws -> Data {
        switch type {
        case .png:
            return try pngData(from: image)
        default:
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
    }
    
    private func pngData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }
    
    private static func cgImage(from data: Data) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return image
    }
}

//
//  ImagePersistence.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import ImageIO

struct ImagePersistence {
    static func writeImage(_ image: CGImage, as type: UTType) throws -> Data {
        switch type {
        case .png:
            return try pngData(from: image)
        default:
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
    }

    static func cgImage(from data: Data) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return image
    }

    private static func pngData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }
}
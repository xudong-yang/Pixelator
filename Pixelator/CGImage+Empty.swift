//
//  CGImage+Empty.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import Foundation
import CoreGraphics

extension CGImage {
    /// 1×1 transparent pixel — placeholder for the new-document path.
    static var empty: CGImage {
        let ctx = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }
}

//
//  PixelatorDocument.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics
import Combine

final class PixelatorDocument: ObservableObject, ReferenceFileDocument {
    typealias Snapshot = CGImage

    @Published var regions: [PixelatedRegion] = []
    private(set) var sourceImage: CGImage
    private let compositor: ImageCompositor

    static var readableContentTypes: [UTType] {
        [.png, .jpeg, .tiff, .bmp, .gif]
    }

    static var writableContentTypes: [UTType] { [.png] }

    required init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let image = ImagePersistence.cgImage(from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.sourceImage = image
        self.compositor = ImageCompositor()
    }

    init(image: CGImage) {
        self.sourceImage = image
        self.compositor = ImageCompositor()
    }

    func snapshot(contentType: UTType) throws -> Snapshot {
        guard let flattenedImage = compositor.flatten(sourceImage: sourceImage, regions: regions) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return flattenedImage
    }

    func fileWrapper(
        snapshot: Snapshot,
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        let data = try ImagePersistence.writeImage(snapshot, as: configuration.contentType)
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
}

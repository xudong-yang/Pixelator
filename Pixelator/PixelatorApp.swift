//
//  PixelatorApp.swift
//  Pixelator
//
//  Created by Xudong Yang on 2026/4/18.
//

import SwiftUI

@main
struct PixelatorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { PixelatorDocument.preview() }) { file in
            ContentView(document: file.document)
        }
    }
}

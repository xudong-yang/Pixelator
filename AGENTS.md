# AGENTS.md — Pixelator

## What This App Does (Read First)

Pixelator is a single-purpose macOS image editor. The user opens an image, drags to select regions, those regions get pixelated immediately, and they save the result. That's the entire product. Every code decision should be evaluated against this narrow scope.

## Architecture in One Paragraph

`DocumentGroup` owns file lifecycle. `PixelatorDocument` (a `ReferenceFileDocument`) holds `sourceImage: CGImage` (never mutated) and `regions: [PixelatedRegion]` (append-only, undo pops last). A SwiftUI `Canvas` renders the composited image and the live drag overlay. A `DragGesture` on that canvas produces rects in view space; a `viewToImageCoordinates()` helper converts them to image space before a `PixelatedRegion` is created. Core Image (`CIPixellate`) does the actual pixelation. Nothing else. If a proposed change doesn't fit this paragraph, it needs justification.

## Stack Constraints (Non-Negotiable)

- **No NSViewRepresentable. No AppKit.** Pure SwiftUI only. If you think you need AppKit, stop and ask.
- **No third-party dependencies.** CoreImage, CoreGraphics, SwiftUI, UniformTypeIdentifiers — that's the entire dependency surface.
- **No mutations to `sourceImage`.** It is set once on load and read forever. Pixelation is applied during `flatten()` and during canvas rendering. The file on disk is never touched until explicit save.
- **No approximations in coordinate mapping.** The `viewToImageCoordinates()` function must account for aspect-ratio letterboxing/pillarboxing and centering offset precisely. Wrong coordinates produce wrong pixelation. This is the highest-risk function.

## File Map

```Pixelator/
PixelatorApp.swift          — @main, DocumentGroup scene only
PixelatorDocument.swift     — all document model logic
PixelatedRegion.swift       — plain value type, no logic
PixelatorDocument.preview()   — static factory for previews
ContentView.swift           — canvas + gesture + toolbar (to be built)
CoordinateMapper.swift      — viewToImageCoordinates(), isolated + testable
PixelatorTests/
CoordinateMapperTests.swift — unit tests for coordinate mapping (required)
FlattenTests.swift          — unit tests for flatten() compositing
PixelatorUITests/
PixelatorUITests.swift      — launch + basic smoke test
```

New files go here. Don't invent new directories.

## The One Function You Must Get Right

```swift
func viewToImageCoordinates(
    viewPoint: CGPoint,
    viewSize: CGSize,
    imageSize: CGSize
) -> CGPoint
```

The image is aspect-ratio scaled to fit inside the canvas, then centered. The function must compute the scale factor (`min(viewW/imgW, viewH/imgH)`), the letterbox/pillarbox offsets, subtract those offsets from the view point, divide by the scale factor, and clamp to image bounds. It must live in `CoordinateMapper.swift` as a free function or a simple struct — not buried inside a view. It must have unit tests before pixelation is wired up.

## Coding Rules

**No comments in production code.** Never add comments unless explicitly requested. Write self-documenting code instead.

**No trailing whitespace.** No space in empty lines. Use trailing newline (exactly one) at file end.

**Explicitness over cleverness.** If there are two ways to write something and one is shorter but requires thinking, use the longer one. This codebase will be read under time pressure.

**No force-unwrap in production paths.** Never use `!` on optionals except in compile-time-guaranteed contexts. Everywhere else: guard-let, if-let, or `throws`.

**One responsibility per file.** `PixelatorDocument` does document logic. `CoordinateMapper` does coordinate math. `ContentView` does layout and gesture handling. Don't let these bleed into each other.

**State lives in the document, not in views.** Views read from `PixelatorDocument` and call `addRegion(_:undoManager:)`. Views do not hold authoritative state about regions or the image.

**Keep `flatten()` pure.** It takes `sourceImage` and `regions`, produces a `CGImage`. It has no side effects. Don't add caching or lazy evaluation without a measured performance reason.

**Undo is the document's job.** Call `undoManager?.registerUndo` inside `addRegion(_:undoManager:)` and `removeLastRegion(undoManager:)` only. Never register undo actions from a view.

## What to Test

`CoordinateMapperTests` must cover:

- Square image in square canvas (no letterboxing)
- Landscape image in square canvas (letterbox top/bottom)
- Portrait image in square canvas (pillarbox left/right)
- Point exactly at image boundary → clamps, does not crash
- Point outside image area (in the letterbox) → clamps to nearest edge

`FlattenTests` must cover:

- No regions → returns `sourceImage` unchanged
- One region → produces an image of the same dimensions
- Region at (0,0) with known pixel size → spot-check that output differs from source in that region

UI tests cover launch only until the full editor is built.

## What Not to Build

- No layers panel, no brush tools, no filters beyond pixelate
- No in-app crop or resize
- No WebP write until `UTType.webP` is confirmed available on the
  deployment target
- No network, no iCloud sync, no sharing sheet
- No preference window, no settings

If a feature isn't in the architecture paragraph above, don't add it without a conversation first.

## When You're Unsure

Read the architecture paragraph again. If the thing you're about to build doesn't serve "open image → drag → pixelate → save", you're probably off-track. The best code in this project is code that isn't written.

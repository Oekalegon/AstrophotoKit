//
//  FITSRulersView.swift
//  AstrophotoKit
//
//  Created by Dieudonné Willems on 31/12/2025.
//

import SwiftUI

/// Rulers showing image pixel coordinates on the edges of the viewport
public struct FITSRulersView: View {
    let imageWidth: Int
    let imageHeight: Int
    let zoom: Float
    let panOffset: SIMD2<Float>
    let cursorPosition: SIMD2<Float>?
    let rulerSize: CGFloat = 20
    
    public init(imageWidth: Int, imageHeight: Int, zoom: Float, panOffset: SIMD2<Float>, cursorPosition: SIMD2<Float>? = nil) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.zoom = zoom
        self.panOffset = panOffset
        self.cursorPosition = cursorPosition
    }
    
    // Calculate aspect ratio correction based on view and image dimensions
    func calculateAspectRatio(viewSize: CGSize) -> SIMD2<Float> {
        guard viewSize.width > 0 && viewSize.height > 0 && imageWidth > 0 && imageHeight > 0 else {
            return SIMD2<Float>(1.0, 1.0)
        }
        
        let imageAspect = Float(imageWidth) / Float(imageHeight)
        let viewAspect = Float(viewSize.width) / Float(viewSize.height)
        
        // Calculate aspect ratio correction (same logic as in FITSImageRenderer)
        if viewAspect > imageAspect {
            // View is wider - scale down X to fit
            return SIMD2<Float>(imageAspect / viewAspect, 1.0)
        } else {
            // View is taller - scale down Y to fit
            return SIMD2<Float>(1.0, viewAspect / imageAspect)
        }
    }
    
    // Convert normalized screen position (-1 to 1) to image pixel coordinates
    func screenToImagePixel(screenPos: SIMD2<Float>, aspectRatio: SIMD2<Float>) -> SIMD2<Float> {
        // Use shared coordinate converter
        guard let texCoord = FITSCoordinateConverter.screenToTextureCoord(
            normalizedX: screenPos.x,
            normalizedY: screenPos.y,
            zoom: zoom,
            panOffset: panOffset,
            aspectRatio: aspectRatio
        ) else {
            // Return (0, 0) if out of bounds (ruler can handle this)
            return SIMD2<Float>(0, 0)
        }
        
        // Convert texture coordinates to image pixel coordinates
        // Texture (0,0) is top-left of image, (1,1) is bottom-right
        return SIMD2<Float>(
            texCoord.x * Float(imageWidth),
            texCoord.y * Float(imageHeight)
        )
    }
    
    // Calculate tick spacing based on zoom level
    // Returns standard spacing values: 1, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, etc.
    func calculateTickSpacing() -> Float {
        // Calculate how many image pixels are visible in the viewport
        // The viewport is 2 units wide in normalized coordinates
        // At zoom level z, we see 2/z units of the image in normalized space
        // In image pixel space, that's (2/z) * imageSize / 2 = imageSize / z
        let visiblePixels = Float(min(imageWidth, imageHeight)) / zoom
        
        // Choose appropriate standard spacing: 1, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, etc.
        let standardSpacings: [Float] = [1, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000]
        
        // Find the largest standard spacing that gives us at least 5 ticks visible
        // We want about 5-15 ticks visible for good readability
        for spacing in standardSpacings.reversed() {
            if visiblePixels / spacing >= 5 {
                return spacing
            }
        }
        
        // If we're very zoomed in, use the smallest spacing
        return 1
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let tickSpacing = calculateTickSpacing()
            let fullWidth = geometry.size.width
            let fullHeight = geometry.size.height
            let aspectRatio = calculateAspectRatio(viewSize: geometry.size)
            
            // Top ruler
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Corner spacer - fill with background color
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .frame(width: rulerSize, height: rulerSize)
                    
                    // Top ruler
                    HorizontalRuler(
                        position: .top,
                        imageWidth: imageWidth,
                        zoom: zoom,
                        panOffset: panOffset,
                        aspectRatio: aspectRatio,
                        tickSpacing: tickSpacing,
                        width: fullWidth - rulerSize * 2,
                        fullViewportWidth: fullWidth,
                        rulerOffset: rulerSize,
                        cursorPosition: cursorPosition
                    )
                    .frame(height: rulerSize)
                    
                    // Corner spacer - fill with background color
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .frame(width: rulerSize, height: rulerSize)
                }
                
                HStack(spacing: 0) {
                    // Left ruler
                    VerticalRuler(
                        position: .left,
                        imageHeight: imageHeight,
                        zoom: zoom,
                        panOffset: panOffset,
                        aspectRatio: aspectRatio,
                        tickSpacing: tickSpacing,
                        height: fullHeight - rulerSize * 2,
                        fullViewportHeight: fullHeight,
                        rulerOffset: rulerSize,
                        cursorPosition: cursorPosition
                    )
                    .frame(width: rulerSize)
                    
                    // Content area (transparent - Metal view shows through)
                    Spacer()
                    
                    // Right ruler
                    VerticalRuler(
                        position: .right,
                        imageHeight: imageHeight,
                        zoom: zoom,
                        panOffset: panOffset,
                        aspectRatio: aspectRatio,
                        tickSpacing: tickSpacing,
                        height: fullHeight - rulerSize * 2,
                        fullViewportHeight: fullHeight,
                        rulerOffset: rulerSize,
                        cursorPosition: cursorPosition
                    )
                    .frame(width: rulerSize)
                }
                
                // Bottom ruler
                HStack(spacing: 0) {
                    // Corner spacer - fill with background color
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .frame(width: rulerSize, height: rulerSize)
                    
                    // Bottom ruler
                    HorizontalRuler(
                        position: .bottom,
                        imageWidth: imageWidth,
                        zoom: zoom,
                        panOffset: panOffset,
                        aspectRatio: aspectRatio,
                        tickSpacing: tickSpacing,
                        width: fullWidth - rulerSize * 2,
                        fullViewportWidth: fullWidth,
                        rulerOffset: rulerSize,
                        cursorPosition: cursorPosition
                    )
                    .frame(height: rulerSize)
                    
                    // Corner spacer - fill with background color
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .frame(width: rulerSize, height: rulerSize)
                }
            }
        }
    }
}

enum HorizontalRulerPosition {
    case top
    case bottom
}

enum VerticalRulerPosition {
    case left
    case right
}

// Horizontal ruler (shows X coordinates) - used for both top and bottom
struct HorizontalRuler: View {
    let position: HorizontalRulerPosition
    let imageWidth: Int
    let zoom: Float
    let panOffset: SIMD2<Float>
    let aspectRatio: SIMD2<Float>
    let tickSpacing: Float
    let width: CGFloat
    let fullViewportWidth: CGFloat
    let rulerOffset: CGFloat
    let cursorPosition: SIMD2<Float>?
    
    func screenToImagePixel(screenPos: SIMD2<Float>) -> SIMD2<Float> {
        // Use shared coordinate converter
        guard let texCoord = FITSCoordinateConverter.screenToTextureCoord(
            normalizedX: screenPos.x,
            normalizedY: screenPos.y,
            zoom: zoom,
            panOffset: panOffset,
            aspectRatio: aspectRatio
        ) else {
            return SIMD2<Float>(0, 0)
        }
        return SIMD2<Float>(
            texCoord.x * Float(imageWidth),
            texCoord.y * Float(imageWidth)  // Not used for horizontal ruler
        )
    }
    
    var body: some View {
        Canvas { context, size in
            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(NSColor.controlBackgroundColor).opacity(0.9))
            )
            
            // Border
            context.stroke(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.secondary.opacity(0.3)),
                lineWidth: 1
            )
            
            // Calculate visible range - use different Y coordinates based on position
            let yCoord: Float = position == .top ? 1.0 : -1.0
            var leftPixel = screenToImagePixel(screenPos: SIMD2<Float>(-1.0, yCoord)).x
            var rightPixel = screenToImagePixel(screenPos: SIMD2<Float>(1.0, yCoord)).x
            
            // Clamp to image bounds and handle out-of-bounds (when coordinate conversion fails)
            // If out of bounds, show the full image range
            if leftPixel == 0 && rightPixel == 0 {
                // Coordinate conversion failed - show full image
                leftPixel = 0
                rightPixel = Float(imageWidth)
            } else {
                // Clamp to valid range
                leftPixel = max(0, min(Float(imageWidth), leftPixel))
                rightPixel = max(0, min(Float(imageWidth), rightPixel))
                // Ensure we have a valid range
                if leftPixel >= rightPixel {
                    leftPixel = 0
                    rightPixel = Float(imageWidth)
                }
            }
            
            // Draw ticks and labels - add micro ticks at smaller intervals
            let microTickSpacing = tickSpacing / 5.0
            let startTick = Int(floor(leftPixel / microTickSpacing)) * Int(microTickSpacing)
            let endTick = Int(ceil(rightPixel / microTickSpacing)) * Int(microTickSpacing)
            
            for tick in stride(from: startTick, through: endTick, by: Int(microTickSpacing)) {
                if tick < 0 || tick > imageWidth { continue }
                
                    // Convert pixel to screen position
                    // The normalized coordinates represent the full viewport
                    // But the ruler Canvas is offset by rulerOffset pixels
                    let texCoord = Float(tick) / Float(imageWidth)
                    let vertexX = texCoord * 2.0 - 1.0
                    // Account for aspect ratio: screenPos = (vertexPos * aspectRatio) * zoom + panOffset
                    // panOffset is sent directly to shader (panOffset.y is stored inverted but used as-is)
                    let screenX = vertexX * aspectRatio.x * zoom + panOffset.x
                    // Convert normalized coordinate (-1 to 1) to full viewport coordinate (0 to fullViewportWidth)
                    // Normalized: -1 is left, 1 is right
                    // View: 0 is left, fullViewportWidth is right
                    // So: viewX = (normalizedX + 1) / 2 * fullViewportWidth
                    let fullViewportX = CGFloat((screenX + 1.0) / 2.0) * fullViewportWidth
                    // Convert to ruler coordinate (accounting for left ruler offset)
                    let x = fullViewportX - rulerOffset
                
                if x >= 0 && x <= size.width {
                    // Draw tick - use different heights for major, medium, minor, and micro ticks
                    // Major ticks at standard intervals: every tickSpacing (which is already a standard value)
                    // For example: if tickSpacing=10, major ticks at 0, 10, 20, 30, 40, ...
                    let isMajorTick = tick % Int(tickSpacing) == 0
                    let isMediumTick = tick % Int(microTickSpacing * 2) == 0 && !isMajorTick
                    let isMicroTick = tick % Int(microTickSpacing) == 0 && !isMediumTick && !isMajorTick
                    let tickHeight: CGFloat = isMajorTick ? size.height : (isMediumTick ? 6 : (isMicroTick ? 2 : 1))
                    // Draw tick - direction depends on position
                    if position == .top {
                        // Top: ticks go down from bottom
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: size.height))
                                path.addLine(to: CGPoint(x: x, y: size.height - tickHeight))
                            },
                            with: .color(Color(NSColor.tertiaryLabelColor)),
                            lineWidth: 1
                        )
                    } else {
                        // Bottom: ticks go up from top
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: tickHeight))
                            },
                            with: .color(Color(NSColor.tertiaryLabelColor)),
                            lineWidth: 1
                        )
                    }
                    
                    // Draw label only for major ticks (at standard intervals)
                    if isMajorTick {
                        let resolvedText = context.resolve(Text("\(tick)").font(.system(size: 10)).foregroundColor(.secondary))
                        if position == .top {
                            // Top: labels above ticks
                            let labelY = size.height/2.0
                            context.draw(resolvedText, at: CGPoint(x: x+4.0, y: labelY), anchor: .leading)
                        } else {
                            // Bottom: labels below ticks
                            let labelY = size.height/2.0
                            context.draw(resolvedText, at: CGPoint(x: x+4.0, y: labelY), anchor: .leading)
                        }
                    }
                }
                
                // Draw cursor line if cursor is visible
                if let cursorPos = cursorPosition {
                    // Convert cursor normalized position to ruler coordinate
                    let fullViewportX = CGFloat((cursorPos.x + 1.0) / 2.0) * fullViewportWidth
                    let cursorX = fullViewportX - rulerOffset
                    
                    if cursorX >= 0 && cursorX <= size.width {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: cursorX, y: 0))
                                path.addLine(to: CGPoint(x: cursorX, y: size.height))
                            },
                            with: .color(.red.opacity(0.8)),
                            lineWidth: 1.5
                        )
                    }
                }
            }
        }
    }
}


// Vertical ruler (shows Y coordinates) - used for both left and right
struct VerticalRuler: View {
    let position: VerticalRulerPosition
    let imageHeight: Int
    let zoom: Float
    let panOffset: SIMD2<Float>
    let aspectRatio: SIMD2<Float>
    let tickSpacing: Float
    let height: CGFloat
    let fullViewportHeight: CGFloat
    let rulerOffset: CGFloat
    let cursorPosition: SIMD2<Float>?
    
    func screenToImagePixel(screenPos: SIMD2<Float>) -> SIMD2<Float> {
        // Use shared coordinate converter
        guard let texCoord = FITSCoordinateConverter.screenToTextureCoord(
            normalizedX: screenPos.x,
            normalizedY: screenPos.y,
            zoom: zoom,
            panOffset: panOffset,
            aspectRatio: aspectRatio
        ) else {
            return SIMD2<Float>(0, 0)
        }
        return SIMD2<Float>(
            texCoord.x * Float(imageHeight),  // Not used for vertical ruler
            texCoord.y * Float(imageHeight)
        )
    }
    
    var body: some View {
        ZStack {
            Canvas { context, size in
                // Background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(NSColor.controlBackgroundColor).opacity(0.9))
                )
                
                // Border
                context.stroke(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.secondary.opacity(0.3)),
                    lineWidth: 1
                )
                
                // Calculate visible range - use different X coordinates based on position
                let xCoord: Float = position == .left ? -1.0 : 1.0
                var topPixel = screenToImagePixel(screenPos: SIMD2<Float>(xCoord, 1.0)).y
                var bottomPixel = screenToImagePixel(screenPos: SIMD2<Float>(xCoord, -1.0)).y
                
                // Clamp to image bounds and handle out-of-bounds (when coordinate conversion fails)
                // If out of bounds, show the full image range
                if topPixel == 0 && bottomPixel == 0 {
                    // Coordinate conversion failed - show full image
                    topPixel = 0
                    bottomPixel = Float(imageHeight)
                } else {
                    // Clamp to valid range
                    topPixel = max(0, min(Float(imageHeight), topPixel))
                    bottomPixel = max(0, min(Float(imageHeight), bottomPixel))
                    // Ensure we have a valid range
                    if topPixel >= bottomPixel {
                        topPixel = 0
                        bottomPixel = Float(imageHeight)
                    }
                }
                
                // Draw ticks and labels - add micro ticks at smaller intervals
                // We want to display y=0 at the top of the ruler
                // Display value equals pixel value (no inversion needed - we want y=0 at top)
                let topDisplay = topPixel  // topPixel is at top, display 0 should be at top
                let bottomDisplay = bottomPixel  // bottomPixel is at bottom, display imageHeight should be at bottom
                
                let microTickSpacing = tickSpacing / 5.0
                let startDisplay = Int(floor(min(topDisplay, bottomDisplay) / microTickSpacing)) * Int(microTickSpacing)
                let endDisplay = Int(ceil(max(topDisplay, bottomDisplay) / microTickSpacing)) * Int(microTickSpacing)
                
                for displayTick in stride(from: startDisplay, through: endDisplay, by: Int(microTickSpacing)) {
                    if displayTick < 0 || displayTick > imageHeight { continue }
                    
                    // Display value equals pixel value (no inversion needed - we want y=0 at top)
                    let tick = displayTick  // display 0 = pixel 0 (both at top)
                    let tickFloat = Float(tick)
                    
                    // Convert image pixel coordinate to view position
                    // Image pixel 0 is at top (texCoord y=0), pixel imageHeight is at bottom (texCoord y=1)
                    let texCoordY = tickFloat / Float(imageHeight)
                    // Texture coordinate to vertex position
                    // From vertices: texture (0,0) at vertex (-1,1), texture (1,1) at vertex (1,-1)
                    // So: texture y=0 -> vertex y=1, texture y=1 -> vertex y=-1
                    // vertexY = 1.0 - texCoordY * 2.0
                    let vertexY = 1.0 - texCoordY * 2.0  // 0->1 -> 1->-1
                    // Vertex position to screen normalized position: screenPos = (vertexPos * aspectRatio) * zoom + panOffset
                    // panOffset is sent directly to shader (panOffset.y is stored inverted but used as-is)
                    let screenY = vertexY * aspectRatio.y * zoom + panOffset.y
                    // Screen normalized coordinate to view coordinate
                    // The pan handler converts: view y=0 (top) -> normalizedY=1, view y=height (bottom) -> normalizedY=-1
                    // So to convert back: normalizedY -> viewY = (1 - normalizedY) / 2 * height
                    // But screenY is already in normalized coordinates, so:
                    let fullViewportY = CGFloat((1.0 - screenY) / 2.0) * fullViewportHeight
                    // Convert to ruler coordinate (accounting for top ruler offset)
                    // The ruler Canvas starts after the top ruler (at y=rulerOffset in full viewport)
                    let y = fullViewportY - rulerOffset
                    
                    if y >= 0 && y <= size.height {
                        // Draw tick - use different widths for major, medium, minor, and micro ticks
                        // Check if this is a major/medium/micro tick based on display value
                        let isMajorTick = displayTick % Int(tickSpacing) == 0
                        let isMediumTick = displayTick % Int(microTickSpacing * 2) == 0 && !isMajorTick
                        let isMicroTick = displayTick % Int(microTickSpacing) == 0 && !isMediumTick && !isMajorTick
                        let tickWidth: CGFloat = isMajorTick ? size.width : (isMediumTick ? 6 : (isMicroTick ? 2 : 1))
                        // Draw tick - direction depends on position
                        if position == .left {
                            // Left: ticks go right from left edge
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: size.width, y: y))
                                    path.addLine(to: CGPoint(x: size.width - tickWidth, y: y))
                                },
                                with: .color(Color(NSColor.tertiaryLabelColor)),
                                lineWidth: 1
                            )
                        } else {
                            // Right: ticks go left from right edge
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: tickWidth, y: y))
                                },
                                with: .color(Color(NSColor.tertiaryLabelColor)),
                                lineWidth: 1
                            )
                        }
                        // Draw label only for major ticks (at standard intervals)
                        // Display the display value (y=0 at top)
                        if isMajorTick {
                            if position == .left {
                                // Left: labels centered
                                let labelX = size.width/2.0
                                self.drawText("\(displayTick)", at: CGPoint(x: labelX, y: y+4.0), rotation: Angle(degrees: -90), context: context)
                            } else {
                                // Right: labels centered
                                let labelX = size.width/2.0
                                self.drawText("\(displayTick)", at: CGPoint(x: labelX, y: y+4.0), rotation: Angle(degrees: 90), context: context)
                            }
                        }
                    }
                }
                
                // Draw cursor line if cursor is visible
                if let cursorPos = cursorPosition {
                    // Convert cursor normalized position to ruler coordinate
                    // Normalized: -1 is bottom, 1 is top
                    // SwiftUI view: 0 is top, height is bottom
                    // So: normalized y=-1 -> view y=height, normalized y=1 -> view y=0
                    let fullViewportY = CGFloat((1.0 - cursorPos.y) / 2.0) * fullViewportHeight
                    // The ruler canvas starts at y=rulerOffset and has height = fullViewportHeight - rulerOffset * 2
                    // Convert from full viewport Y to ruler canvas Y (ruler canvas has 0 at top)
                    let cursorY = fullViewportY - rulerOffset
                    
                    if cursorY >= 0 && cursorY <= size.height {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: cursorY))
                                path.addLine(to: CGPoint(x: size.width, y: cursorY))
                            },
                            with: .color(.red.opacity(0.8)),
                            lineWidth: 1.5
                        )
                    }
                }
            }
        }
    }
    
    func drawText(
        _ text: String,
        at position: CGPoint,
        rotation: Angle = .zero,
        context: GraphicsContext
    ) {
        let resolvedText = context.resolve(
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.primary)
        )

        var textContext = context
        textContext.translateBy(x: position.x, y: position.y)
        textContext.rotate(by: rotation)
        
        var anchor = UnitPoint.trailing
        if rotation.degrees > 0 {
            anchor = .leading
        }

        textContext.draw(
            resolvedText,
            at: .zero,
            anchor: anchor
        )
    }
}



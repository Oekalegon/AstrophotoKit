#include <metal_stdlib>
using namespace metal;

/// Compute shader to draw ellipses around stars on an image
/// For each pixel, checks if it's inside any ellipse and draws it
/// Ellipse data is stored as 5 floats per ellipse: [centroidX, centroidY, majorAxis, minorAxis, rotationAngle]
/// Note: inputTexture and outputTexture can be the same (RGBA texture with background already copied)
kernel void draw_ellipses(texture2d<float> inputTexture [[texture(0)]],
                          texture2d<float, access::read_write> outputTexture [[texture(1)]],
                          device const float* ellipseData [[buffer(0)]], // Array of 5 floats per ellipse
                          constant int& numEllipses [[buffer(1)]],
                          device const float* ellipseColorData [[buffer(2)]], // RGB color [r, g, b]
                          constant float& ellipseWidth [[buffer(3)]], // Line width in pixels
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read original pixel value from RGBA output texture (background already copied)
    float4 originalColor = outputTexture.read(gid);
    
    // Use pixel coordinates directly (gid matches pixel position)
    float2 pixelPos = float2(gid.x, gid.y);
    
    // Background is already RGB (grayscale converted to RGB)
    float3 originalRGB = originalColor.rgb;
    float3 outputRGB = originalRGB;
    
    // Get ellipse color
    float3 ellipseColor = float3(ellipseColorData[0], ellipseColorData[1], ellipseColorData[2]);
    
    // Check if this pixel is on any ellipse boundary or axis
    bool isOnEllipse = false;
    bool isOnAxis = false;
    
    for (int i = 0; i < numEllipses; i++) {
        int offset = i * 5;
        float centroidX = ellipseData[offset + 0];
        float centroidY = ellipseData[offset + 1];
        float majorAxis = ellipseData[offset + 2];
        float minorAxis = ellipseData[offset + 3];
        float rotationAngle = ellipseData[offset + 4];
        
        float2 centroid = float2(centroidX, centroidY);
        float2 translated = pixelPos - centroid;
        
        // Rotate by negative angle to transform to ellipse-local coordinates
        float cosAngle = cos(-rotationAngle);
        float sinAngle = sin(-rotationAngle);
        float2 rotated = float2(
            cosAngle * translated.x - sinAngle * translated.y,
            sinAngle * translated.x + cosAngle * translated.y
        );
        
        // Check if point is on ellipse boundary: (x/a)² + (y/b)² ≈ 1
        float ellipseValue = (rotated.x * rotated.x) / (majorAxis * majorAxis) +
                            (rotated.y * rotated.y) / (minorAxis * minorAxis);
        
        // Check if pixel is on or near the ellipse boundary (1 pixel wide)
        // Use a fixed threshold for 1-pixel width regardless of ellipse size
        float distance = abs(ellipseValue - 1.0);
        // For 1 pixel width, we want pixels where distance is small
        // The threshold should account for the ellipse size to get approximately 1 pixel
        float avgRadius = (majorAxis + minorAxis) * 0.5;
        float threshold = 1.0 / max(avgRadius, 1.0); // Approximately 1 pixel wide
        
        if (distance <= threshold) {
            isOnEllipse = true;
        }
        
        // Check if pixel is on major or minor axis
        // Major axis: rotated.y ≈ 0 (horizontal in ellipse-local coordinates)
        // Minor axis: rotated.x ≈ 0 (vertical in ellipse-local coordinates)
        float distToMajorAxis = abs(rotated.y);
        float distToMinorAxis = abs(rotated.x);
        
        // Check if within 0.5 pixels of an axis and within ellipse bounds
        if (ellipseValue <= 1.0) {
            if (distToMajorAxis <= 0.5 || distToMinorAxis <= 0.5) {
                isOnAxis = true;
            }
        }
    }
    
    // If pixel is on ellipse or axis, use ellipse color
    if (isOnEllipse || isOnAxis) {
        // Use ellipse color directly (not blended) for visibility
        outputRGB = ellipseColor;
    }
    
    outputTexture.write(float4(outputRGB, 1.0), gid);
}

/// Compute shader to copy grayscale texture to RGBA texture
/// Copies the grayscale value to all RGB channels
kernel void copy_grayscale_to_rgba(texture2d<float> inputTexture [[texture(0)]],
                                    texture2d<float, access::write> outputTexture [[texture(1)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float2 texCoord = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
    float4 inputColor = inputTexture.sample(textureSampler, texCoord);
    
    // Copy grayscale value to all RGB channels
    float grayValue = inputColor.r;
    outputTexture.write(float4(grayValue, grayValue, grayValue, 1.0), gid);
}

/// Helper function to calculate distance from point to line segment
float distanceToLineSegment(float2 point, float2 lineStart, float2 lineEnd) {
    float2 lineDir = lineEnd - lineStart;
    float lineLength = length(lineDir);
    
    if (lineLength < 0.0001) {
        // Degenerate line segment, return distance to point
        return length(point - lineStart);
    }
    
    float2 lineUnit = lineDir / lineLength;
    float2 toPoint = point - lineStart;
    float projection = dot(toPoint, lineUnit);
    
    // Clamp projection to line segment
    projection = clamp(projection, 0.0, lineLength);
    
    float2 closestPoint = lineStart + lineUnit * projection;
    return length(point - closestPoint);
}

/// Compute shader to draw quads (4-point quadrilaterals) on an image
/// Quad data is stored as 8 floats per quad: [x1, y1, x2, y2, x3, y3, x4, y4]
/// Draws lines connecting: S1->S2->S3->S4->S1
kernel void draw_quads(texture2d<float> inputTexture [[texture(0)]],
                       texture2d<float, access::read_write> outputTexture [[texture(1)]],
                       device const float* quadData [[buffer(0)]], // Array of 8 floats per quad
                       constant int& numQuads [[buffer(1)]],
                       device const float* quadColorData [[buffer(2)]], // RGB color [r, g, b]
                       constant float& quadWidth [[buffer(3)]], // Line width in pixels
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read original pixel value
    float4 originalColor = outputTexture.read(gid);
    float3 originalRGB = originalColor.rgb;
    float3 outputRGB = originalRGB;
    
    // Get quad color
    float3 quadColor = float3(quadColorData[0], quadColorData[1], quadColorData[2]);
    
    // Use pixel coordinates directly
    float2 pixelPos = float2(gid.x, gid.y);
    
    // Check if this pixel is on any quad line
    bool isOnQuad = false;
    
    for (int i = 0; i < numQuads; i++) {
        int offset = i * 8;
        float2 p1 = float2(quadData[offset + 0], quadData[offset + 1]);
        float2 p2 = float2(quadData[offset + 2], quadData[offset + 3]);
        float2 p3 = float2(quadData[offset + 4], quadData[offset + 5]);
        float2 p4 = float2(quadData[offset + 6], quadData[offset + 7]);
        
        // Check distance to each line segment: S1->S2, S2->S3, S3->S4, S4->S1
        float dist1 = distanceToLineSegment(pixelPos, p1, p2);
        float dist2 = distanceToLineSegment(pixelPos, p2, p3);
        float dist3 = distanceToLineSegment(pixelPos, p3, p4);
        float dist4 = distanceToLineSegment(pixelPos, p4, p1);
        
        // Check if pixel is within quadWidth/2 of any line segment
        float halfWidth = quadWidth * 0.5;
        if (dist1 <= halfWidth || dist2 <= halfWidth || dist3 <= halfWidth || dist4 <= halfWidth) {
            isOnQuad = true;
            break;
        }
    }
    
    // If pixel is on quad line, use quad color
    if (isOnQuad) {
        outputRGB = quadColor;
    }
    
    outputTexture.write(float4(outputRGB, 1.0), gid);
}


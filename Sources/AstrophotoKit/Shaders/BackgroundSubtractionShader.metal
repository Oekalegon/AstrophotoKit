#include <metal_stdlib>
using namespace metal;

/// Compute shader for background subtraction
/// Subtracts a constant background level from each pixel and clamps to zero
kernel void background_subtract(texture2d<float> inputTexture [[texture(0)]],
                                  texture2d<float, access::write> outputTexture [[texture(1)]],
                                  constant float& backgroundLevel [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    // Check bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read input pixel
    float4 inputPixel = inputTexture.read(gid);
    
    // Subtract background and clamp to zero
    float4 result = max(float4(0.0), inputPixel - float4(backgroundLevel));
    
    // Write output
    outputTexture.write(result, gid);
}

/// Compute shader to create a uniform background texture
/// Fills the entire texture with a constant background level
kernel void background_fill(texture2d<float, access::write> outputTexture [[texture(0)]],
                          constant float& backgroundLevel [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    // Check bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Write uniform background level
    outputTexture.write(float4(backgroundLevel), gid);
}


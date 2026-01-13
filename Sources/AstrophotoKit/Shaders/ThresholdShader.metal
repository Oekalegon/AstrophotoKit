#include <metal_stdlib>
using namespace metal;

/// Compute shader for thresholding
/// Creates a binary mask where pixels >= threshold are set to 1.0, others to 0.0
kernel void threshold(texture2d<float> inputTexture [[texture(0)]],
                      texture2d<float, access::write> outputTexture [[texture(1)]],
                      constant float& thresholdValue [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    // Check bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read input pixel
    float4 inputPixel = inputTexture.read(gid);
    
    // Apply threshold: 1.0 if >= threshold, 0.0 otherwise
    float4 result = select(float4(0.0), float4(1.0), inputPixel >= float4(thresholdValue));
    
    // Write output
    outputTexture.write(result, gid);
}


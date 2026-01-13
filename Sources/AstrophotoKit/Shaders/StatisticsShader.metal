#include <metal_stdlib>
using namespace metal;

/// Compute shader for calculating mean and standard deviation
/// Uses atomic operations to accumulate sum and sum of squares
kernel void calculate_mean_stddev(texture2d<float> inputTexture [[texture(0)]],
                                  device atomic_float* sumBuffer [[buffer(0)]],
                                  device atomic_float* sumSqBuffer [[buffer(1)]],
                                  constant float& imageMinValue [[buffer(2)]],
                                  constant float& imageMaxValue [[buffer(3)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read pixel and convert to actual value
    float4 pixel = inputTexture.read(gid);
    float normalizedValue = pixel.r;
    float imageRange = imageMaxValue - imageMinValue;
    float pixelValue = imageMinValue + normalizedValue * imageRange;
    float pixelValueSq = pixelValue * pixelValue;
    
    // Atomic add to sum and sum of squares
    atomic_fetch_add_explicit(sumBuffer, pixelValue, memory_order_relaxed);
    atomic_fetch_add_explicit(sumSqBuffer, pixelValueSq, memory_order_relaxed);
}

/// Compute shader for building a histogram for median/MAD/percentile calculation
/// Uses a histogram-based approach for efficient median calculation
kernel void build_histogram(texture2d<float> inputTexture [[texture(0)]],
                            device atomic_int* histogram [[buffer(0)]],
                            constant int& numBins [[buffer(1)]],
                            constant float& imageMinValue [[buffer(2)]],
                            constant float& imageMaxValue [[buffer(3)]],
                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read pixel and convert to actual value
    float4 pixel = inputTexture.read(gid);
    float normalizedValue = pixel.r;
    float pixelValue = imageMinValue + normalizedValue * (imageMaxValue - imageMinValue);
    
    // Map to histogram bin
    float imageRange = imageMaxValue - imageMinValue;
    float normalizedForBin = (pixelValue - imageMinValue) / imageRange;
    normalizedForBin = clamp(normalizedForBin, 0.0f, 1.0f);
    
    int binIndex = min(int(normalizedForBin * float(numBins)), numBins - 1);
    
    // Atomic increment histogram bin
    atomic_fetch_add_explicit(&histogram[binIndex], 1, memory_order_relaxed);
}

/// Compute shader for building histogram of absolute deviations for MAD calculation
kernel void build_mad_histogram(texture2d<float> inputTexture [[texture(0)]],
                                 device atomic_int* histogram [[buffer(0)]],
                                 constant int& numBins [[buffer(1)]],
                                 constant float& imageMinValue [[buffer(2)]],
                                 constant float& imageMaxValue [[buffer(3)]],
                                 constant float& medianValue [[buffer(4)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read pixel and convert to actual value
    float4 pixel = inputTexture.read(gid);
    float normalizedValue = pixel.r;
    float pixelValue = imageMinValue + normalizedValue * (imageMaxValue - imageMinValue);
    
    // Calculate absolute deviation from median
    float absDeviation = abs(pixelValue - medianValue);
    
    // Map to histogram bin (use full range for deviations)
    float imageRange = imageMaxValue - imageMinValue;
    float normalizedForBin = absDeviation / imageRange;
    normalizedForBin = clamp(normalizedForBin, 0.0f, 1.0f);
    
    int binIndex = min(int(normalizedForBin * float(numBins)), numBins - 1);
    
    // Atomic increment histogram bin
    atomic_fetch_add_explicit(&histogram[binIndex], 1, memory_order_relaxed);
}


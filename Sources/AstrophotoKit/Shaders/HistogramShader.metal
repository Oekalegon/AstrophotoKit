#include <metal_stdlib>
using namespace metal;

/// Compute shader to calculate histogram of a FITS image
/// Input: texture2d<float> - the FITS image texture (normalized 0-1)
/// Output: device uint* - histogram bins (must be pre-allocated with numBins elements)
/// Parameters: numBins - number of histogram bins
///             imageMinValue, imageMaxValue - full image pixel value range (for converting normalized texture values)
///             histogramMinValue, histogramMaxValue - histogram range (for binning, may be black/white points)
kernel void histogram_compute(texture2d<float> inputTexture [[texture(0)]],
                                    device atomic_uint* histogram [[buffer(0)]],
                                    constant uint& numBins [[buffer(1)]],
                                    constant float& imageMinValue [[buffer(2)]],
                                    constant float& imageMaxValue [[buffer(3)]],
                                    constant float& histogramMinValue [[buffer(4)]],
                                    constant float& histogramMaxValue [[buffer(5)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    // Check bounds
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read pixel value directly using integer coordinates (no sampling, no interpolation)
    // This ensures we get exact pixel values without any quantization
    float normalizedValue = inputTexture.read(uint2(gid.x, gid.y)).r;
    
    // Clamp normalized value to [0, 1] range
    normalizedValue = clamp(normalizedValue, 0.0f, 1.0f);
    
    // Convert normalized value (0-1) to full image pixel value range
    float imageRange = imageMaxValue - imageMinValue;
    float pixelValue = imageMinValue + normalizedValue * imageRange;
    
    // Calculate which bin this pixel belongs to
    // Map [histogramMinValue, histogramMaxValue] to [0, numBins-1]
    float histogramRange = histogramMaxValue - histogramMinValue;
    if (histogramRange <= 0.0f) {
        return; // Invalid range
    }
    
    // Only count pixels within the histogram range (black/white points)
    // Use <= and >= to include pixels exactly at the boundaries
    if (pixelValue < histogramMinValue || pixelValue > histogramMaxValue) {
        return; // Skip pixels outside the histogram range
    }
    
    // Calculate normalized position within histogram range
    // Map [histogramMinValue, histogramMaxValue] to [0, 1]
    // For pixelValue at histogramMinValue: we want bin 0
    // For pixelValue at histogramMaxValue: we want bin (numBins-1)
    float normalizedForBin = (pixelValue - histogramMinValue) / histogramRange;
    
    // Clamp to [0, 1] to handle floating point precision issues
    // Then map to [0, numBins-1] with special handling for the max value
    normalizedForBin = clamp(normalizedForBin, 0.0f, 1.0f);
    
    // Map to bin index: [0, 1] -> [0, numBins-1]
    // Special case: if normalizedForBin == 1.0, map to last bin (numBins - 1)
    float binFloat;
    if (normalizedForBin >= 1.0f) {
        binFloat = float(numBins - 1);
    } else {
        binFloat = normalizedForBin * float(numBins);
    }
    uint binIndex = min(uint(floor(binFloat)), numBins - 1);
    
    // Atomically increment the histogram bin
    atomic_fetch_add_explicit(&histogram[binIndex], 1, memory_order_relaxed);
}


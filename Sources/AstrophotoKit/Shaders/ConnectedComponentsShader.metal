#include <metal_stdlib>
using namespace metal;

/// Structure to represent a 2D coordinate
struct Coordinate {
    int x;
    int y;
};

/// Compute shader to count non-zero pixels in a binary image
/// Uses atomic operations to count pixels
kernel void count_nonzero_pixels(texture2d<float> inputTexture [[texture(0)]],
                                  device atomic_int* countBuffer [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read pixel
    float4 pixel = inputTexture.read(gid);
    
    // If pixel is non-zero (>= 0.5 for binary images), increment count
    if (pixel.r >= 0.5) {
        atomic_fetch_add_explicit(countBuffer, 1, memory_order_relaxed);
    }
}

/// Compute shader to collect coordinates of non-zero pixels
/// Uses atomic operations to write coordinates to a buffer
kernel void collect_nonzero_coordinates(texture2d<float> inputTexture [[texture(0)]],
                                        device Coordinate* coordinateBuffer [[buffer(0)]],
                                        device atomic_int* indexBuffer [[buffer(1)]],
                                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read pixel
    float4 pixel = inputTexture.read(gid);
    
    // If pixel is non-zero (>= 0.5 for binary images), add coordinate
    if (pixel.r >= 0.5) {
        // Atomically get the next index
        int index = atomic_fetch_add_explicit(indexBuffer, 1, memory_order_relaxed);
        
        // Write coordinate to buffer
        coordinateBuffer[index] = Coordinate{int(gid.x), int(gid.y)};
    }
}


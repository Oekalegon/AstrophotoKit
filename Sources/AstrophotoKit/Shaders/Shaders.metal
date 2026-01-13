#include <metal_stdlib>
using namespace metal;

/// Example Metal shader for AstrophotoKit
/// Replace this with your actual shader code

kernel void exampleKernel(device float *input [[buffer(0)]],
                          device float *output [[buffer(1)]],
                          uint id [[thread_position_in_grid]]) {
    output[id] = input[id] * 2.0;
}


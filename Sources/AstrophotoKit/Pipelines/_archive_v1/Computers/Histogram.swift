import Foundation
import Metal
import MetalKit
import os

/// Represents histogram data for a FITS image
public struct Histogram {
    /// Number of bins in the histogram
    public let numBins: Int
    /// Bin counts (number of pixels in each bin)
    public let binCounts: [UInt32]
    /// Minimum pixel value (normalized 0-1)
    public let minValue: Float
    /// Maximum pixel value (normalized 0-1)
    public let maxValue: Float
    
    /// Total number of pixels counted
    public var totalPixels: UInt32 {
        binCounts.reduce(0, +)
    }
    
    /// Maximum bin count (for scaling)
    public var maxBinCount: UInt32 {
        binCounts.max() ?? 0
    }
    
    /// Normalized bin counts (0-1 range)
    public var normalizedBinCounts: [Float] {
        let max = Float(maxBinCount)
        guard max > 0 else { return Array(repeating: 0, count: numBins) }
        return binCounts.map { Float($0) / max }
    }
}

/// Computes histograms from FITS images using Metal
public class HistogramComputer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipelineState: MTLComputePipelineState
    
    /// Initialize the histogram computer
    /// - Parameter device: Optional Metal device (uses default if nil)
    public init(device: MTLDevice? = nil) throws {
        guard let device = device ?? MTLCreateSystemDefaultDevice() else {
            throw HistogramError.metalNotSupported
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw HistogramError.couldNotCreateCommandQueue
        }
        self.commandQueue = commandQueue
        
        // Load the compute shader
        guard let library = AstrophotoKit.makeShaderLibrary(device: device) else {
            throw HistogramError.couldNotLoadShaderLibrary
        }
        
        guard let computeFunction = library.makeFunction(name: "histogram_compute") else {
            throw HistogramError.couldNotLoadComputeFunction
        }
        
        do {
            self.computePipelineState = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            throw HistogramError.couldNotCreatePipelineState(error)
        }
    }
    
    /// Computes histogram from a Metal texture
    /// - Parameters:
    ///   - texture: The Metal texture to analyze
    ///   - numBins: Number of histogram bins (default: 256)
    ///   - minValue: Minimum pixel value in original data (for histogram range)
    ///   - maxValue: Maximum pixel value in original data (for histogram range)
    ///   - imageMinValue: Full image minimum value (for converting normalized texture, defaults to minValue)
    ///   - imageMaxValue: Full image maximum value (for converting normalized texture, defaults to maxValue)
    /// - Returns: Histogram data
    public func computeHistogram(from texture: MTLTexture, numBins: Int = 256, minValue: Float = 0.0, maxValue: Float = 1.0, imageMinValue: Float? = nil, imageMaxValue: Float? = nil) throws -> Histogram {
        guard numBins > 0 else {
            throw HistogramError.invalidNumBins
        }
        
        // Create histogram buffer (initialized to zeros)
        let histogramBufferSize = numBins * MemoryLayout<UInt32>.size
        guard let histogramBuffer = device.makeBuffer(length: histogramBufferSize, options: [.storageModeShared]) else {
            throw HistogramError.couldNotCreateBuffer
        }
        
        // Zero out the buffer
        let histogramPointer = histogramBuffer.contents().bindMemory(to: UInt32.self, capacity: numBins)
        memset(histogramPointer, 0, histogramBufferSize)
        
        // Create buffer for numBins parameter
        var numBinsValue = UInt32(numBins)
        guard let numBinsBuffer = device.makeBuffer(bytes: &numBinsValue, length: MemoryLayout<UInt32>.size, options: []) else {
            throw HistogramError.couldNotCreateBuffer
        }
        
        // Create buffers for image min/max values (for converting normalized texture values)
        let actualImageMin = imageMinValue ?? minValue
        let actualImageMax = imageMaxValue ?? maxValue
        var imageMinValueFloat = Float(actualImageMin)
        var imageMaxValueFloat = Float(actualImageMax)
        guard let imageMinValueBuffer = device.makeBuffer(bytes: &imageMinValueFloat, length: MemoryLayout<Float>.size, options: []),
              let imageMaxValueBuffer = device.makeBuffer(bytes: &imageMaxValueFloat, length: MemoryLayout<Float>.size, options: []) else {
            throw HistogramError.couldNotCreateBuffer
        }
        
        // Create buffers for histogram min/max values (the range we want to bin)
        var histogramMinValueFloat = Float(minValue)
        var histogramMaxValueFloat = Float(maxValue)
        Logger.computers.debug("Metal shader params: imageRange=[\(imageMinValueFloat), \(imageMaxValueFloat)], histogramRange=[\(histogramMinValueFloat), \(histogramMaxValueFloat)], numBins=\(numBins)")
        guard let histogramMinValueBuffer = device.makeBuffer(bytes: &histogramMinValueFloat, length: MemoryLayout<Float>.size, options: []),
              let histogramMaxValueBuffer = device.makeBuffer(bytes: &histogramMaxValueFloat, length: MemoryLayout<Float>.size, options: []) else {
            throw HistogramError.couldNotCreateBuffer
        }
        
        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw HistogramError.couldNotCreateCommandBuffer
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HistogramError.couldNotCreateComputeEncoder
        }
        
        // Set up compute pipeline
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setBuffer(histogramBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(numBinsBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(imageMinValueBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(imageMaxValueBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(histogramMinValueBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(histogramMaxValueBuffer, offset: 0, index: 5)
        
        // Calculate threadgroup size
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        // Dispatch compute
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Check for errors
        if let error = commandBuffer.error {
            throw HistogramError.computeError(error)
        }
        
        // Read back histogram data
        let binCounts = Array(UnsafeBufferPointer(start: histogramPointer, count: numBins))
        
        // Debug: Print histogram statistics
        let totalCount = binCounts.reduce(0, +)
        let nonZeroBins = binCounts.filter { $0 > 0 }.count
        Logger.computers.debug("Metal histogram result: totalCount=\(totalCount), nonZeroBins=\(nonZeroBins), first 10 bins: \(Array(binCounts.prefix(10)))")
        
        // Debug: Print all non-zero bins with their pixel values
        if nonZeroBins < 50 {
            Logger.computers.debug("All non-zero bins:")
            for (index, count) in binCounts.enumerated() where count > 0 {
                let normalizedBinCenter = (Float(index) + 0.5) / Float(numBins)
                let pixelValue = Float(minValue) + normalizedBinCenter * (Float(maxValue) - Float(minValue))
                Logger.computers.debug("Bin \(index): count=\(count), pixelValue≈\(pixelValue)")
            }
        }
        
        return Histogram(
            numBins: numBins,
            binCounts: binCounts,
            minValue: Float(minValue),
            maxValue: Float(maxValue)
        )
    }
}

/// Errors that can occur during histogram computation
public enum HistogramError: LocalizedError {
    case metalNotSupported
    case couldNotCreateCommandQueue
    case couldNotLoadShaderLibrary
    case couldNotLoadComputeFunction
    case couldNotCreatePipelineState(Error)
    case invalidNumBins
    case couldNotCreateBuffer
    case couldNotCreateCommandBuffer
    case couldNotCreateComputeEncoder
    case computeError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .metalNotSupported:
            return "Metal is not supported on this device"
        case .couldNotCreateCommandQueue:
            return "Could not create Metal command queue"
        case .couldNotLoadShaderLibrary:
            return "Could not load Metal shader library"
        case .couldNotLoadComputeFunction:
            return "Could not load histogram compute function"
        case .couldNotCreatePipelineState(let error):
            return "Could not create compute pipeline state: \(error.localizedDescription)"
        case .invalidNumBins:
            return "Invalid number of bins (must be greater than 0)"
        case .couldNotCreateBuffer:
            return "Could not create Metal buffer"
        case .couldNotCreateCommandBuffer:
            return "Could not create Metal command buffer"
        case .couldNotCreateComputeEncoder:
            return "Could not create Metal compute encoder"
        case .computeError(let error):
            return "Compute shader error: \(error.localizedDescription)"
        }
    }
}


import Foundation
import Metal
import os

/// Processor for converting frames to grayscale
public struct GrayscaleProcessor: Processor {

    public init() {}

    /// Execute the grayscale processor
    /// - Parameters:
    ///   - inputs: Dictionary containing "input_frame" -> Frame
    ///   - parameters: Dictionary (empty for this processor)
    ///   - device: Metal device for GPU operations
    ///   - commandQueue: Metal command queue for GPU operations
    /// - Returns: Dictionary containing "grayscale_frame" -> Frame
    /// - Throws: ProcessorExecutionError if execution fails
    public func execute(
        inputs: [String: Any],
        parameters: [String: Parameter],
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) throws -> [String: Any] {

        // Get input frame
        guard let inputFrame = inputs["input_frame"] as? Frame else {
            throw ProcessorExecutionError.missingRequiredInput("input_frame")
        }

        guard let inputTexture = inputFrame.texture else {
            throw ProcessorExecutionError.executionFailed("Input frame texture is not available")
        }

        Logger.processor.debug(
            "Converting frame to grayscale (width: \(inputTexture.width), height: \(inputTexture.height))"
        )

        // Load shader library
        guard let library = AstrophotoKit.makeShaderLibrary(device: device) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not load Metal shader library")
        }

        // Load compute function
        guard let grayscaleFunction = library.makeFunction(name: "grayscale") else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not load grayscale shader function")
        }

        // Create compute pipeline state
        let computePipelineState: MTLComputePipelineState
        do {
            computePipelineState = try device.makeComputePipelineState(function: grayscaleFunction)
        } catch {
            throw ProcessorExecutionError.couldNotCreateResource(
                "Could not create compute pipeline state: \(error.localizedDescription)"
            )
        }

        // Create output texture (grayscale format: r32Float)
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: outputDescriptor) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create output texture")
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create command buffer")
        }

        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create compute encoder")
        }

        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)

        // Calculate threadgroup size
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (inputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (inputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()

        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Check for errors
        if let error = commandBuffer.error {
            throw ProcessorExecutionError.executionFailed("GPU compute error: \(error.localizedDescription)")
        }

        // Create output frame with the grayscale texture
        // Update color space to grayscale
        // Use input dataType or default to float if not available
        let outputDataType = inputFrame.dataType ?? .float
        let outputFrame = Frame(
            type: inputFrame.type,
            filter: inputFrame.filter,
            colorSpace: .greyscale,  // Explicitly set to grayscale
            dataType: outputDataType,
            texture: outputTexture,
            outputProcess: nil,  // Will be set by pipeline runner
            inputProcesses: []
        )

        Logger.processor.debug("Grayscale conversion completed successfully")

        return ["grayscale_frame": outputFrame]
    }
}

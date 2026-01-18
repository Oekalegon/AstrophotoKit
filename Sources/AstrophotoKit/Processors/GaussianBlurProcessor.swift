import Foundation
import Metal
import os

/// Processor for applying Gaussian blur to frames
public struct GaussianBlurProcessor: Processor {

    public init() {}

    /// Execute the Gaussian blur processor
    /// - Parameters:
    ///   - inputs: Dictionary containing "input_frame" -> Frame
    ///   - parameters: Dictionary containing "radius" -> Parameter (Double, default: 3.0)
    ///   - device: Metal device for GPU operations
    ///   - commandQueue: Metal command queue for GPU operations
    /// - Returns: Dictionary containing "blurred_frame" -> Frame
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

        // Get radius parameter (default: 3.0)
        let radius: Float
        if let radiusParam = parameters["radius"] {
            if let doubleValue = radiusParam.doubleValue {
                radius = Float(doubleValue)
            } else {
                throw ProcessorExecutionError.executionFailed("Radius parameter must be a number")
            }
        } else {
            radius = 3.0  // Default from YAML
        }

        Logger.processor.debug("Applying Gaussian blur with radius: \(radius)")

        // Load shader library
        guard let library = AstrophotoKit.makeShaderLibrary(device: device) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not load Metal shader library")
        }

        // Load compute functions
        guard let horizontalFunction = library.makeFunction(name: "gaussian_blur_horizontal"),
              let verticalFunction = library.makeFunction(name: "gaussian_blur_vertical") else {
            throw ProcessorExecutionError.couldNotCreateResource(
                "Could not load Gaussian blur shader functions"
            )
        }

        // Create compute pipeline states
        let horizontalPipelineState: MTLComputePipelineState
        let verticalPipelineState: MTLComputePipelineState

        do {
            horizontalPipelineState = try device.makeComputePipelineState(function: horizontalFunction)
            verticalPipelineState = try device.makeComputePipelineState(function: verticalFunction)
        } catch {
            throw ProcessorExecutionError.couldNotCreateResource(
                "Could not create compute pipeline states: \(error.localizedDescription)"
            )
        }

        // Create intermediate texture for horizontal pass
        let intermediateDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        intermediateDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let intermediateTexture = device.makeTexture(descriptor: intermediateDescriptor) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create intermediate texture")
        }

        // Create output texture
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: outputDescriptor) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create output texture")
        }

        // Create buffer for radius parameter
        var radiusValue = radius
        guard let radiusBuffer = device.makeBuffer(
            bytes: &radiusValue,
            length: MemoryLayout<Float>.size,
            options: []
        ) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create radius buffer")
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create command buffer")
        }

        // Pass 1: Horizontal blur (input -> intermediate)
        guard let horizontalEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create compute encoder")
        }

        horizontalEncoder.setComputePipelineState(horizontalPipelineState)
        horizontalEncoder.setTexture(inputTexture, index: 0)
        horizontalEncoder.setTexture(intermediateTexture, index: 1)
        horizontalEncoder.setBuffer(radiusBuffer, offset: 0, index: 0)

        // Calculate threadgroup size
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (inputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (inputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        horizontalEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        horizontalEncoder.endEncoding()

        // Pass 2: Vertical blur (intermediate -> output)
        guard let verticalEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ProcessorExecutionError.couldNotCreateResource(
                "Could not create compute encoder for vertical pass"
            )
        }

        verticalEncoder.setComputePipelineState(verticalPipelineState)
        verticalEncoder.setTexture(intermediateTexture, index: 0)
        verticalEncoder.setTexture(outputTexture, index: 1)
        verticalEncoder.setBuffer(radiusBuffer, offset: 0, index: 0)

        verticalEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        verticalEncoder.endEncoding()

        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Check for errors
        if let error = commandBuffer.error {
            throw ProcessorExecutionError.executionFailed("GPU compute error: \(error.localizedDescription)")
        }

        // Create output frame with the blurred texture
        // Copy metadata from input frame but update processing stage
        var outputFrame = Frame(
            type: inputFrame.type,
            filter: inputFrame.filter,
            colorSpace: inputFrame.colorSpace,
            dataType: inputFrame.dataType ?? .float,
            texture: outputTexture,
            outputProcess: nil,  // Will be set by pipeline runner
            inputProcesses: []
        )

        Logger.processor.debug("Gaussian blur completed successfully")

        return ["blurred_frame": outputFrame]
    }
}


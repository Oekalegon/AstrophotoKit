import Foundation
import Metal
import os
import TabularData

/// Processor for estimating and subtracting background from frames
public struct BackgroundEstimationProcessor: Processor {

    public var id: String { "background_estimation" }

    public init() {}

    /// Execute the background estimation processor
    /// - Parameters:
    ///   - inputs: Dictionary containing "input_frame" -> ProcessData (Frame)
    ///   - outputs: Dictionary containing:
    ///     - "background_frame" -> ProcessData (Frame, to be instantiated)
    ///     - "background_subtracted_frame" -> ProcessData (Frame, to be instantiated)
    ///     - "background_level" -> ProcessData (Table, to be instantiated)
    ///   - parameters: Dictionary (empty for this processor)
    ///   - device: Metal device for GPU operations
    ///   - commandQueue: Metal command queue for GPU operations
    /// - Throws: ProcessorExecutionError if execution fails
    public func execute(
        inputs: [String: ProcessData],
        outputs: inout [String: ProcessData],
        parameters: [String: Parameter],
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) throws {
        // Validate input frame
        let (_, inputTexture) = try ProcessorHelpers.validateInputFrame(from: inputs)

        Logger.processor.debug(
            "Estimating background (width: \(inputTexture.width), height: \(inputTexture.height))"
        )

        // Default window size for local median estimation
        let windowSize: Int32 = 50

        // Load shader library and functions
        let library = try ProcessorHelpers.loadShaderLibrary(device: device)
        guard let localMedianFunction = library.makeFunction(name: "local_median"),
              let localMedianSubtractFunction = library.makeFunction(name: "local_median_subtract") else {
            throw ProcessorExecutionError.couldNotCreateResource(
                "Could not load background estimation shader functions"
            )
        }

        // Create compute pipeline states
        let localMedianPipelineState = try ProcessorHelpers.createComputePipelineState(
            function: localMedianFunction,
            device: device
        )
        let localMedianSubtractPipelineState = try ProcessorHelpers.createComputePipelineState(
            function: localMedianSubtractFunction,
            device: device
        )

        // Image value range (assuming normalized [0, 1] for now)
        let imageMinValue: Float = 0.0
        let imageMaxValue: Float = 1.0

        // Create textures
        let backgroundDescriptor = ProcessorHelpers.createTextureDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height
        )
        let backgroundTexture = try ProcessorHelpers.createTexture(
            descriptor: backgroundDescriptor,
            device: device
        )

        let subtractedDescriptor = ProcessorHelpers.createTextureDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height
        )
        let subtractedTexture = try ProcessorHelpers.createTexture(
            descriptor: subtractedDescriptor,
            device: device
        )

        // Create parameter buffers
        var windowSizeInt = windowSize
        var minValue = imageMinValue
        var maxValue = imageMaxValue

        let windowSizeBuffer = try ProcessorHelpers.createBuffer(from: &windowSizeInt, device: device)
        let minValueBuffer = try ProcessorHelpers.createBuffer(from: &minValue, device: device)
        let maxValueBuffer = try ProcessorHelpers.createBuffer(from: &maxValue, device: device)

        // Create command buffer
        let commandBuffer = try ProcessorHelpers.createCommandBuffer(commandQueue: commandQueue)

        // Calculate threadgroups
        let (threadgroupSize, threadgroupsPerGrid) = ProcessorHelpers.calculateThreadgroups(for: inputTexture)

        // Step 1: Estimate local median background
        let encoder1 = try ProcessorHelpers.createComputeEncoder(commandBuffer: commandBuffer)
        encoder1.setComputePipelineState(localMedianPipelineState)
        encoder1.setTexture(inputTexture, index: 0)
        encoder1.setTexture(backgroundTexture, index: 1)
        encoder1.setBuffer(windowSizeBuffer, offset: 0, index: 0)
        encoder1.setBuffer(minValueBuffer, offset: 0, index: 1)
        encoder1.setBuffer(maxValueBuffer, offset: 0, index: 2)
        encoder1.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        encoder1.endEncoding()

        // Step 2: Subtract background from input
        let encoder2 = try ProcessorHelpers.createComputeEncoder(commandBuffer: commandBuffer)
        encoder2.setComputePipelineState(localMedianSubtractPipelineState)
        encoder2.setTexture(inputTexture, index: 0)
        encoder2.setTexture(backgroundTexture, index: 1)
        encoder2.setTexture(subtractedTexture, index: 2)
        encoder2.setBuffer(minValueBuffer, offset: 0, index: 0)
        encoder2.setBuffer(maxValueBuffer, offset: 0, index: 1)
        encoder2.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
        encoder2.endEncoding()

        // Execute command buffer
        try ProcessorHelpers.executeCommandBuffer(commandBuffer)

        // Calculate average background level for table output
        let backgroundLevel = try calculateAverageBackgroundLevel(
            texture: backgroundTexture,
            device: device,
            commandQueue: commandQueue
        )

        // Update output frames
        try ProcessorHelpers.updateOutputFrame(
            outputs: &outputs,
            outputName: "background_frame",
            texture: backgroundTexture
        )

        try ProcessorHelpers.updateOutputFrame(
            outputs: &outputs,
            outputName: "background_subtracted_frame",
            texture: subtractedTexture
        )

        // Create table with background level
        if var backgroundLevelTable = outputs["background_level"] as? Table {
            // Create DataFrame with single row and column
            var dataFrame = DataFrame()
            dataFrame.append(column: Column(name: "background_level", contents: [backgroundLevel]))
            backgroundLevelTable.dataFrame = dataFrame
            outputs["background_level"] = backgroundLevelTable
        }

        Logger.processor.info("Background estimation completed (level: \(backgroundLevel))")
    }

    /// Calculate average background level from background texture
    /// - Parameters:
    ///   - texture: The background texture
    ///   - device: Metal device
    ///   - commandQueue: Metal command queue
    /// - Returns: Average background level
    /// - Throws: ProcessorExecutionError if calculation fails
    private func calculateAverageBackgroundLevel(
        texture: MTLTexture,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) throws -> Double {
        // Sample a subset of pixels for performance (every 10th pixel)
        let sampleRate = 10
        let width = texture.width
        let height = texture.height
        let sampleWidth = max(1, width / sampleRate)
        let sampleHeight = max(1, height / sampleRate)
        let bytesPerRow = sampleWidth * MemoryLayout<Float32>.size
        let bufferSize = bytesPerRow * sampleHeight

        guard let readBuffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create read buffer")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create command buffer")
        }

        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw ProcessorExecutionError.couldNotCreateResource("Could not create blit encoder")
        }

        blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: sampleWidth, height: sampleHeight, depth: 1),
            to: readBuffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: bufferSize
        )
        blitEncoder.endEncoding()

        try ProcessorHelpers.executeCommandBuffer(commandBuffer)

        // Calculate average from sample
        let pixelPointer = readBuffer.contents().bindMemory(to: Float32.self, capacity: sampleWidth * sampleHeight)
        let pixels = Array(UnsafeBufferPointer(start: pixelPointer, count: sampleWidth * sampleHeight))
        let average = pixels.reduce(0.0, +) / Float(pixels.count)

        return Double(average)
    }
}


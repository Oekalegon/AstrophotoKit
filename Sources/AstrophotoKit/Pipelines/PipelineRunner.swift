import Foundation
import Metal
import os

/// The runner for a pipeline.
/// 
/// The runner is responsible for executing the pipeline.
/// It is responsible for tracking the data that is available for the pipeline
/// and the processes that are currently running in the pipeline.
public actor PipelineRunner {

    /// The pipeline to execute.
    /// 
    /// The pipeline is the pipeline to execute.
    private let pipeline: Pipeline

    /// The data stack for the pipeline.
    /// 
    /// The data stack is used to track the data that is available for the pipeline.
    public let dataStack: DataStack

    /// The process stack for the pipeline.
    public let processStack: ProcessStack

    /// Initialize the pipeline runner with a pipeline.
    /// - Parameter pipeline: The pipeline to execute.
    public init(pipeline: Pipeline) {
        self.pipeline = pipeline
        self.dataStack = DataStack()
        self.processStack = ProcessStack()
    }

    /// Execute this pipeline asynchronously with parallel execution when dependencies allow
    /// Uses a data-driven execution model: tracks available data and checks pending step instances
    /// when new data becomes available. Each step execution gets a unique instance ID.
    /// - Parameters:
    ///   - inputs: Dictionary of pipeline input name to input data
    ///   - parameters: Dictionary of parameter name to parameter value
    ///   - device: Metal device for GPU operations
    ///   - commandQueue: Metal command queue for GPU operations
    ///   - registry: Processor registry to look up processors (defaults to shared registry)
    /// - Returns: Dictionary of output name to output data (from all step outputs)
    /// - Throws: ProcessorExecutionError or PipelineConfigurationError if execution fails
    public func execute(
        inputs: [String: Any],
        parameters: [String: Parameter] = [:],
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        registry: ProcessorRegistry = .shared
    ) async throws -> [String: Any] {

        // This represents the initial process
        let initialProcess = Process(
            stepIdentifier: "initial",
            processorIdentifier: "initial"
        )

        // Create the initial input data for the pipeline.
        try await self.createInitialInputData(
            from: inputs,
            device: device,
            initialProcess: initialProcess,
            dataStack: dataStack,
        )

        // Create the pipeline processes.
        for step in pipeline.steps {
            let process = Process(step: step)
            await processStack.add(process: process)

            // TODO: Create multiple processes for collections.

            // Go through all the input links and set the correct input link for the ProcessData that is
            // identified by the input link.
            for inputLink in process.inputData {
                if case .input(let processId, let linkName, let type, let collectionMode, let stepLinkID) = inputLink {
                    guard var processData = await dataStack.get(by: .input(process: processId, link: linkName, type: type, collectionMode: collectionMode, stepLinkID: stepLinkID)) else {
                        continue
                    }
                    processData.addInputLink(process: process.identifier, link: linkName, collectionMode: collectionMode)
                    _ = await dataStack.update(data: processData)
                }
            }   

            // For each output link of the process, create the output data and add it to the data stack.
            for outputLink in process.outputData {
                if case .output(_, _, let type, _) = outputLink {
                    if let outputData = try self.createOutputData(
                        type: type,
                        outputLink: outputLink
                    ) {
                        await dataStack.add(data: outputData)
                    }
                }
            }
        }
        return [:]
    }   

    private func createInitialInputData(
        from inputs: [String: Any],
        device: MTLDevice,
        initialProcess: Process,
        dataStack: DataStack,
    ) async throws {
        // Create the initial input data for the pipeline.
        Logger.pipeline.debug("Creating initial input data for the pipeline")
        for (key, value) in inputs {
            // Infer data type from the input value
            let dataType: DataType
            if value is Frame {
                dataType = .frame
            } else if value is FrameSet {
                dataType = .frameSet
            } else if value is FITSImage {
                dataType = .frame // FITSImage becomes a Frame
            } else {
                Logger.pipeline.error("Cannot infer data type for input: \(type(of: value))")
                fatalError("Cannot infer data type for input: \(type(of: value))")
            }
            
            // For initial input data, stepLinkID follows the pattern "initial.input_name"
            let stepLinkID = "initial.\(key)"
            let inputData = try self.createInputData(
                from: value,
                device: device,
                outputProcess: .output(process: initialProcess.identifier, link: key, type: dataType, stepLinkID: stepLinkID),
            )
            Logger.pipeline.debug("Created input data \(inputData.identifier)")
            await dataStack.add(data: inputData)
        }
    }

    private func createInputData(
        from input: Any,
        device: MTLDevice,
        outputProcess: ProcessDataLink,
    ) throws -> ProcessData {
        if var frame = input as? Frame {
            Logger.pipeline.debug("Creating frame input data")
            frame.outputLink = outputProcess
            return frame
        } else if var frameSet = input as? FrameSet {
            Logger.pipeline.debug("Creating frame set input data")
            frameSet.outputLink = outputProcess
            return frameSet
        } else if let fitsImage = input as? FITSImage {
            Logger.pipeline.debug("Creating FITS image input data")
            return try Frame(
                fitsImage: fitsImage,
                device: device,
                outputProcess: outputProcess,
                inputProcesses: []
            )
        } else {
            Logger.pipeline.error("Unsupported input type: \(type(of: input))")
            fatalError("Unsupported input type: \(type(of: input))")
        }
    }

    private func createOutputData(
        type: DataType,
        outputLink: ProcessDataLink
    ) throws -> ProcessData? { // TODO: Should never be nil when all types are supported.
        switch type {
        case .frame:
            Logger.pipeline.debug("Creating frame output data placeholder")
            // Create a placeholder Frame without texture (not instantiated yet)
            return Frame(
                type: .light, // Default, will be updated when process executes
                filter: .none,
                colorSpace: .greyscale, // Default, will be updated when process executes
                dataType: .float, // Default, will be updated when process executes
                texture: nil, // Not instantiated yet
                outputProcess: outputLink,
                inputProcesses: []
            )
        case .frameSet:
            Logger.pipeline.debug("Creating frame set output data placeholder")
            // Create a placeholder FrameSet (empty collection)
            // Extract process ID, link name, and stepLinkID from outputLink
            if case .output(let processId, let linkName, _, let stepLinkID) = outputLink {
                return FrameSet(
                    frames: [],
                    outputProcess: (id: processId, name: linkName, stepLinkID: stepLinkID),
                    inputProcesses: []
                )
            } else {
                fatalError("Output link must be an output case")
            }
        case .table:
            Logger.pipeline.error("Table output data creation not yet implemented")
            return nil
        }
    }
}
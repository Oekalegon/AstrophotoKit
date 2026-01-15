import Foundation
import Metal

/// Pipeline step loaded from YAML configuration
public struct PipelineStep: Codable {
    /// Unique identifier for this step instance
    public let id: String

    /// The step type/class identifier (e.g., "gaussian_blur", "threshold")
    public let type: String

    /// Human-readable name
    public let name: String?

    /// Description
    public let description: String?

    /// Data inputs: data (frames, tables, etc.) that this step acts upon
    public let dataInputs: [DataInput]

    /// Parameters: configuration values that can be adjusted between runs
    public let parameters: [ParameterSpec]

    /// Outputs: outputs that this step produces
    public let outputs: [DataOutput]

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case description
        case dataInputs
        case parameters
        case outputs
    }

    public init(
        id: String,
        type: String,
        name: String? = nil,
        description: String? = nil,
        dataInputs: [DataInput] = [],
        parameters: [ParameterSpec] = [],
        outputs: [DataOutput] = []
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.dataInputs = dataInputs
        self.parameters = parameters
        self.outputs = outputs
    }

    /// Execute this step with resolved inputs and parameters
    /// - Parameters:
    ///   - resolvedInputs: Dictionary mapping data input names to their resolved data
    ///   - resolvedParameters: Dictionary mapping parameter names to their resolved values
    ///   - device: Metal device for GPU operations (can be ignored for CPU-only processors)
    ///   - commandQueue: Metal command queue for GPU operations (can be ignored for CPU-only processors)
    ///   - registry: Step registry to look up processors (defaults to shared registry)
    /// - Returns: Dictionary of output name to output data
    /// - Throws: ProcessorExecutionError if execution fails
    /// - Note: CPU-only processors can ignore the `device` and `commandQueue` parameters
    public func execute(
        resolvedInputs: [String: Any],
        resolvedParameters: [String: Parameter],
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        registry: ProcessorRegistry = .shared
    ) throws -> [String: Any] {
        // Look up the processor
        guard let processor = registry.get(type: type) else {
            throw ProcessorExecutionError.processorNotFound(type)
        }

        // Validate required inputs
        for dataInput in dataInputs where resolvedInputs[dataInput.name] == nil {
            throw ProcessorExecutionError.missingRequiredInput(dataInput.name)
        }

        // Execute the processor
        return try processor.execute(
            inputs: resolvedInputs,
            parameters: resolvedParameters,
            device: device,
            commandQueue: commandQueue
        )
    }
}

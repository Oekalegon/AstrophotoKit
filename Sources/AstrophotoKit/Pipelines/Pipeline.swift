import Foundation
import Yams
import Metal

/// Pipeline loaded from YAML configuration
public struct Pipeline: Codable {
    /// Unique identifier for this pipeline
    public let id: String

    /// Human-readable name
    public let name: String

    /// Description
    public let description: String?

    /// The steps in this pipeline
    public let steps: [PipelineStep]

    /// Load a pipeline from a YAML file
    public static func load(from url: URL) throws -> Pipeline {
        let data = try Data(contentsOf: url)
        return try parseYAML(from: data)
    }

    /// Load a pipeline from a YAML string
    public static func load(from yamlString: String) throws -> Pipeline {
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(Pipeline.self, from: yamlString)
        } catch {
            throw PipelineConfigurationError.invalidFormat("YAML parsing failed: \(error.localizedDescription)")
        }
    }

    /// Parse a YAML configuration from data
    private static func parseYAML(from data: Data) throws -> Pipeline {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw PipelineConfigurationError.invalidEncoding
        }

        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(Pipeline.self, from: yamlString)
        } catch let decodingError as DecodingError {
            var errorDescription = "YAML parsing failed: "
            switch decodingError {
            case .typeMismatch(let type, let context):
                errorDescription += "Type mismatch for type \(type) at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                errorDescription += "Value not found for type \(type) at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                errorDescription += "Key '\(key.stringValue)' not found at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            case .dataCorrupted(let context):
                errorDescription += "Data corrupted at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
            @unknown default:
                errorDescription += decodingError.localizedDescription
            }
            throw PipelineConfigurationError.invalidFormat(errorDescription)
        } catch {
            throw PipelineConfigurationError.invalidFormat("YAML parsing failed: \(error.localizedDescription)")
        }
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        steps: [PipelineStep]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
    }

    /// Execute this pipeline with the given inputs and parameters
    /// - Parameters:
    ///   - inputs: Dictionary of pipeline input name to input data
    ///   - parameters: Dictionary of parameter name to parameter value (optional, can be provided per-step)
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
    ) throws -> [String: Any] {
        // Track available data throughout execution (pipeline inputs + step outputs)
        var availableData: [String: Any] = inputs

        // Execute each step in order
        for step in steps {
            // Resolve data inputs for this step
            var resolvedInputs: [String: Any] = [:]
            for dataInput in step.dataInputs {
                // Parse the "from" field: "step_id.output_name" or "input_name"
                let fromParts = dataInput.from.split(separator: ".", maxSplits: 1)
                let sourceData: Any?

                if fromParts.count == 2 {
                    // Step output: "step_id.output_name"
                    let stepId = String(fromParts[0])
                    let outputName = String(fromParts[1])
                    let key = "\(stepId).\(outputName)"
                    sourceData = availableData[key]
                } else {
                    // Pipeline input: "input_name"
                    let inputName = String(fromParts[0])
                    sourceData = availableData[inputName]
                }

                guard let data = sourceData else {
                    throw ProcessorExecutionError.missingRequiredInput(dataInput.name)
                }

                resolvedInputs[dataInput.name] = data
            }

            // Resolve parameters for this step
            var resolvedParameters: [String: Parameter] = [:]
            for parameterSpec in step.parameters {
                let parameterValue: Parameter?

                if let from = parameterSpec.from {
                    // Parameter from pipeline inputs
                    if let param = parameters[from] {
                        parameterValue = param
                    } else if let defaultValue = parameterSpec.defaultValue {
                        parameterValue = defaultValue
                    } else {
                        parameterValue = nil
                    }
                } else if let defaultValue = parameterSpec.defaultValue {
                    // Use default value
                    parameterValue = defaultValue
                } else {
                    parameterValue = nil
                }

                if let value = parameterValue {
                    resolvedParameters[parameterSpec.name] = value
                }
            }

            // Execute the step
            let stepOutputs = try step.execute(
                resolvedInputs: resolvedInputs,
                resolvedParameters: resolvedParameters,
                device: device,
                commandQueue: commandQueue,
                registry: registry
            )

            // Add step outputs to available data (keyed as "step_id.output_name")
            for (outputName, outputData) in stepOutputs {
                let key = "\(step.id).\(outputName)"
                availableData[key] = outputData
                // Also make available by output name alone for convenience
                availableData[outputName] = outputData
            }
        }

        // Return all available data (includes both intermediate and final outputs)
        return availableData
    }
}


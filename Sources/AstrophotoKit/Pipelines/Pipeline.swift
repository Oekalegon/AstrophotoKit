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
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Type mismatch for type \(type) at path \(path): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Value not found for type \(type) at path \(path): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Key '\(key.stringValue)' not found at path \(path): \(context.debugDescription)"
            case .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Data corrupted at path \(path): \(context.debugDescription)"
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
        // Track available data (pipeline inputs + step outputs)
        // Use actor for async-safe synchronization
    }
}

internal actor OutputDataStack {
    private var data: [ProcessData] = []
}
    
internal actor ProcessorStepStack {
    private var processors: [ProcessorInstance] = []


}


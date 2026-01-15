import Foundation

/// Registry for processors
public class ProcessorRegistry {
    private var implementations: [String: Processor] = [:]
    public static let shared = ProcessorRegistry()

    private init() {}

    /// Register a processor
    /// - Parameters:
    ///   - type: The step type identifier (e.g., "gaussian_blur")
    ///   - implementation: The processor implementation
    public func register(type: String, implementation: Processor) {
        implementations[type] = implementation
    }

    /// Get a processor by type
    /// - Parameter type: The step type identifier
    /// - Returns: The processor, or nil if not found
    public func get(type: String) -> Processor? {
        return implementations[type]
    }
}


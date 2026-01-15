import Foundation
import Metal

/// Protocol that processors must conform to
public protocol Processor {
    /// Execute this processor with the given inputs and parameters
    /// - Parameters:
    ///   - inputs: Dictionary of input name to data (type to be defined)
    ///   - parameters: Dictionary of parameter name to parameter value
    ///   - device: Metal device for GPU operations (can be ignored for CPU-only processors)
    ///   - commandQueue: Metal command queue for GPU operations (can be ignored for CPU-only processors)
    ///   - Returns: Dictionary of output name to data
    /// - Throws: ProcessorExecutionError if execution fails
    /// - Note: CPU-only processors can ignore the `device` and `commandQueue` parameters
    func execute(
        inputs: [String: Any],
        parameters: [String: Parameter],
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) throws -> [String: Any]
}

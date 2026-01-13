import Foundation

/// Represents a processed scalar value with metadata about its processing history
public class ProcessedScalar: ProcessedData {
    /// The scalar value
    public let value: Float
    
    /// The processing steps that have been applied to create this scalar
    public let processingHistory: [ProcessingStep]
    
    /// A unique identifier for this processed scalar
    public let id: String
    
    /// Human-readable name/description
    public let name: String
    
    /// Optional unit for the scalar value (e.g., "pixels", "ADU", "count")
    public let unit: String?
    
    public init(
        value: Float,
        processingHistory: [ProcessingStep] = [],
        id: String = UUID().uuidString,
        name: String = "Processed Scalar",
        unit: String? = nil
    ) {
        self.value = value
        self.processingHistory = processingHistory
        self.id = id
        self.name = name
        self.unit = unit
    }
    
    /// Creates a new ProcessedScalar by applying a processing step
    public func withProcessingStep(
        stepID: String,
        stepName: String,
        parameters: [String: String] = [:],
        newValue: Float,
        newName: String? = nil,
        newUnit: String? = nil
    ) -> ProcessedScalar {
        let nextOrder = processingHistory.count
        let newStep = ProcessingStep(
            stepID: stepID,
            stepName: stepName,
            parameters: parameters,
            order: nextOrder
        )
        
        return ProcessedScalar(
            value: newValue,
            processingHistory: processingHistory + [newStep],
            id: UUID().uuidString,
            name: newName ?? "\(name) + \(stepName)",
            unit: newUnit ?? unit
        )
    }
    
    /// Checks if this scalar has been processed with a specific step and parameters
    public func hasProcessingStep(stepID: String, parameters: [String: String]? = nil) -> Bool {
        if let params = parameters {
            return processingHistory.contains { step in
                step.stepID == stepID && step.parameters == params
            }
        } else {
            return processingHistory.contains { $0.stepID == stepID }
        }
    }
    
    /// Gets the most recent processing step of a specific type
    public func getProcessingStep(stepID: String) -> ProcessingStep? {
        return processingHistory.last { $0.stepID == stepID }
    }
}


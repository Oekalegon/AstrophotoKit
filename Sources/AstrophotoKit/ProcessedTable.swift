import Foundation

/// Represents a processed table with metadata about its processing history
public class ProcessedTable {
    /// The table data
    public let data: [String: Any]
    
    /// The processing steps that have been applied to create this table
    public let processingHistory: [ProcessingStep]
    
    /// A unique identifier for this processed table
    public let id: String
    
    /// Human-readable name/description
    public let name: String
    
    public init(
        data: [String: Any],
        processingHistory: [ProcessingStep] = [],
        id: String = UUID().uuidString,
        name: String = "Processed Table"
    ) {
        self.data = data
        self.processingHistory = processingHistory
        self.id = id
        self.name = name
    }
    
    /// Creates a new ProcessedTable by applying a processing step
    public func withProcessingStep(
        stepID: String,
        stepName: String,
        parameters: [String: String] = [:],
        newData: [String: Any],
        newName: String? = nil
    ) -> ProcessedTable {
        let nextOrder = processingHistory.count
        let newStep = ProcessingStep(
            stepID: stepID,
            stepName: stepName,
            parameters: parameters,
            order: nextOrder
        )
        
        return ProcessedTable(
            data: newData,
            processingHistory: processingHistory + [newStep],
            id: UUID().uuidString,
            name: newName ?? "\(name) + \(stepName)"
        )
    }
    
    /// Checks if this table has been processed with a specific step and parameters
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


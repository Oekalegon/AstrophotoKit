import Foundation
import Metal

/// Protocol for any processed data that tracks processing history
public protocol ProcessedData: AnyObject {
    /// The processing steps that have been applied
    var processingHistory: [ProcessingStep] { get }
    
    /// A unique identifier
    var id: String { get }
    
    /// Human-readable name/description
    var name: String { get }
}

/// Generic container for processed data that can hold single or multiple items
/// Supports images, tables, or combinations
public class ProcessedDataContainer: ProcessedData {
    /// Single processed image (if this is a single image)
    public let image: ProcessedImage?
    
    /// Multiple processed images (if this is a set of images)
    public let images: [ProcessedImage]?
    
    /// Single processed table (if this is a single table)
    public let table: ProcessedTable?
    
    /// Multiple processed tables (if this is a set of tables)
    public let tables: [ProcessedTable]?
    
    /// The processing steps that have been applied
    public let processingHistory: [ProcessingStep]
    
    /// A unique identifier
    public let id: String
    
    /// Human-readable name/description
    public let name: String
    
    /// The type of data this container holds
    public enum DataType {
        case singleImage
        case multipleImages
        case singleTable
        case multipleTables
        case mixed // Combination of images and tables
    }
    
    /// The type of data in this container
    public var dataType: DataType {
        if image != nil && images == nil && table == nil && tables == nil {
            return .singleImage
        } else if images != nil && image == nil && table == nil && tables == nil {
            return .multipleImages
        } else if table != nil && image == nil && images == nil && tables == nil {
            return .singleTable
        } else if tables != nil && image == nil && images == nil && table == nil {
            return .multipleTables
        } else {
            return .mixed
        }
    }
    
    /// Initialize with a single image
    public init(image: ProcessedImage, processingHistory: [ProcessingStep]? = nil) {
        self.image = image
        self.images = nil
        self.table = nil
        self.tables = nil
        self.processingHistory = processingHistory ?? image.processingHistory
        self.id = image.id
        self.name = image.name
    }
    
    /// Initialize with multiple images
    public init(images: [ProcessedImage], processingHistory: [ProcessingStep]? = nil, name: String = "Image Set") {
        self.image = nil
        self.images = images
        self.table = nil
        self.tables = nil
        // Combine histories from all images, removing duplicates
        var combinedHistory: [ProcessingStep] = processingHistory ?? []
        for img in images {
            for step in img.processingHistory {
                if !combinedHistory.contains(where: { $0.stepID == step.stepID && $0.order == step.order }) {
                    combinedHistory.append(step)
                }
            }
        }
        combinedHistory.sort { $0.order < $1.order }
        self.processingHistory = combinedHistory
        self.id = UUID().uuidString
        self.name = name
    }
    
    /// Initialize with a single table
    public init(table: ProcessedTable, processingHistory: [ProcessingStep]? = nil) {
        self.image = nil
        self.images = nil
        self.table = table
        self.tables = nil
        self.processingHistory = processingHistory ?? table.processingHistory
        self.id = table.id
        self.name = table.name
    }
    
    /// Initialize with multiple tables
    public init(tables: [ProcessedTable], processingHistory: [ProcessingStep]? = nil, name: String = "Table Set") {
        self.image = nil
        self.images = nil
        self.table = nil
        self.tables = tables
        // Combine histories from all tables, removing duplicates
        var combinedHistory: [ProcessingStep] = processingHistory ?? []
        for tbl in tables {
            for step in tbl.processingHistory {
                if !combinedHistory.contains(where: { $0.stepID == step.stepID && $0.order == step.order }) {
                    combinedHistory.append(step)
                }
            }
        }
        combinedHistory.sort { $0.order < $1.order }
        self.processingHistory = combinedHistory
        self.id = UUID().uuidString
        self.name = name
    }
    
    /// Initialize with mixed data (images and tables)
    public init(
        images: [ProcessedImage]? = nil,
        tables: [ProcessedTable]? = nil,
        processingHistory: [ProcessingStep],
        name: String = "Mixed Data"
    ) {
        self.image = nil
        self.images = images
        self.table = nil
        self.tables = tables
        self.processingHistory = processingHistory
        self.id = UUID().uuidString
        self.name = name
    }
    
    /// Creates a new ProcessedDataContainer by applying a processing step
    public func withProcessingStep(
        stepID: String,
        stepName: String,
        parameters: [String: String] = [:],
        newImage: ProcessedImage? = nil,
        newImages: [ProcessedImage]? = nil,
        newTable: ProcessedTable? = nil,
        newTables: [ProcessedTable]? = nil,
        newName: String? = nil
    ) -> ProcessedDataContainer {
        let nextOrder = processingHistory.count
        let newStep = ProcessingStep(
            stepID: stepID,
            stepName: stepName,
            parameters: parameters,
            order: nextOrder
        )
        
        let newHistory = processingHistory + [newStep]
        
        // Determine what to create based on what's provided
        if let img = newImage {
            return ProcessedDataContainer(image: img, processingHistory: newHistory)
        } else if let imgs = newImages {
            return ProcessedDataContainer(images: imgs, processingHistory: newHistory, name: newName ?? name)
        } else if let tbl = newTable {
            return ProcessedDataContainer(table: tbl, processingHistory: newHistory)
        } else if let tbls = newTables {
            return ProcessedDataContainer(tables: tbls, processingHistory: newHistory, name: newName ?? name)
        } else {
            // Keep existing data but update history
            if let img = image {
                return ProcessedDataContainer(image: img, processingHistory: newHistory)
            } else if let imgs = images {
                return ProcessedDataContainer(images: imgs, processingHistory: newHistory, name: newName ?? name)
            } else if let tbl = table {
                return ProcessedDataContainer(table: tbl, processingHistory: newHistory)
            } else if let tbls = tables {
                return ProcessedDataContainer(tables: tbls, processingHistory: newHistory, name: newName ?? name)
            } else {
                return ProcessedDataContainer(images: images, tables: tables, processingHistory: newHistory, name: newName ?? name)
            }
        }
    }
    
    /// Checks if this data has been processed with a specific step and parameters
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

/// Make ProcessedImage conform to ProcessedData
extension ProcessedImage: ProcessedData {}

/// Make ProcessedTable conform to ProcessedData
extension ProcessedTable: ProcessedData {}


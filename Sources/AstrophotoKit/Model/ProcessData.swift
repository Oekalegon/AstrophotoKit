import Foundation

/// Represents a piece of data in a pipeline.
/// 
/// Implementations are for instance frames, tables, and frame collections.
protocol ProcessData {

    /// The unique identifier for this piece of data.
    var identifier: String { get  }

    /// The date and time this piece of data was instantiated.
    /// 
    /// The data may not exist yet, if the process that produces 
    /// this data has not yet been executed.
    /// 
    /// Instances of ``ProcessData`` are created when a pipeline is
    /// started. The actual data will not exist yet, except when it 
    /// is input data for the pipeline.
    var instantiatedAt: Date? { get }

    /// Whether this piece of data has been instantiated.
    /// 
    /// The data may not exist yet, if the process that produces 
    /// this data has not yet been executed.
    /// 
    /// Instances of ``ProcessData`` are created when a pipeline is
    /// started. The actual data will not exist yet, except when it 
    /// is input data for the pipeline.
    var isInstantiated: Bool { get }

    /// Whether this piece of data is a collection.
    var isCollection: Bool { get }

    /// The identifier of the processor that produced this piece of data.
    var processIdentifier: String { get }

    /// Get the metadata for this piece of data.
    /// - Parameter key: The key of the metadata to get.
    /// - Returns: The metadata value, or nil if the metadata does not exist.
    func metadata(for key: any MetadataKey) -> Any?
}

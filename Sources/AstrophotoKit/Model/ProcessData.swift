import Foundation

/// Represents a piece of data in a pipeline.
/// 
/// Implementations are for instance frames, tables, and frame collections.
public protocol ProcessData {

    /// The unique identifier for this piece of data.
    var identifier: UUID { get  }

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

    /// The number of items in this collection.
    /// 
    /// This is only valid if ``isCollection`` is `true`.
    var collectionCount: Int { get }

    /// The input links for this piece of data.
    /// 
    /// The input links are the links (process parameters) to which this piece of data is connected.
    /// They identify the process and the parameter name into which this data is fed.
    var inputLinks: [ProcessDataLink] { get }

    /// The output link for this piece of data.
    /// 
    /// The data can be produced by only one process, so there is only one output link.
    /// It is connected to the process that produces this data with a name reference.
    /// Named references are needed when a process produces multiple outputs and the 
    /// output data needs to be referenced by name.
    var outputLink: ProcessDataLink? { get }

    /// Get the metadata for this piece of data.
    /// - Parameter key: The key of the metadata to get.
    /// - Returns: The metadata value, or nil if the metadata does not exist.
    func metadata(for key: any MetadataKey) -> Any?
}

/// A link to a piece of data in a process.
/// 
/// A process has a set of input and output links.
/// Each link is identified by the process identifier and the link name.
/// Think of link namse as the name of the parameter of the process in the case of an input link.
public enum ProcessDataLink {
    /// An input link to a piece of data in a process.
    case input(process: UUID, link: String)
    /// An output link to a piece of data in a process.
    case output(process: UUID, link: String)
}

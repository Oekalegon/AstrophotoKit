import Foundation

/// Data input specification for a pipeline step
/// Specifies which data (frame, table, etc. from a previous step or pipeline input) this step acts upon
public struct DataInput: Codable {
    /// The data input name in the step (e.g., "input_frame", "input_table")
    public let name: String

    /// The source of the data
    /// Format: "step_id.output_name" for step outputs, or "input_name" for pipeline inputs
    public let from: String

    /// Optional metadata restrictions to validate the input data
    /// Keys are metadata field names (e.g., "frame_type", "filter", "exposure_time", "camera")
    /// Values are restrictions that must be satisfied
    public let metadataRestrictions: [String: MetadataRestriction]?

    /// Optional description
    public let description: String?

    public init(
        name: String,
        from: String,
        metadataRestrictions: [String: MetadataRestriction]? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.from = from
        self.metadataRestrictions = metadataRestrictions
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case name
        case from
        case metadataRestrictions = "metadata_restrictions"
        case description
    }
}
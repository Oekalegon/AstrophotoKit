import Foundation
import Metal

extension Frame {
    /// Create a Frame from a FITSImage.
    ///
    /// This initializer creates a Frame instance from a FITSImage, including creating
    /// the Metal texture from the image data. Metadata such as frame type and filter
    /// are extracted from the FITS header if available.
    /// - Parameters:
    ///   - fitsImage: The FITS image to create the frame from
    ///   - device: The Metal device to use for creating the texture
    ///   - processIdentifier: The identifier of the process that produced this frame
    /// - Throws: An error if the texture cannot be created
    public init(
        fitsImage: FITSImage, device: MTLDevice,
        outputProcess: (id: UUID, name: String)?,
        inputProcesses: [(id: UUID, name: String)]
    ) throws {
        // Create the texture from the FITS image using the appropriate pixel format
        let texture = try fitsImage.createMetalTexture(device: device, pixelFormat: fitsImage.dataType.metalPixelFormat)

        // Determine color space from the texture's pixel format
        let colorSpace = ColorSpace.from(metalPixelFormat: texture.pixelFormat) ?? .greyscale

        // Extract frame type from FITS header
        var frameType: FrameType = .light
        if let frameTypeStr = fitsImage.metadata["FRAMETYP"]?.stringValue?.lowercased() {
            frameType = FrameType(rawValue: frameTypeStr) ?? .light
        } else if let imagetyp = fitsImage.metadata["IMAGETYP"]?.stringValue?.lowercased() {
            // Some FITS files use IMAGETYP instead of FRAMETYP
            frameType = FrameType(rawValue: imagetyp) ?? .light
        }

        // Extract filter from FITS header
        var filter: Filter = .none
        if let filterStr = fitsImage.metadata["FILTER"]?.stringValue {
            // Try to match filter string to Filter enum (case-insensitive)
            let normalizedFilter = filterStr.lowercased().trimmingCharacters(in: .whitespaces)
            filter = Filter(rawValue: normalizedFilter) ?? .none
        }

        // Initialize using the main initializer
        self.init(
            type: frameType,
            filter: filter,
            colorSpace: colorSpace,
            dataType: fitsImage.dataType,
            texture: texture,
            outputProcess: outputProcess,
            inputProcesses: inputProcesses
        )
    }
}

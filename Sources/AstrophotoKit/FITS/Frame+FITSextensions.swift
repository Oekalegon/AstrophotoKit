import Foundation
import Metal

extension Frame {
    /// Create a Frame from a FITSImage.
    ///
    /// This initializer creates a Frame instance from a FITSImage, including creating
    /// the Metal texture from the image data. Metadata such as frame type and filter
    /// are extracted from the FITS header if available.
    /// 
    /// The texture is kept as grayscale (r32Float) for memory efficiency.
    /// Convert to RGBA only when needed (e.g., for color overlays in StarDetectionOverlayProcessor).
    /// - Parameters:
    ///   - fitsImage: The FITS image to create the frame from
    ///   - device: The Metal device to use for creating the texture
    ///   - outputProcess: The output link for this frame (the process that produces it)
    ///   - inputProcesses: The input links for this frame (the processes that consume it)
    /// - Throws: An error if the texture cannot be created
    public init(
        fitsImage: FITSImage,
        device: MTLDevice,
        outputProcess: ProcessDataLink? = nil,
        inputProcesses: [ProcessDataLink] = []
    ) throws {
        // Create the texture from the FITS image as r32Float (pixelData is always Float32)
        // This ensures correct data layout regardless of original FITS data type
        // Keep as grayscale for memory efficiency - only convert to RGBA when needed (e.g., for color overlays)
        let texture = try fitsImage.createMetalTexture(device: device, pixelFormat: .r32Float)

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

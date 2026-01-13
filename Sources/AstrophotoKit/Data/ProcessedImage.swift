import Foundation
import Metal

/// Represents the type of image data
public enum ImageType: String, Codable {
    case grayscale
    case binary
    case rgb
    case rgba
}

/// Represents a processing step that has been applied to an image
public struct ProcessingStep: Codable, Equatable {
    /// The ID of the processing step (e.g., "gaussian_blur", "threshold")
    public let stepID: String
    
    /// The name of the processing step
    public let stepName: String
    
    /// Parameters used in this step (e.g., ["sigma": "3.0", "radius": "5.0"])
    public let parameters: [String: String]
    
    /// The order in which this step was applied (0 = first step)
    public let order: Int
    
    public init(stepID: String, stepName: String, parameters: [String: String] = [:], order: Int) {
        self.stepID = stepID
        self.stepName = stepName
        self.parameters = parameters
        self.order = order
    }
    
    /// Checks if this step matches another step with the same ID and parameters
    public func matches(_ other: ProcessingStep) -> Bool {
        return stepID == other.stepID && parameters == other.parameters
    }
}

/// Represents a processed image with metadata about its processing history
public class ProcessedImage {
    /// The Metal texture containing the image data
    public let texture: MTLTexture
    
    /// The type of image (grayscale, binary, RGB, RGBA)
    public let imageType: ImageType
    
    /// The original min/max values (for grayscale images)
    public let originalMinValue: Float
    public let originalMaxValue: Float
    
    /// The processing steps that have been applied to create this image
    public let processingHistory: [ProcessingStep]
    
    /// Optional FITS image metadata (if this originated from a FITS file)
    public let fitsImage: FITSImage?
    
    /// A unique identifier for this processed image
    public let id: String
    
    /// Human-readable name/description
    public let name: String
    
    /// Width of the image
    public var width: Int { texture.width }
    
    /// Height of the image
    public var height: Int { texture.height }
    
    public init(
        texture: MTLTexture,
        imageType: ImageType,
        originalMinValue: Float = 0.0,
        originalMaxValue: Float = 1.0,
        processingHistory: [ProcessingStep] = [],
        fitsImage: FITSImage? = nil,
        id: String = UUID().uuidString,
        name: String = "Processed Image"
    ) {
        self.texture = texture
        self.imageType = imageType
        self.originalMinValue = originalMinValue
        self.originalMaxValue = originalMaxValue
        self.processingHistory = processingHistory
        self.fitsImage = fitsImage
        self.id = id
        self.name = name
    }
    
    /// Creates a new ProcessedImage by applying a processing step
    public func withProcessingStep(
        stepID: String,
        stepName: String,
        parameters: [String: String] = [:],
        newTexture: MTLTexture,
        newImageType: ImageType? = nil,
        newName: String? = nil
    ) -> ProcessedImage {
        let nextOrder = processingHistory.count
        let newStep = ProcessingStep(
            stepID: stepID,
            stepName: stepName,
            parameters: parameters,
            order: nextOrder
        )
        
        return ProcessedImage(
            texture: newTexture,
            imageType: newImageType ?? imageType,
            originalMinValue: originalMinValue,
            originalMaxValue: originalMaxValue,
            processingHistory: processingHistory + [newStep],
            fitsImage: fitsImage,
            id: UUID().uuidString,
            name: newName ?? "\(name) + \(stepName)"
        )
    }
    
    /// Checks if this image has been processed with a specific step and parameters
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
    
    /// Creates a ProcessedImage from a FITSImage
    public static func fromFITSImage(
        _ fitsImage: FITSImage,
        device: MTLDevice,
        pixelFormat: MTLPixelFormat = .r32Float
    ) throws -> ProcessedImage {
        let texture = try fitsImage.createMetalTexture(device: device, pixelFormat: pixelFormat)
        let imageType: ImageType = pixelFormat == .rgba32Float ? .rgba : .grayscale
        
        return ProcessedImage(
            texture: texture,
            imageType: imageType,
            originalMinValue: fitsImage.originalMinValue,
            originalMaxValue: fitsImage.originalMaxValue,
            processingHistory: [],
            fitsImage: fitsImage,
            id: UUID().uuidString,
            name: "Original Image"
        )
    }
}

/// Extension to help with image type detection
extension ProcessedImage {
    /// Determines the image type from a Metal texture pixel format
    public static func imageType(from pixelFormat: MTLPixelFormat) -> ImageType {
        switch pixelFormat {
        case .r32Float, .r16Float, .r8Unorm, .r16Unorm:
            return .grayscale
        case .rgba32Float, .rgba16Float, .rgba8Unorm:
            return .rgba
        case .rgb10a2Unorm, .bgra8Unorm:
            return .rgb
        default:
            return .grayscale
        }
    }
}


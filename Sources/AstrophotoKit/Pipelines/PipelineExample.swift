import Foundation
import Metal

/// Example usage of the pipeline system
public class PipelineExample {
    
    /// Example: Run star detection pipeline on a FITS image
    /// - Parameter fitsImage: The FITS image to process
    /// - Returns: Dictionary of output results
    public static func runStarDetectionPipeline(on fitsImage: FITSImage) throws -> [String: PipelineData] {
        // Create pipeline executor
        let executor = try PipelineExecutor()
        
        // Get the star detection pipeline from registry
        guard let pipeline = PipelineRegistry.shared.get("star_detection") else {
            throw NSError(domain: "PipelineExample", code: 1, userInfo: [NSLocalizedDescriptionKey: "Star detection pipeline not found"])
        }
        
        // Prepare inputs
        let inputs: [String: PipelineData] = [
            "input_image": .fitsImage(fitsImage)
        ]
        
        // Execute pipeline
        let outputs = try executor.execute(pipeline: pipeline, inputs: inputs)
        
        return outputs
    }
    
    /// Example: Run star detection pipeline with custom parameters
    /// - Parameters:
    ///   - fitsImage: The FITS image to process
    ///   - blurRadius: Custom blur radius
    ///   - thresholdValue: Custom threshold value
    /// - Returns: Dictionary of output results
    public static func runStarDetectionPipeline(
        on fitsImage: FITSImage,
        blurRadius: Float,
        thresholdValue: Float
    ) throws -> [String: PipelineData] {
        // Create a custom pipeline with specific parameters
        let pipeline = StarDetectionPipeline(
            blurRadius: blurRadius,
            thresholdValue: thresholdValue,
            thresholdMethod: .otsu
        )
        
        // Create pipeline executor
        let executor = try PipelineExecutor()
        
        // Prepare inputs
        let inputs: [String: PipelineData] = [
            "input_image": .fitsImage(fitsImage)
        ]
        
        // Execute pipeline
        let outputs = try executor.execute(pipeline: pipeline, inputs: inputs)
        
        return outputs
    }
    
    /// Example: Run star detection pipeline on multiple images (batch processing)
    /// - Parameter fitsImages: Array of FITS images to process
    /// - Returns: Array of output dictionaries, one per image
    public static func runStarDetectionPipelineBatch(on fitsImages: [FITSImage]) throws -> [[String: PipelineData]] {
        // Create pipeline executor
        let executor = try PipelineExecutor()
        
        // Get the star detection pipeline from registry
        guard let pipeline = PipelineRegistry.shared.get("star_detection") else {
            throw NSError(domain: "PipelineExample", code: 1, userInfo: [NSLocalizedDescriptionKey: "Star detection pipeline not found"])
        }
        
        // Prepare inputs for each image
        let imageInputs = fitsImages.map { fitsImage in
            ["input_image": PipelineData.fitsImage(fitsImage)]
        }
        
        // Execute pipeline on all images
        let results = try executor.executeBatch(pipeline: pipeline, imageInputs: imageInputs)
        
        return results
    }
    
    /// Example: Access pipeline outputs
    /// - Parameter outputs: The outputs from a pipeline execution
    /// - Returns: Extracted results
    public static func extractResults(from outputs: [String: PipelineData]) -> (
        blurredImage: MTLTexture?,
        backgroundImage: MTLTexture?,
        backgroundSubtractedImage: MTLTexture?,
        backgroundLevel: Float?,
        thresholdedImage: MTLTexture?,
        binaryMask: MTLTexture?
    ) {
        return (
            blurredImage: outputs["blurred_image"]?.texture,
            backgroundImage: outputs["background_image"]?.texture,
            backgroundSubtractedImage: outputs["background_subtracted_image"]?.texture,
            backgroundLevel: outputs["background_level"]?.scalar,
            thresholdedImage: outputs["thresholded_image"]?.texture,
            binaryMask: outputs["binary_mask"]?.texture
        )
    }
}


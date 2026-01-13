import Foundation
import Metal
import MetalKit

/// Example usage of FITS file reading and Metal integration
/// This file demonstrates how to use the FITS API
public struct FITSExample {
    
    /// Example: Read a FITS file and create a Metal texture
    /// - Parameters:
    ///   - filePath: Path to the FITS file
    ///   - device: Metal device
    /// - Returns: Metal texture and metadata
    public static func loadFITSAsMetalTexture(filePath: String, device: MTLDevice) throws -> (texture: MTLTexture, metadata: [String: FITSHeaderValue]) {
        // Open FITS file
        let fitsFile = try FITSFile(path: filePath)
        
        // Read the image with metadata
        let fitsImage = try fitsFile.readFITSImage()
        
        // Access metadata
        let metadata = fitsImage.metadata
        print("Image dimensions: \(fitsImage.width) x \(fitsImage.height)")
        print("Data type: \(fitsImage.dataType)")
        
        // Access specific metadata values
        if let ra = metadata["RA"]?.doubleValue {
            print("Right Ascension: \(ra)")
        }
        if let dec = metadata["DEC"]?.doubleValue {
            print("Declination: \(dec)")
        }
        if let exposure = metadata["EXPOSURE"]?.doubleValue {
            print("Exposure time: \(exposure)")
        }
        
        // Create Metal texture
        let texture = try fitsImage.createMetalTexture(device: device)
        
        return (texture, metadata)
    }
    
    /// Example: Read FITS file and get pixel data for custom processing
    /// - Parameter filePath: Path to the FITS file
    /// - Returns: FITSImage with pixel data
    public static func loadFITSPixelData(filePath: String) throws -> FITSImage {
        let fitsFile = try FITSFile(path: filePath)
        return try fitsFile.readFITSImage()
    }
    
    /// Example: Access multiple HDUs in a FITS file
    /// - Parameter filePath: Path to the FITS file
    public static func readAllHDUs(filePath: String) throws -> [FITSImage] {
        let fitsFile = try FITSFile(path: filePath)
        let numHDUs = try fitsFile.numberOfHDUs()
        
        var images: [FITSImage] = []
        for hdu in 0..<numHDUs {
            let image = try fitsFile.readFITSImage(hduNumber: hdu)
            images.append(image)
        }
        
        return images
    }
}


import Foundation
import CCFITSIO
import os

// Direct C function bindings for functions that Swift Package Manager can't see
// Using Swift naming conventions while mapping to C function names
@_silgen_name("fits_open_file_wrapper")
func openFITSFile(_ fptr: UnsafeMutablePointer<OpaquePointer?>, _ filename: UnsafePointer<CChar>?, _ mode: Int32, _ status: UnsafeMutablePointer<Int32>) -> Int32

@_silgen_name("fits_close_file_wrapper")
func closeFITSFile(_ fptr: OpaquePointer?, _ status: UnsafeMutablePointer<Int32>) -> Int32

@_silgen_name("fits_get_num_hdus_wrapper")
func getNumberOfHDUs(_ fptr: OpaquePointer?, _ numhdus: UnsafeMutablePointer<Int32>, _ status: UnsafeMutablePointer<Int32>) -> Int32

@_silgen_name("fits_get_errstatus_wrapper")
func getFITSErrorStatus(_ status: Int32, _ errText: UnsafeMutablePointer<CChar>)

/// A Swift wrapper for FITS file operations using CFITSIO
public class FITSFile {
    internal var fitsfile: OpaquePointer?
    
    /// Opens a FITS file for reading or writing
    /// - Parameters:
    ///   - path: The file path to the FITS file
    ///   - mode: The access mode ("READONLY" or "READWRITE")
    /// - Throws: An error if the file cannot be opened
    public init(path: String, mode: String = "READONLY") throws {
        var status: Int32 = 0
        var fitsfilePtr: OpaquePointer?
        
        let cPath = path.cString(using: .utf8)
        
        _ = openFITSFile(&fitsfilePtr, cPath, Int32(mode == "READONLY" ? 0 : 1), &status)
        
        guard status == 0, let file = fitsfilePtr else {
            // CFITSIO uses FLEN_ERRMSG (81) for error messages
            var errorText = [CChar](repeating: 0, count: 81)
            getFITSErrorStatus(status, &errorText)
            // Ensure null-termination
            errorText[80] = 0
            // Safely convert to String
            let errorString = String(cString: errorText)
            Logger.swiftfitsio.error("Failed to open FITS file at \(path): status \(status), \(errorString)")
            throw FITSFileError.cannotOpenFile(path: path, status: status, message: errorString)
        }
        
        Logger.swiftfitsio.debug("Opened FITS file at \(path)")
        
        self.fitsfile = file
    }
    
    deinit {
        if let file = fitsfile {
            var status: Int32 = 0
            _ = closeFITSFile(file, &status)
        }
    }
    
    /// Reads the number of HDUs (Header Data Units) in the FITS file
    public func numberOfHDUs() throws -> Int {
        guard let file = fitsfile else {
            throw FITSFileError.fileNotOpen
        }
        
        var numHDUs: Int32 = 0
        var status: Int32 = 0
        
        _ = getNumberOfHDUs(file, &numHDUs, &status)
        
        guard status == 0 else {
            var errorText = [CChar](repeating: 0, count: 81)
            getFITSErrorStatus(status, &errorText)
            errorText[80] = 0
            let errorString = String(cString: errorText)
            Logger.swiftfitsio.error("Error reading number of HDUs: status \(status), \(errorString)")
            throw FITSFileError.readError(status: status, message: errorString)
        }
        
        return Int(numHDUs)
    }
}

/// Errors that can occur when working with FITS files
public enum FITSFileError: Error, LocalizedError {
    case cannotOpenFile(path: String, status: Int32, message: String)
    case fileNotOpen
    case readError(status: Int32, message: String)
    case unsupportedDataType(bitpix: Int32)
    
    public var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path, let status, let message):
            return "Cannot open FITS file at \(path): status \(status), \(message)"
        case .fileNotOpen:
            return "FITS file is not open"
        case .readError(let status, let message):
            return "Error reading FITS file: status \(status), \(message)"
        case .unsupportedDataType(let bitpix):
            return "Unsupported data type: bitpix = \(bitpix)"
        }
    }
}


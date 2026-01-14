import Foundation
import os
import AstrophotoKit

@main
struct AstrophotoKitCLI {
    static var verbose = false
    
    /// Prints an error message to stderr
    static func printError(_ message: String) {
        let data = (message + "\n").data(using: .utf8) ?? Data()
        FileHandle.standardError.write(data)
    }
    
    static func main() {
        let arguments = CommandLine.arguments
        
        guard arguments.count > 1 else {
            printUsage()
            exit(1)
        }
        
        let command = arguments[1]
        
        switch command {
        case "info":
            if arguments.count < 3 {
                printError("Error: Please provide a FITS file path")
                printUsage()
                exit(1)
            }
            // Check for verbose flag
            if arguments.contains("--verbose") || arguments.contains("-v") {
                verbose = true
            }
            handleInfoCommand(path: arguments[2])
        case "help", "--help", "-h":
            printUsage()
        default:
            printError("Error: Unknown command '\(command)'")
            printUsage()
            exit(1)
        }
    }
    
    static func printUsage() {
        print("""
        AstrophotoKit CLI - Command line tools for astronomical image processing
        
        Usage:
          astrophoto <command> [arguments]
        
        Commands:
          info <file>    Display information about a FITS file
          help           Show this help message
        
        Examples:
          astrophoto info image.fits
        """)
    }
    
    static func handleInfoCommand(path: String) {
        do {
            Logger.cli.debug("Opening FITS file: \(path)")
            let fitsFile = try FITSFile(path: path)
            let numHDUs = try fitsFile.numberOfHDUs()
            
            Logger.cli.debug("File opened successfully, found \(numHDUs) HDUs")
            
            print("FITS File Information")
            print("====================")
            print("Path: \(path)")
            print("Number of HDUs: \(numHDUs)")
            
            // Try to read image data if available
            Logger.cli.debug("Attempting to read image data from primary HDU")
            if let image = try? fitsFile.readFITSImage() {
                Logger.cli.debug("Successfully read image: \(image.width)x\(image.height)x\(image.depth)")
                print("\nImage Data:")
                print("  Dimensions: \(image.width) x \(image.height) x \(image.depth)")
                print("  Bitpix: \(image.bitpix)")
                print("  Data Type: \(image.dataType.description)")
                print("  Min value: \(image.originalMinValue)")
                print("  Max value: \(image.originalMaxValue)")
                
                let mean = image.pixelData.reduce(0, +) / Float32(image.pixelData.count)
                let normalizedMin = image.pixelData.min() ?? 0
                let normalizedMax = image.pixelData.max() ?? 0
                print("  Normalized pixel range: [\(normalizedMin), \(normalizedMax)]")
                print("  Mean normalized value: \(mean)")
                print("  Total pixels: \(image.pixelData.count)")
                
                // Show some metadata if available
                if !image.metadata.isEmpty {
                    print("\nMetadata (showing first 10 keys):")
                    let keys = Array(image.metadata.keys.sorted().prefix(10))
                    for key in keys {
                        if let value = image.metadata[key] {
                            let valueStr: String
                            switch value {
                            case .string(let str): valueStr = str
                            case .integer(let int): valueStr = "\(int)"
                            case .floatingPoint(let double): valueStr = "\(double)"
                            case .boolean(let bool): valueStr = bool ? "T" : "F"
                            case .comment(let comment): valueStr = comment
                            }
                            print("  \(key) = \(valueStr)")
                        }
                    }
                    if image.metadata.count > 10 {
                        print("  ... and \(image.metadata.count - 10) more keys")
                    }
                }
            }
            
        } catch {
            Logger.cli.error("Error reading FITS file: \(error.localizedDescription)")
            printError("Error reading FITS file: \(error)")
            exit(1)
        }
    }
}


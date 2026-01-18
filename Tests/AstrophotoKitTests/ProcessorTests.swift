import Testing
import Foundation
import Metal
@testable import AstrophotoKit

@Test("Grayscale and Gaussian blur processors work with FITS input")
func testGrayscaleAndBlurProcessors() async throws {
    // Get Metal device
    guard let device = MTLCreateSystemDefaultDevice() else {
        Issue.record("Metal device not available")
        return
    }

    guard let commandQueue = device.makeCommandQueue() else {
        Issue.record("Could not create Metal command queue")
        return
    }

    // Load a FITS file from test resources
    // FITS files are in the test bundle, not the main bundle
    let fitsFileName = "CHI-1-CMOS_2025-03-25T08-25-40_LDN43TheCosmicBatNebula_Luminance_300s_ID493996_cal"
    var resourceURL: URL?
    // Try test bundle first
    if let testBundle = Bundle.module as Bundle? {
        resourceURL = testBundle.url(forResource: fitsFileName, withExtension: "fits")
    }
    // Fallback: try all bundles
    if resourceURL == nil {
        for b in Bundle.allBundles {
            if let url = b.url(forResource: fitsFileName, withExtension: "fits") {
                resourceURL = url
                break
            }
        }
    }
    guard let resourceURL = resourceURL else {
        Issue.record("Could not find test FITS file")
        return
    }

    // Open FITS file and read image
    let fitsFile = try FITSFile(path: resourceURL.path)
    let fitsImage = try fitsFile.readFITSImage()

    // Create Frame from FITS image
    let inputFrame = try Frame(fitsImage: fitsImage, device: device)

    // Verify input frame has texture
    #expect(inputFrame.texture != nil, "Input frame should have a texture")
    let inputTexture = inputFrame.texture!
    print("Input frame: \(inputTexture.width)x\(inputTexture.height), format: \(inputTexture.pixelFormat)")

    // Test 1: Grayscale processor
    let grayscaleProcessor = GrayscaleProcessor()
    let grayscaleInputs: [String: ProcessData] = ["input_frame": inputFrame]
    var grayscaleOutputs: [String: ProcessData] = ["grayscale_frame": Frame(type: .light, filter: .none, colorSpace: .greyscale, dataType: .float)]
    try grayscaleProcessor.execute(
        inputs: grayscaleInputs,
        outputs: &grayscaleOutputs,
        parameters: [:],
        device: device,
        commandQueue: commandQueue
    )

    // Verify grayscale output
    guard let grayscaleFrame = grayscaleOutputs["grayscale_frame"] as? Frame else {
        Issue.record("Grayscale processor did not return grayscale_frame")
        return
    }

    #expect(grayscaleFrame.texture != nil, "Grayscale frame should have a texture")
    #expect(grayscaleFrame.colorSpace == ColorSpace.greyscale, "Grayscale frame should have greyscale color space")
    let grayscaleTexture = grayscaleFrame.texture!
    #expect(grayscaleTexture.width == inputTexture.width, "Grayscale output should have same width as input")
    #expect(grayscaleTexture.height == inputTexture.height, "Grayscale output should have same height as input")
    print(
        "Grayscale output: \(grayscaleTexture.width)x\(grayscaleTexture.height), " +
        "format: \(grayscaleTexture.pixelFormat)"
    )

    // Test 2: Gaussian blur processor (using grayscale output as input)
    let blurProcessor = GaussianBlurProcessor()
    let blurInputs: [String: ProcessData] = ["input_frame": grayscaleFrame]
    let blurParameters: [String: Parameter] = [
        "radius": Parameter.double(3.0)
    ]
    var blurOutputs: [String: ProcessData] = ["blurred_frame": Frame(type: .light, filter: .none, colorSpace: .greyscale, dataType: .float)]
    try blurProcessor.execute(
        inputs: blurInputs,
        outputs: &blurOutputs,
        parameters: blurParameters,
        device: device,
        commandQueue: commandQueue
    )

    // Verify blur output
    guard let blurredFrame = blurOutputs["blurred_frame"] as? Frame else {
        Issue.record("Blur processor did not return blurred_frame")
        return
    }

    #expect(blurredFrame.texture != nil, "Blurred frame should have a texture")
    let blurredTexture = blurredFrame.texture!
    #expect(blurredTexture.width == inputTexture.width, "Blurred output should have same width as input")
    #expect(blurredTexture.height == inputTexture.height, "Blurred output should have same height as input")
    print(
        "Blur output: \(blurredTexture.width)x\(blurredTexture.height), format: \(blurredTexture.pixelFormat)"
    )

    // Test 3: Run both processors in sequence (simulating pipeline)
    print("Successfully tested grayscale and blur processors in sequence")
}

import Testing
import Foundation
import Metal
@testable import AstrophotoKit

@Test("Star detection pipeline runs first three steps (grayscale, blur, and background)")
func testStarDetectionPipelineFirstThreeSteps() async throws {
    // Get Metal device
    guard let device = MTLCreateSystemDefaultDevice() else {
        Issue.record("Metal device not available")
        return
    }

    guard let commandQueue = device.makeCommandQueue() else {
        Issue.record("Could not create Metal command queue")
        return
    }

    // Load the star-detection pipeline
    guard let bundle = findMainPackageBundle(),
          let pipelineURL = bundle.url(forResource: "star-detection", withExtension: "yaml") else {
        Issue.record("Failed to find star-detection.yaml resource")
        return
    }
    let pipeline = try Pipeline.load(from: pipelineURL)

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

    // Create the pipeline runner
    let runner = PipelineRunner(pipeline: pipeline)

    // Execute the pipeline with the input frame
    // Processors are automatically registered when first accessed
    let outputs = try await runner.execute(
        inputs: ["input_frame": inputFrame],
        parameters: ["blur_radius": Parameter.double(3.0)],
        device: device,
        commandQueue: commandQueue
    )

    print("\n=== Pipeline Execution Results ===")
    print("Number of output data items: \(outputs.count)")

    // Verify we have output data
    #expect(!outputs.isEmpty, "Pipeline should produce output data")

    // Check for grayscale_frame output (from first step)
    // Find data by stepLinkID: "grayscale.grayscale_frame"
    let grayscaleData = outputs.first { data in
        if case .output(_, _, _, let stepLinkID) = data.outputLink {
            return stepLinkID == "grayscale.grayscale_frame"
        }
        return false
    }
    #expect(grayscaleData != nil, "Should have grayscale_frame output")
    if let grayscaleFrame = grayscaleData as? Frame {
        #expect(grayscaleFrame.texture != nil, "Grayscale frame should be instantiated")
        #expect(grayscaleFrame.isInstantiated, "Grayscale frame should be instantiated")
        #expect(grayscaleFrame.colorSpace == ColorSpace.greyscale, "Grayscale frame should have greyscale color space")
        print("✓ Grayscale frame: \(grayscaleFrame.texture!.width)x\(grayscaleFrame.texture!.height)")
    }

    // Check for blurred_frame output (from second step)
    // Find data by stepLinkID: "blur.blurred_frame"
    let blurredData = outputs.first { data in
        if case .output(_, _, _, let stepLinkID) = data.outputLink {
            return stepLinkID == "blur.blurred_frame"
        }
        return false
    }
    #expect(blurredData != nil, "Should have blurred_frame output")
    if let blurredFrame = blurredData as? Frame {
        #expect(blurredFrame.texture != nil, "Blurred frame should be instantiated")
        #expect(blurredFrame.isInstantiated, "Blurred frame should be instantiated")
        print("✓ Blurred frame: \(blurredFrame.texture!.width)x\(blurredFrame.texture!.height)")
    }

    // Check for background_frame output (from third step)
    // Find data by stepLinkID: "background.background_frame"
    let backgroundData = outputs.first { data in
        if case .output(_, _, _, let stepLinkID) = data.outputLink {
            return stepLinkID == "background.background_frame"
        }
        return false
    }
    #expect(backgroundData != nil, "Should have background_frame output")
    if let backgroundFrame = backgroundData as? Frame {
        #expect(backgroundFrame.texture != nil, "Background frame should be instantiated")
        #expect(backgroundFrame.isInstantiated, "Background frame should be instantiated")
        print("✓ Background frame: \(backgroundFrame.texture!.width)x\(backgroundFrame.texture!.height)")
    }

    // Check for background_subtracted_frame output (from third step)
    // Find data by stepLinkID: "background.background_subtracted_frame"
    let subtractedData = outputs.first { data in
        if case .output(_, _, _, let stepLinkID) = data.outputLink {
            return stepLinkID == "background.background_subtracted_frame"
        }
        return false
    }
    #expect(subtractedData != nil, "Should have background_subtracted_frame output")
    if let subtractedFrame = subtractedData as? Frame {
        #expect(subtractedFrame.texture != nil, "Background-subtracted frame should be instantiated")
        #expect(subtractedFrame.isInstantiated, "Background-subtracted frame should be instantiated")
        print("✓ Background-subtracted frame: \(subtractedFrame.texture!.width)x\(subtractedFrame.texture!.height)")
    }

    // Check for background_level table output (from third step)
    // Find data by stepLinkID: "background.background_level"
    let backgroundLevelData = outputs.first { data in
        if case .output(_, _, _, let stepLinkID) = data.outputLink {
            return stepLinkID == "background.background_level"
        }
        return false
    }
    #expect(backgroundLevelData != nil, "Should have background_level output")
    if let backgroundLevelTable = backgroundLevelData as? Table {
        #expect(backgroundLevelTable.isInstantiated, "Background level table should be instantiated")
        #expect(backgroundLevelTable.dataFrame != nil, "Background level table should have DataFrame")
        #expect(backgroundLevelTable.rowCount == 1, "Background level table should have 1 row")
        #expect(backgroundLevelTable.columnCount == 1, "Background level table should have 1 column")
        print("✓ Background level table: \(backgroundLevelTable.rowCount) row(s), \(backgroundLevelTable.columnCount) column(s)")
    }

    // Verify process stack
    let processes = await runner.processStack.getAll()
    print("\n=== Process Stack ===")
    print("Total processes: \(processes.count)")

    // Check that grayscale, blur, and background processes exist
    let grayscaleProcess = processes.first { $0.stepIdentifier == "grayscale" }
    let blurProcess = processes.first { $0.stepIdentifier == "blur" }
    let backgroundProcess = processes.first { $0.stepIdentifier == "background" }

    #expect(grayscaleProcess != nil, "Should have grayscale process")
    #expect(blurProcess != nil, "Should have blur process")
    #expect(backgroundProcess != nil, "Should have background process")

    print("✓ Pipeline execution completed successfully")
}


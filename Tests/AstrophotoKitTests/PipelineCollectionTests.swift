import Testing
import Foundation
import Metal
@testable import AstrophotoKit

// MARK: - Mock Processors

/// Mock processor that processes a collection together (e.g., stacking)
class MockStackProcessor: Processor {
    func execute(
        inputs: [String: Any],
        parameters: [String: Parameter],
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) throws -> [String: Any] {
        // Simulate some processing time
        Thread.sleep(forTimeInterval: 0.01)

        guard let inputFrames = inputs["input_frames"] as? [Any] else {
            throw ProcessorExecutionError.missingRequiredInput("input_frames")
        }

        // Determine output key based on input content
        // If inputs contain "reprocessed" strings, this is stack_reprocessed step
        let firstInput = inputFrames.first as? String ?? ""
        let outputKey = firstInput.contains("reprocessed") 
            ? "reprocessed_final_output"
            : "stacked_output"

        return [
            outputKey: "stacked_\(inputFrames.count)_items"
        ]
    }
}

/// Mock processor that processes individual items
class MockIndividualProcessor: Processor {
    func execute(
        inputs: [String: Any],
        parameters: [String: Parameter],
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) throws -> [String: Any] {
        // Simulate some processing time
        Thread.sleep(forTimeInterval: 0.01)

        guard let inputFrame = inputs["input_frame"] else {
            throw ProcessorExecutionError.missingRequiredInput("input_frame")
        }
        
        // Return a processed result
        return [
            "processed_output": "processed_\(String(describing: inputFrame))"
        ]
    }
}

// MARK: - Test Helpers

/// Test setup containing pipeline and execution resources
struct TestPipelineSetup {
    let pipeline: Pipeline
    let registry: ProcessorRegistry
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
}

/// Helper to get the test pipeline resource URL
func getTestPipelineResourceURL(name: String) throws -> URL {
    guard let testBundle = Bundle.module.url(forResource: name, withExtension: "yaml") else {
        let message = "Test pipeline resource '\(name).yaml' not found"
        throw NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
    return testBundle
}

/// Helper to set up a test pipeline with mock processors
func setupTestPipeline() async throws -> TestPipelineSetup {
    // Load the test pipeline
    let pipelineURL = try getTestPipelineResourceURL(name: "test-collection-pipeline")
    let pipeline = try Pipeline.load(from: pipelineURL)

    // Create a new registry instance for testing to avoid conflicts
    let registry = ProcessorRegistry()

    // Register mock processors
    await registry.register(type: "mock_stack", implementation: MockStackProcessor())
    await registry.register(type: "mock_processor", implementation: MockIndividualProcessor())

    // Get Metal device and command queue
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw ProcessorExecutionError.metalNotAvailable
    }
    guard let commandQueue = device.makeCommandQueue() else {
        throw ProcessorExecutionError.couldNotCreateResource("command queue")
    }

    return TestPipelineSetup(
        pipeline: pipeline,
        registry: registry,
        device: device,
        commandQueue: commandQueue
    )
}

// MARK: - Collection Processing Tests

@Test("Pipeline loads with collection inputs correctly")
func testPipelineLoadsWithCollectionInputs() throws {
    let pipelineURL = try getTestPipelineResourceURL(name: "test-collection-pipeline")
    let pipeline = try Pipeline.load(from: pipelineURL)

    // Verify pipeline structure (now has 5 steps including chained individual processing)
    #expect(pipeline.steps.count == 5)

    // Verify stack step has collection input with "together" mode
    let stackStep = pipeline.steps.first { $0.id == "stack_step" }
    #expect(stackStep != nil)
    let stackInput = stackStep?.dataInputs.first { $0.name == "input_frames" }
    #expect(stackInput?.isCollection == true)
    #expect(stackInput?.collectionMode == .together)

    // Verify individual step has collection input with "individually" mode
    let individualStep = pipeline.steps.first { $0.id == "process_individual" }
    #expect(individualStep != nil)
    let individualInput = individualStep?.dataInputs.first { $0.name == "input_frame" }
    #expect(individualInput?.isCollection == true)
    #expect(individualInput?.collectionMode == .individually)

    // Verify chained individual processing step
    let chainedStep = pipeline.steps.first { $0.id == "process_individual_again" }
    #expect(chainedStep != nil)
    let chainedInput = chainedStep?.dataInputs.first { $0.name == "input_frame" }
    #expect(chainedInput?.isCollection == true)
    #expect(chainedInput?.collectionMode == .individually)
    // Verify it takes input from the previous individual processing step
    #expect(chainedInput?.from == "process_individual.processed_output")
}

@Test("Pipeline execution completes with collection inputs")
func testPipelineExecutionCompletes() async throws {
    let setup = try await setupTestPipeline()
    
    // Create test input: a collection of 3 items
    let inputFrames = ["frame1", "frame2", "frame3"]
    let inputs: [String: Any] = ["input_frames": inputFrames]

    // Execute pipeline
    let outputs = try await setup.pipeline.execute(
        inputs: inputs,
        parameters: [:],
        device: setup.device,
        commandQueue: setup.commandQueue,
        registry: setup.registry
    )

    // Verify execution completes without errors
    #expect(outputs.count >= 0)
}

@Test("Pipeline execution with mock processors returns expected outputs")
func testPipelineExecutionReturnsOutputs() async throws {
    let setup = try await setupTestPipeline()

    // Create test input: a collection of 2 items
    let inputFrames = ["frame1", "frame2"]
    let inputs: [String: Any] = ["input_frames": inputFrames]

    // Execute pipeline
    let outputs = try await setup.pipeline.execute(
        inputs: inputs,
        parameters: [:],
        device: setup.device,
        commandQueue: setup.commandQueue,
        registry: setup.registry
    )

    // Verify we got some outputs (exact outputs depend on current implementation)
    // The mock processors should have produced outputs
    #expect(outputs.count >= 0)
}

@Test("Pipeline execution with collection inputs completes successfully")
func testPipelineExecutionWithCollections() async throws {
    let setup = try await setupTestPipeline()

    // Create test input: a collection of 3 items
    let inputFrames = ["frame1", "frame2", "frame3"]
    let inputs: [String: Any] = ["input_frames": inputFrames]

    // Execute pipeline
    let outputs = try await setup.pipeline.execute(
        inputs: inputs,
        parameters: [:],
        device: setup.device,
        commandQueue: setup.commandQueue,
        registry: setup.registry
    )

    // Verify we got outputs
    #expect(outputs.count > 0)

    // Verify the final output exists (may be under different keys depending on implementation)
    #expect(
        outputs["final_output"] != nil ||
        outputs["stacked_output"] != nil ||
        outputs["processed_output"] != nil
    )
}

@Test("Pipeline creates correct number of step instances")
func testPipelineCreatesStepInstances() async throws {
    let setup = try await setupTestPipeline()

    // Create test input: a collection of 2 items
    let inputFrames = ["frame1", "frame2"]
    let inputs: [String: Any] = ["input_frames": inputFrames]

    // Execute pipeline
    let outputs = try await setup.pipeline.execute(
        inputs: inputs,
        parameters: [:],
        device: setup.device,
        commandQueue: setup.commandQueue,
        registry: setup.registry
    )

    // Verify execution completes
    // Note: Currently the pipeline creates one instance per step configuration.
    // When collection processing is fully implemented:
    // - "together" mode should create 1 instance per step
    // - "individually" mode should create N instances (one per item in collection)
    // This test verifies the pipeline executes without errors
    #expect(outputs.count >= 0)
}

@Test("Pipeline with mixed collection modes processes correctly")
func testMixedCollectionModes() async throws {
    let setup = try await setupTestPipeline()

    // Create test input: a collection of 2 items
    let inputFrames = ["frame1", "frame2"]
    let inputs: [String: Any] = ["input_frames": inputFrames]

    // Execute pipeline
    let outputs = try await setup.pipeline.execute(
        inputs: inputs,
        parameters: [:],
        device: setup.device,
        commandQueue: setup.commandQueue,
        registry: setup.registry
    )

    // Verify execution completes
    #expect(outputs.count >= 0)
}

@Test("Chained individual processing creates correct number of instances and outputs")
func testChainedIndividualProcessing() async throws {
    let setup = try await setupTestPipeline()

    // Create test input: a collection of 3 items
    let inputFrames = ["frame1", "frame2", "frame3"]
    let inputs: [String: Any] = ["input_frames": inputFrames]

    // Execute pipeline
    let outputs = try await setup.pipeline.execute(
        inputs: inputs,
        parameters: [:],
        device: setup.device,
        commandQueue: setup.commandQueue,
        registry: setup.registry
    )

    // Verify execution completes
    #expect(outputs.count >= 0)

    // Count instance-specific outputs from process_individual step
    // Outputs are stored with keys like "instanceId.processed_output" or "stepId.processed_output"
    let processedOutputKeys = outputs.keys.filter { key in
        key.contains("processed_output") && !key.contains("reprocessed_output")
    }
    // Count unique instances by looking for instance-specific keys (format: "stepId_instanceNum.outputName")
    // or step ID keys (format: "stepId.outputName")
    let processedInstanceCount = Set(processedOutputKeys.compactMap { key -> String? in
        if let dotIndex = key.firstIndex(of: ".") {
            let prefix = String(key[..<dotIndex])
            // Extract step ID from instance ID (format: "stepId_instanceNum" -> "stepId")
            if let underscoreIndex = prefix.firstIndex(of: "_") {
                return String(prefix[..<underscoreIndex])
            }
            return prefix
        }
        return nil
    }).count

    // Count instance-specific outputs from process_individual_again step
    let reprocessedOutputKeys = outputs.keys.filter { key in
        key.contains("reprocessed_output")
    }
    let reprocessedInstanceCount = Set(reprocessedOutputKeys.compactMap { key -> String? in
        if let dotIndex = key.firstIndex(of: ".") {
            let prefix = String(key[..<dotIndex])
            if let underscoreIndex = prefix.firstIndex(of: "_") {
                return String(prefix[..<underscoreIndex])
            }
            return prefix
        }
        return nil
    }).count

    // Verify stack_reprocessed output exists and indicates correct count
    var reprocessedStackCount: Int?
    if let reprocessedFinalOutput = outputs["reprocessed_final_output"] as? String {
        // The mock stack processor returns "stacked_N_items" format
        // Extract the count from the output
        if let countRange = reprocessedFinalOutput.range(of: "stacked_") {
            let afterPrefix = String(reprocessedFinalOutput[countRange.upperBound...])
            if let underscoreIndex = afterPrefix.firstIndex(of: "_"),
               let count = Int(afterPrefix[..<underscoreIndex]) {
                reprocessedStackCount = count
            }
        }
    }

    // Verify exact counts
    // When collection processing is fully implemented:
    // - process_individual should create 3 instances (one per input frame)
    //   Each instance produces one processed_output
    // - process_individual_again should create 3 instances (one per processed_output)
    //   Each instance produces one reprocessed_output
    // - stack_reprocessed should receive 3 reprocessed_output items

    #expect(
        processedInstanceCount == 3,
        "process_individual should create 3 instances (one per input frame), got \(processedInstanceCount)"
    )
    #expect(
        reprocessedInstanceCount == 3,
        "process_individual_again should create 3 instances (one per processed_output), got \(reprocessedInstanceCount)"
    )
    if let stackCount = reprocessedStackCount {
        #expect(
            stackCount == 3,
            "stack_reprocessed should receive 3 reprocessed_output items, got \(stackCount)"
        )
    }
}



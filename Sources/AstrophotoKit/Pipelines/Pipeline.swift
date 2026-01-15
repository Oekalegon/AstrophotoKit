import Foundation
import Yams
import Metal

/// Pipeline loaded from YAML configuration
public struct Pipeline: Codable {
    /// Unique identifier for this pipeline
    public let id: String

    /// Human-readable name
    public let name: String

    /// Description
    public let description: String?

    /// The steps in this pipeline
    public let steps: [PipelineStep]

    /// Load a pipeline from a YAML file
    public static func load(from url: URL) throws -> Pipeline {
        let data = try Data(contentsOf: url)
        return try parseYAML(from: data)
    }

    /// Load a pipeline from a YAML string
    public static func load(from yamlString: String) throws -> Pipeline {
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(Pipeline.self, from: yamlString)
        } catch {
            throw PipelineConfigurationError.invalidFormat("YAML parsing failed: \(error.localizedDescription)")
        }
    }

    /// Parse a YAML configuration from data
    private static func parseYAML(from data: Data) throws -> Pipeline {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw PipelineConfigurationError.invalidEncoding
        }

        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(Pipeline.self, from: yamlString)
        } catch let decodingError as DecodingError {
            var errorDescription = "YAML parsing failed: "
            switch decodingError {
            case .typeMismatch(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Type mismatch for type \(type) at path \(path): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Value not found for type \(type) at path \(path): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Key '\(key.stringValue)' not found at path \(path): \(context.debugDescription)"
            case .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                errorDescription += "Data corrupted at path \(path): \(context.debugDescription)"
            @unknown default:
                errorDescription += decodingError.localizedDescription
            }
            throw PipelineConfigurationError.invalidFormat(errorDescription)
        } catch {
            throw PipelineConfigurationError.invalidFormat("YAML parsing failed: \(error.localizedDescription)")
        }
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        steps: [PipelineStep]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
    }

    /// Generate a unique instance ID for a step
    /// - Parameters:
    ///   - stepId: The step configuration ID
    ///   - instanceNumber: Optional instance number for multiple instances of the same step
    ///   - inputIdentifiers: Optional identifiers for the inputs being processed
    /// - Returns: Unique instance identifier
    private func generateInstanceId(
        stepId: String,
        instanceNumber: Int? = nil,
        inputIdentifiers: [String] = []
    ) -> String {
        if !inputIdentifiers.isEmpty {
            // Combine all input identifiers into a single string for the instance ID
            // Sort to ensure consistent ordering regardless of input order
            let sortedIds = inputIdentifiers.sorted().joined(separator: "_")
            return "\(stepId)_\(sortedIds)"
        } else if let instanceNum = instanceNumber {
            return "\(stepId)_\(instanceNum)"
        } else {
            // Fallback: use timestamp for uniqueness
            return "\(stepId)_\(UUID().uuidString.prefix(8))"
        }
    }

    /// Resolve data inputs for a step
    private func resolveDataInputs(
        for step: PipelineStep,
        from availableData: [String: Any]
    ) throws -> [String: Any] {
        var resolvedInputs: [String: Any] = [:]
        for dataInput in step.dataInputs {
            let fromParts = dataInput.from.split(separator: ".", maxSplits: 1)
            let sourceData: Any?

            if fromParts.count == 2 {
                // Step output: "step_id.output_name"
                let dependencyStepId = String(fromParts[0])
                let outputName = String(fromParts[1])
                let key = "\(dependencyStepId).\(outputName)"
                sourceData = availableData[key]
            } else {
                // Pipeline input: "input_name"
                let inputName = String(fromParts[0])
                sourceData = availableData[inputName]
            }

            guard let data = sourceData else {
                throw ProcessorExecutionError.missingRequiredInput(dataInput.name)
            }

            resolvedInputs[dataInput.name] = data
        }
        return resolvedInputs
    }

    /// Resolve parameters for a step
    private func resolveParameters(
        for step: PipelineStep,
        from pipelineParameters: [String: Parameter]
    ) -> [String: Parameter] {
        var resolvedParameters: [String: Parameter] = [:]
        for parameterSpec in step.parameters {
            let parameterValue: Parameter?

            if let from = parameterSpec.from {
                // Parameter from pipeline inputs
                if let param = pipelineParameters[from] {
                    parameterValue = param
                } else if let defaultValue = parameterSpec.defaultValue {
                    parameterValue = defaultValue
                } else {
                    parameterValue = nil
                }
            } else if let defaultValue = parameterSpec.defaultValue {
                // Use default value
                parameterValue = defaultValue
            } else {
                parameterValue = nil
            }

            if let value = parameterValue {
                resolvedParameters[parameterSpec.name] = value
            }
        }
        return resolvedParameters
    }

    /// Check if a step instance can run based on available data
    /// - Parameters:
    ///   - step: The step configuration
    ///   - instanceId: Unique identifier for this step instance
    ///   - availableData: Dictionary of currently available data
    ///   - failedInstances: Set of instance IDs that have failed (non-fatal)
    /// - Returns: True if all required inputs are available and no dependencies failed, false otherwise
    private func canStepInstanceRun(
        step: PipelineStep,
        instanceId: String,
        availableData: [String: Any],
        failedInstances: Set<String> = []
    ) -> Bool {
        for dataInput in step.dataInputs {
            let fromParts = dataInput.from.split(separator: ".", maxSplits: 1)
            let sourceData: Any?
            var sourceInstanceId: String?

            if fromParts.count == 2 {
                // Step output: "step_id.output_name" or "instance_id.output_name"
                sourceInstanceId = String(fromParts[0])
                let outputName = String(fromParts[1])
                // Try instance-specific key first: "sourceInstanceId.outputName"
                let instanceKey = "\(sourceInstanceId!).\(outputName)"
                sourceData = availableData[instanceKey] ?? availableData[outputName]
            } else {
                // Pipeline input: "input_name"
                let inputName = String(fromParts[0])
                sourceData = availableData[inputName]
            }

            // Check if the source instance failed (non-fatal)
            if let sourceId = sourceInstanceId, failedInstances.contains(sourceId) {
                return false
            }

            if sourceData == nil {
                return false
            }
        }
        return true
    }

    /// Execute this pipeline asynchronously with parallel execution when dependencies allow
    /// Uses a data-driven execution model: tracks available data and checks pending step instances
    /// when new data becomes available. Each step execution gets a unique instance ID.
    /// - Parameters:
    ///   - inputs: Dictionary of pipeline input name to input data
    ///   - parameters: Dictionary of parameter name to parameter value
    ///   - device: Metal device for GPU operations
    ///   - commandQueue: Metal command queue for GPU operations
    ///   - registry: Processor registry to look up processors (defaults to shared registry)
    /// - Returns: Dictionary of output name to output data (from all step outputs)
    /// - Throws: ProcessorExecutionError or PipelineConfigurationError if execution fails
    public func execute(
        inputs: [String: Any],
        parameters: [String: Parameter] = [:],
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        registry: ProcessorRegistry = .shared
    ) async throws -> [String: Any] {
        // Track available data (pipeline inputs + step outputs)
        // Use actor for async-safe synchronization
        actor DataStore {
            var data: [String: Any]
            var pendingInstances: [(step: PipelineStep, instanceId: String)] = []
            var processorInstances: [String: ProcessorInstance] = [:]
            var failedInstances: Set<String> = []

            init(initialData: [String: Any]) {
                self.data = initialData
            }

            func addData(key: String, value: Any) {
                data[key] = value
            }

            func addStepOutputs(instanceId: String, outputs: [String: Any]) {
                // Add outputs with instance-specific keys
                // Each instance produces unique outputs (e.g., A on X produces U, A on Y produces V)
                for (outputName, outputData) in outputs {
                    let instanceKey = "\(instanceId).\(outputName)"
                    data[instanceKey] = outputData
                    // Also add with step ID for backward compatibility
                    // Extract step ID from instance ID (format: "stepId_instanceId")
                    if let stepIdEnd = instanceId.firstIndex(of: "_") {
                        let stepId = String(instanceId[..<stepIdEnd])
                        let stepKey = "\(stepId).\(outputName)"
                        data[stepKey] = outputData
                    }
                    // Also make available by output name alone for convenience
                    data[outputName] = outputData
                }
            }

            func getData() -> [String: Any] {
                return data
            }

            func addPendingInstance(step: PipelineStep, instanceId: String) {
                pendingInstances.append((step, instanceId))
            }

            func getPendingInstances() -> [(step: PipelineStep, instanceId: String)] {
                return pendingInstances
            }

            func removePendingInstance(instanceId: String) {
                pendingInstances.removeAll { $0.instanceId == instanceId }
            }

            func addProcessorInstance(_ instance: ProcessorInstance) {
                processorInstances[instance.instanceId] = instance
            }

            func getProcessorInstance(_ instanceId: String) -> ProcessorInstance? {
                return processorInstances[instanceId]
            }

            func markInstanceFailed(_ instanceId: String) {
                failedInstances.insert(instanceId)
            }

            func getFailedInstances() -> Set<String> {
                return failedInstances
            }
        }

        let dataStore = DataStore(initialData: inputs)

        // Create initial processor instances from pipeline configuration
        // For now, create one instance per step configuration
        // In the future, this will be driven by input data (e.g., one instance per input frame)
        var instanceCounter: [String: Int] = [:]
        for step in steps {
            let instanceId = generateInstanceId(stepId: step.id, instanceNumber: instanceCounter[step.id])
            instanceCounter[step.id, default: 0] += 1
            let instance = ProcessorInstance(instanceId: instanceId, step: step)
            await dataStore.addProcessorInstance(instance)
            await dataStore.addPendingInstance(step: step, instanceId: instanceId)
        }

        // Execute steps asynchronously, running in parallel when inputs are available
        try await withThrowingTaskGroup(of: (String, [String: Any]).self) { group in
            var runningInstances = Set<String>()

            // Continue until all instances are completed
            while true {
                // Check pending instances to see if any can now run
                let pendingInstances = await dataStore.getPendingInstances()
                let availableData = await dataStore.getData()
                let failedInstances = await dataStore.getFailedInstances()

                var readyInstances: [(step: PipelineStep, instanceId: String)] = []
                for (step, instanceId) in pendingInstances {
                    // Skip if already running
                    if runningInstances.contains(instanceId) {
                        continue
                    }

                    // Get the instance to check its status
                    if let instance = await dataStore.getProcessorInstance(instanceId) {
                        let currentStatus = await instance.getStatus()

                        // Check if this instance can run (all inputs available and no failed dependencies)
                        if canStepInstanceRun(
                            step: step,
                            instanceId: instanceId,
                            availableData: availableData,
                            failedInstances: failedInstances
                        ) && instance.canRun(availableData: availableData, currentStatus: currentStatus) {
                            readyInstances.append((step, instanceId))
                        }
                    }
                }

                // Start all ready instances in parallel
                for (step, instanceId) in readyInstances {
                    await dataStore.removePendingInstance(instanceId: instanceId)
                    runningInstances.insert(instanceId)

                    // Update instance status to running
                    if let instance = await dataStore.getProcessorInstance(instanceId) {
                        await instance.updateStatus(.running)
                        await instance.updateProgress(0.0)
                    }

                    group.addTask {
                        do {
                            // Get current available data
                            let currentData = await dataStore.getData()

                            // Resolve inputs and parameters for this instance
                            let resolvedInputs = try self.resolveDataInputs(for: step, from: currentData)
                            let resolvedParameters = self.resolveParameters(for: step, from: parameters)

                            // Update progress to indicate execution started
                            if let instance = await dataStore.getProcessorInstance(instanceId) {
                                await instance.updateProgress(0.1)
                            }

                            // Execute the step
                            // Note: step.execute is synchronous, but we're already in an async context
                            // so we can call it directly. If it's CPU-bound and long-running, consider
                            // using Task.detached, but that would require synchronization for ProcessorInstance.
                            let stepOutputs = try step.execute(
                                resolvedInputs: resolvedInputs,
                                resolvedParameters: resolvedParameters,
                                device: device,
                                commandQueue: commandQueue,
                                registry: registry
                            )

                            // Mark as completed
                            if let instance = await dataStore.getProcessorInstance(instanceId) {
                                await instance.updateProgress(1.0)
                                await instance.updateStatus(.completed)
                            }

                            return (instanceId, stepOutputs)
                        } catch {
                            // Check if error is fatal
                            let isFatal: Bool
                            if let processorError = error as? ProcessorExecutionError {
                                isFatal = processorError.isFatal
                            } else {
                                // Non-processor errors are considered fatal
                                isFatal = true
                            }

                            // Update instance status
                            if let instance = await dataStore.getProcessorInstance(instanceId) {
                                await instance.updateStatus(.failed(error))
                            }

                            if isFatal {
                                // Fatal error: stop entire pipeline
                                throw error
                            } else {
                                // Non-fatal error: mark instance as failed, continue pipeline
                                await dataStore.markInstanceFailed(instanceId)
                                // Return empty outputs to indicate failure
                                return (instanceId, [:])
                            }
                        }
                    }
                }

                // If no instances are ready and none are running, we're done
                if readyInstances.isEmpty && runningInstances.isEmpty {
                    break
                }

                // Wait for at least one instance to complete
                if let (completedInstanceId, outputs) = try await group.next() {
                    // Add step outputs to available data
                    await dataStore.addStepOutputs(instanceId: completedInstanceId, outputs: outputs)
                    runningInstances.remove(completedInstanceId)

                    // Continue loop to check if any pending instances can now run
                    continue
                }

                // If no instances are ready but some are running, wait for them
                if readyInstances.isEmpty && !runningInstances.isEmpty {
                    if let (completedInstanceId, outputs) = try await group.next() {
                        await dataStore.addStepOutputs(instanceId: completedInstanceId, outputs: outputs)
                        runningInstances.remove(completedInstanceId)
                    }
                }
            }

            // Wait for all remaining tasks to complete
            while let (completedInstanceId, outputs) = try await group.next() {
                await dataStore.addStepOutputs(instanceId: completedInstanceId, outputs: outputs)
            }
        }

        // Return all available data (includes both intermediate and final outputs)
        return await dataStore.getData()
    }
}

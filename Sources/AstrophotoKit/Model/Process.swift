import Foundation

/// Represents a process, i.e. a specific run of a processor.
public struct Process {

    /// The unique identifier for this process.
    public let identifier: UUID = UUID()

    /// The identifier of the processor that produced this process.
    public let processorIdentifier: String

    /// The input data names for this process.
    public let inputData: [ProcessDataLink]

    /// The parameters for this process.
    /// 
    /// The parameters are a dictionary of parameter names and values.
    public let parameters: [String: Parameter]

    /// The output data names for this process.
    public var outputData: [ProcessDataLink]

    /// The current status of this process.
    public var currentStatus: ProcessStatus {
        return statusHistory.first!
    }

    /// The history of the statuses of this process.
    /// 
    /// The history of the statuses is an array of statuses, 
    /// where the first status is the current status.
    /// The last status is the oldest status.
    public var statusHistory: [ProcessStatus] = []

    /// The date and time the process was created.
    public var createdAt: Date {
        for status in statusHistory {
            if case .pending(let date) = status {
                return date
            }
        }
        fatalError("Process must have a pending status in its history")
    }

    /// The date and time the process was started.
    public var startedAt: Date? { 
        for status in statusHistory {
            if case .running(let date, _) = status {
                return date
            }
        }
        return nil
    }

    /// The date and time the process was finished.
    public var finishedAt: Date? { 
        for status in statusHistory {
            if case .completed(let date) = status {
                return date
            } else if case .failed(let date, _) = status {
                return date
            }
        }
        return nil
    }

    public init(
        processorIdentifier: String,
        inputData: [String] = [],
        parameters: [String: Parameter] = [:],
        outputData: [String] = [],
    ) {
        self.processorIdentifier = processorIdentifier
        self.inputData = inputData.map { .input(process: self.identifier, link: $0) }
        self.parameters = parameters
        self.outputData = outputData.map { .output(process: self.identifier, link: $0) }
        self.statusHistory.append(.pending(date: Date()))
    }

    /// Add an output data name to this process.
    /// 
    /// The output data name is the name of the data that this process produces.
    /// - Parameter name: The name of the output data.
    public mutating func addOutputData(name: String) {
        self.outputData.append(.output(process: self.identifier, link: name))
    }
}

/// The status of a process.
public enum ProcessStatus {

    /// The process is pending.
    /// 
    /// The date and time the process was set to pending.
    case pending(date: Date)

    /// The process is running.
    /// 
    /// The date and time the process was set to running.
    case running(date: Date, progress: Progress)

    /// The process is paused.
    /// 
    /// The date and time the process was set to paused.
    case paused(date: Date)

    /// The process is resumed.
    /// 
    /// The date and time the process was set to resumed.
    case resumed(date: Date)

    /// The process is completed.
    /// 
    /// The date and time the process was set to completed.
    case completed(date: Date)

    /// The process is cancelled.
    /// 
    /// The date and time the process was set to cancelled.
    case cancelled(date: Date)

    /// The process failed.
    /// 
    /// The date and time the process was set to failed.
    /// The error that caused the process to fail.
    case failed(date: Date, error: Error)
}

/// The progress of a process.
public struct Progress {

    /// The progress value.
    /// 
    /// The progress value is a value between 0.0 and 1.0.
    var value: Double

    /// The date and time the progress was set.
    /// 
    /// The date and time the progress was set.
    var date: Date

    /// The progress message.
    /// 
    /// The progress message is a message describing the progress.
    var message: String
}

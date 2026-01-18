import Foundation
import os

/// The process stack for a pipeline.
/// 
/// The process stack is used to track the processes that are currently running in the pipeline.
public actor ProcessStack {
    private var processes: [Process] = []

    // Create
    public func add(process: Process) {
        self.processes.append(process)
        Logger.pipeline.debug("Added process \(process.identifier) to the process stack")
    }

    // Read
    public func getAll() -> [Process] {
        return processes
    }

    public func get(by identifier: UUID) -> Process? {
        return processes.first(where: { $0.identifier == identifier })
    }

    public func contains(identifier: UUID) -> Bool {
        return processes.contains(where: { $0.identifier == identifier })
    }

    // Delete
    public func remove(identifier: UUID) -> Bool {
        guard let index = processes.firstIndex(where: { $0.identifier == identifier }) else {
            return false
        }
        processes.remove(at: index)
        Logger.pipeline.debug("Removed process \(identifier) from the process stack")
        return true
    }

    public func removeAll() {
        processes.removeAll()
        Logger.pipeline.debug("Removed all processes from the process stack")
    }

    public func count() -> Int {
        return processes.count
    }

    // Get processes by status
    public func getPending() -> [Process] {
        return processes.filter {
            if case .pending = $0.currentStatus {
                return true
            }
            return false
        }
    }

    public func getRunning() -> [Process] {
        return processes.filter {
            if case .running = $0.currentStatus {
                return true
            }
            return false
        }
    }

    public func getPaused() -> [Process] {
        return processes.filter {
            if case .paused = $0.currentStatus {
                return true
            }
            return false
        }
    }

    public func getResumed() -> [Process] {
        return processes.filter {
            if case .resumed = $0.currentStatus {
                return true
            }
            return false
        }
    }

    public func getCompleted() -> [Process] {
        return processes.filter {
            if case .completed = $0.currentStatus {
                return true
            }
            return false
        }
    }

    public func getCancelled() -> [Process] {
        return processes.filter {
            if case .cancelled = $0.currentStatus {
                return true
            }
            return false
        }
    }

    public func getFailed() -> [Process] {
        return processes.filter {
            if case .failed = $0.currentStatus {
                return true
            }
            return false
        }
    }

    /// Get processes by a specific status
    /// - Parameter status: The status to filter by
    /// - Returns: Array of processes with the specified status
    public func get(by status: ProcessStatus) -> [Process] {
        return processes.filter { process in
            switch (process.currentStatus, status) {
            case (.pending, .pending),
                 (.running, .running),
                 (.paused, .paused),
                 (.resumed, .resumed),
                 (.completed, .completed),
                 (.cancelled, .cancelled),
                 (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }

    /// Get all pending processes for which all input data is available (has been instantiated)
    /// - Parameter dataStack: The data stack to check for input data availability
    /// - Parameter excludeProcesses: Optional set of process identifiers to exclude (already executed)
    /// - Returns: Array of pending processes that have all their input data instantiated
    public func getReadyPending(dataStack: DataStack, excludeProcesses: Set<UUID> = []) async -> [Process] {
        let pending = getPending()
        var ready: [Process] = []
        
        for process in pending {
            // Skip processes that have already been executed
            if excludeProcesses.contains(process.identifier) {
                continue
            }

            // Check if all input data links have corresponding instantiated data
            var allInputsReady = true
            
            for inputLink in process.inputData {
                // Find the ProcessData for this input link (converted to output link internally)
                guard let inputData = await dataStack.get(by: inputLink) else {
                    // Input data not found, so not ready
                    allInputsReady = false
                    break
                }
                
                // Check if the data is instantiated
                if !inputData.isInstantiated {
                    allInputsReady = false
                    break
                }
            }
            
            if allInputsReady {
                ready.append(process)
            }
        }
        
        return ready
    }
}


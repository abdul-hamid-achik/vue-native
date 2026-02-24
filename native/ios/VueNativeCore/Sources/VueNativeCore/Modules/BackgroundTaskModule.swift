#if canImport(UIKit)
import UIKit
import BackgroundTasks

/// Native module for scheduling background tasks using BGTaskScheduler.
///
/// Methods:
///   - scheduleTask(taskId, type, options) — schedule a background task
///   - cancelTask(taskId) — cancel a specific task
///   - cancelAllTasks() — cancel all scheduled tasks
///   - completeTask(taskId) — signal task completion from JS
///
/// Events:
///   - background:taskExecute — fired when a background task runs, payload: { taskId }
@available(iOS 13.0, *)
final class BackgroundTaskModule: NativeModule {
    var moduleName: String { "BackgroundTask" }
    private weak var bridge: NativeBridge?

    /// Track active tasks so we can call setTaskCompleted from JS
    private var activeTasks: [String: BGTask] = [:]

    /// Registered task identifiers
    private var registeredIdentifiers: Set<String> = []

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "scheduleTask":
            guard args.count >= 2,
                  let taskId = args[0] as? String,
                  let type = args[1] as? String else {
                callback(nil, "scheduleTask: missing taskId or type")
                return
            }
            let options = args.count >= 3 ? args[2] as? [String: Any] : nil
            scheduleTask(taskId: taskId, type: type, options: options ?? [:], callback: callback)

        case "cancelTask":
            guard let taskId = args.first as? String else {
                callback(nil, "cancelTask: missing taskId")
                return
            }
            BGTaskScheduler.shared.cancel(taskIdentifier: taskId)
            callback(nil, nil)

        case "cancelAllTasks":
            BGTaskScheduler.shared.cancelAllTaskRequests()
            callback(nil, nil)

        case "completeTask":
            guard let taskId = args.first as? String else {
                callback(nil, "completeTask: missing taskId")
                return
            }
            let success = (args.count >= 2 ? args[1] as? Bool : nil) ?? true
            if let task = activeTasks[taskId] {
                task.setTaskCompleted(success: success)
                activeTasks.removeValue(forKey: taskId)
            }
            callback(nil, nil)

        case "registerTask":
            guard let taskId = args.first as? String else {
                callback(nil, "registerTask: missing taskId")
                return
            }
            registerTaskHandler(taskId: taskId)
            callback(nil, nil)

        default:
            callback(nil, "BackgroundTaskModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Private

    private func registerTaskHandler(taskId: String) {
        guard !registeredIdentifiers.contains(taskId) else { return }
        registeredIdentifiers.insert(taskId)

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { [weak self] task in
            self?.handleTaskExecution(task: task)
        }
    }

    private func handleTaskExecution(task: BGTask) {
        let taskId = task.identifier
        activeTasks[taskId] = task

        task.expirationHandler = { [weak self] in
            self?.activeTasks[taskId]?.setTaskCompleted(success: false)
            self?.activeTasks.removeValue(forKey: taskId)
        }

        // Notify JS that the task is executing
        let bridge = bridge
        DispatchQueue.main.async {
            bridge?.dispatchGlobalEvent("background:taskExecute", payload: ["taskId": taskId])
        }
    }

    private func scheduleTask(taskId: String, type: String, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        // Ensure task handler is registered
        registerTaskHandler(taskId: taskId)

        let request: BGTaskRequest
        if type == "processing" {
            let processingRequest = BGProcessingTaskRequest(identifier: taskId)
            processingRequest.requiresNetworkConnectivity = options["requiresNetworkConnectivity"] as? Bool ?? false
            processingRequest.requiresExternalPower = options["requiresExternalPower"] as? Bool ?? false
            request = processingRequest
        } else {
            // Default: app refresh
            request = BGAppRefreshTaskRequest(identifier: taskId)
        }

        if let earliestBeginDate = options["earliestBeginDate"] as? Double {
            request.earliestBeginDate = Date(timeIntervalSince1970: earliestBeginDate / 1000.0)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            callback(nil, nil)
        } catch {
            callback(nil, "Failed to schedule task: \(error.localizedDescription)")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif

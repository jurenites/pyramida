import Cocoa
let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.hides = true
configuration.createsNewApplicationInstance = true
configuration.promptsUserIfNeeded = false
let mirror = CommandLine.arguments[1]
let script = CommandLine.arguments[2]
let logPath = CommandLine.arguments[3]
// Opt-in only when the user explicitly approves this particular visual check.
let allowActivation = CommandLine.arguments.dropFirst(4).contains("--allow-activation")
configuration.arguments = ["--audio-driver", "Dummy", "--path", mirror, "--script", script, "--log-file", logPath]
var target: NSRunningApplication?
var activated = false
let initial = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
let observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier == target?.processIdentifier { activated = true; if !allowActivation { app.terminate() } }
}
NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Godot.app"), configuration: configuration) { app, error in
    target = app
    if let error = error { print("Launch failed: \(error)"); exit(1) }
    if app?.isActive == true { activated = true; if !allowActivation { app?.terminate() } }
    print("Background render PID \(app?.processIdentifier ?? -1), active=\(app?.isActive ?? true), previous foreground=\(initial)")
}
let deadline = Date().addingTimeInterval(180)
while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    if let app = target, app.isTerminated {
        print("Finished. Renderer activated: \(activated). Foreground: \(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)")
        exit(activated && !allowActivation ? 1 : 0)
    }
}
target?.terminate(); print("Render timed out"); exit(1)

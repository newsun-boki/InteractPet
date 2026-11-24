import AppKit
import ApplicationServices

@main struct Probe {
    static func main() {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        if args.contains("--activate-chrome") || args.contains("--activate-textedit") {
            let bundle = args.contains("--activate-chrome") ? "com.google.Chrome" : "com.apple.TextEdit"
            NSRunningApplication.runningApplications(withBundleIdentifier:bundle).first?.activate(options:[.activateIgnoringOtherApps])
            RunLoop.current.run(until:Date(timeIntervalSinceNow:1))
        }
        if args.contains("--request-permission") {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        let seconds = args.contains("--watch") ? 20.0 : 0.0
        let reader = CaretReader()
        let start = Date()
        var previous = ""
        if args.contains("--click-fixture") {
            guard let front = NSWorkspace.shared.frontmostApplication,front.bundleIdentifier == "com.apple.TextEdit" else { print("fixture-lost-focus");return }
            let app = AXUIElementCreateApplication(front.processIdentifier)
            guard let win = axElement(axAttribute(app,kAXFocusedWindowAttribute)),
                  let title = axAttribute(win,kAXTitleAttribute) as? String,title.contains("octopus-caret-fixture"),
                  let position = axAttribute(win,kAXPositionAttribute),CFGetTypeID(position)==AXValueGetTypeID() else {print("fixture-window-not-focused");return}
            var point = CGPoint.zero
            AXValueGetValue(position as! AXValue,.cgPoint,&point)
            point.x += 380;point.y += 160
            CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
            CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
            print("Clicked the dedicated fixture at:",point)
            RunLoop.current.run(until:Date(timeIntervalSinceNow:0.6))
            return
        }
        if args.contains("--type-fixture") {
            for i in 0..<12 {
                guard let front = NSWorkspace.shared.frontmostApplication,front.bundleIdentifier == "com.apple.TextEdit" else { print("fixture-lost-focus"); return }
                let app = AXUIElementCreateApplication(front.processIdentifier)
                guard let win = axElement(axAttribute(app,kAXFocusedWindowAttribute)),
                      let title = axAttribute(win,kAXTitleAttribute) as? String,title.contains("octopus-caret-fixture") else { print("fixture-window-not-focused"); return }
                if i == 0,let el = axElement(axAttribute(app,kAXFocusedUIElementAttribute)) {
                    var r = CFRange(location:0,length:0)
                    if let v = AXValueCreate(.cfRange,&r) { AXUIElementSetAttributeValue(el,kAXSelectedTextRangeAttribute as CFString,v) }
                    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.25))
                }
                let down = CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:true)
                var letter = [UniChar]("aBc8!" .utf16)[i%5]
                down?.keyboardSetUnicodeString(stringLength:1,unicodeString:&letter)
                down?.post(tap:.cghidEventTap)
                CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:false)?.post(tap:.cghidEventTap)
                RunLoop.current.run(until:Date(timeIntervalSinceNow:0.15))
            }
            print("Typed 12 test keystrokes into the dedicated fixture only.")
            return
        }
        if args.contains("--exercise-textedit") {
            guard let front = NSWorkspace.shared.frontmostApplication,front.bundleIdentifier == "com.apple.TextEdit" else { print("fixture-not-focused"); return }
            let app = AXUIElementCreateApplication(front.processIdentifier)
            guard let win = axElement(axAttribute(app,kAXFocusedWindowAttribute)),
                  let title = axAttribute(win,kAXTitleAttribute) as? String,title.contains("octopus-caret-fixture"),
                  let el = axElement(axAttribute(app,kAXFocusedUIElementAttribute)) else { print("fixture-window-not-focused"); return }
            let original = axRange(el)
            for index in [0,8,20,27,33] {
                var range = CFRange(location:index,length:0)
                let value = AXValueCreate(.cfRange,&range)!
                let err = AXUIElementSetAttributeValue(el,kAXSelectedTextRangeAttribute as CFString,value)
                RunLoop.current.run(until:Date(timeIntervalSinceNow:0.15))
                let sample = reader.read()
                var output:[String:Any] = ["case":index,"setRangeError":err.rawValue,"status":sample.status,"app":sample.app]
                if let selected = axRange(el) { output["selectedIndex"] = selected.location }
                if let r = sample.rect { output["caret"] = ["x":r.minX,"y":r.minY,"width":r.width,"height":r.height] }
                if let r = axBounds(el,range:CFRange(location:index,length:1)) {
                    output["nextCharacterBounds"] = ["x":r.minX,"y":r.minY,"width":r.width,"height":r.height]
                }
                let data = try! JSONSerialization.data(withJSONObject:output,options:[.sortedKeys])
                print(String(data:data,encoding:.utf8)!)
            }
            if var r = original,let value = AXValueCreate(.cfRange,&r) { AXUIElementSetAttributeValue(el,kAXSelectedTextRangeAttribute as CFString,value) }
            return
        }
        if args.contains("--diagnose") {
            print("frontmost:",NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")
            let sys = AXUIElementCreateSystemWide()
            var debugValue: CFTypeRef?
            print("focused app error:", AXUIElementCopyAttributeValue(sys,kAXFocusedApplicationAttribute as CFString,&debugValue).rawValue)
            let fromPID = NSWorkspace.shared.frontmostApplication.map { AXUIElementCreateApplication($0.processIdentifier) }
            if let app = axElement(axAttribute(sys,kAXFocusedApplicationAttribute)) ?? fromPID {
                if args.contains("--enable-browser-accessibility") {
                    let e = AXUIElementSetAttributeValue(app,"AXEnhancedUserInterface" as CFString,kCFBooleanTrue)
                    print("enable AXEnhancedUserInterface:",e.rawValue)
                    RunLoop.current.run(until:Date(timeIntervalSinceNow:2.5))
                }
                if let el = axElement(axAttribute(app,kAXFocusedUIElementAttribute)) {
                    var names: CFArray?
                    let error = AXUIElementCopyParameterizedAttributeNames(el,&names)
                    print("parameter attributes:",error.rawValue,names as? [String] ?? [])
                    if let range = axRange(el) {
                        print("selected range:",range.location,range.length)
                        var request = range
                        let param = AXValueCreate(.cfRange,&request)!
                        var result: CFTypeRef?
                        let err = AXUIElementCopyParameterizedAttributeValue(el,kAXBoundsForRangeParameterizedAttribute as CFString,param,&result)
                        print("bounds status:",err.rawValue)
                        if let r = result,CFGetTypeID(r)==AXValueGetTypeID() {
                            var rect = CGRect.zero
                            AXValueGetValue(r as! AXValue,.cgRect,&rect)
                            print("raw rectangle:",rect)
                        }
                    }
                }
            }
        }
        repeat {
            let sample = reader.read()
            var output: [String:Any] = ["status":sample.status,"app":sample.app,"role":sample.role,
                                       "trusted":AXIsProcessTrusted(),"inputListening":CGPreflightListenEventAccess()]
            if let r = sample.rect { output["caret"] = ["x":r.minX,"y":r.minY,"width":r.width,"height":r.height] }
            if let data = try? JSONSerialization.data(withJSONObject:output,options:[.sortedKeys]),
               let string = String(data:data,encoding:.utf8),string != previous {
                print(string); fflush(stdout); previous = string
            }
            if seconds == 0 { break }
            RunLoop.current.run(until:Date(timeIntervalSinceNow:0.1))
        } while Date().timeIntervalSince(start) < seconds
    }
}

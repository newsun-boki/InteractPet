import AppKit
import ApplicationServices
import Carbon

struct CaretSample {
    var rect: CGRect?
    var app: String = ""
    var role: String = ""
    var status: String
    var time: Double = ProcessInfo.processInfo.systemUptime
}
func axAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element,name as CFString,&result) == .success else { return nil }
    return result
}
func axElement(_ value: CFTypeRef?) -> AXUIElement? {
    guard let value = value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}
func axRange(_ element: AXUIElement) -> CFRange? {
    guard let value = axAttribute(element,kAXSelectedTextRangeAttribute),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let ax = value as! AXValue
    guard AXValueGetType(ax) == .cfRange else { return nil }
    var range = CFRange()
    return AXValueGetValue(ax,.cfRange,&range) ? range : nil
}
func axBounds(_ element: AXUIElement, range: CFRange) -> CGRect? {
    var request = range
    guard let param = AXValueCreate(.cfRange,&request) else { return nil }
    var result: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element,kAXBoundsForRangeParameterizedAttribute as CFString,param,&result) == .success,
          let value = result, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let ax = value as! AXValue
    guard AXValueGetType(ax) == .cgRect else { return nil }
    var bounds = CGRect.zero
    guard AXValueGetValue(ax,.cgRect,&bounds), bounds.origin.x.isFinite,bounds.origin.y.isFinite,
          bounds.width.isFinite,bounds.height.isFinite,bounds.height >= 2,bounds.height < 160 else { return nil }
    return bounds
}
func appKitRect(fromAX rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x:rect.minX,y:primaryHeight-rect.maxY,width:rect.width,height:rect.height)
}
func axMarkerCaret(_ element: AXUIElement) -> CGRect? {
    guard let markers = axAttribute(element,"AXSelectedTextMarkerRange") else { return nil }
    var length: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element,"AXLengthForTextMarkerRange" as CFString,markers,&length) == .success,
          let count = length as? NSNumber, count.intValue == 0 else { return nil }
    var result: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element,"AXBoundsForTextMarkerRange" as CFString,markers,&result) == .success,
          let value = result,CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var r = CGRect.zero
    guard AXValueGetValue(value as! AXValue,.cgRect,&r),r.minX.isFinite,r.minY.isFinite,
          r.width >= 0,r.width <= 5,r.height >= 2,r.height < 160 else { return nil }
    return r
}
func axLine(_ element: AXUIElement,index: Int) -> Int? {
    var value: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element,kAXLineForIndexParameterizedAttribute as CFString,index as CFNumber,&value) == .success else { return nil }
    return (value as? NSNumber)?.intValue
}
func axCharacterEdge(_ element: AXUIElement,index: Int) -> CGRect? {
    // Geometric estimate, explicitly labelled as such. No text content is fetched.
    let next = axBounds(element,range:CFRange(location:index,length:1))
    let previous = index > 0 ? axBounds(element,range:CFRange(location:index-1,length:1)) : nil
    if let next = next,next.width > 0,next.width < 80 {
        var x = next.minX
        if let previous = previous,abs(next.minY-previous.minY) < 2,next.maxX <= previous.minX+1 { x = next.maxX }
        return CGRect(x:x,y:next.minY,width:1,height:next.height)
    }
    if let previous = previous,previous.width > 0,previous.width < 80 {
        let currentLine = axLine(element,index:index),priorLine = axLine(element,index:index-1)
        if currentLine != nil && currentLine == priorLine {
            return CGRect(x:previous.maxX,y:previous.minY,width:1,height:previous.height)
        }
    }
    return nil
}

final class CaretReader {
    var enabled = Set<pid_t>()
    // Runs on a serial background queue. Never reads AXValue / selected text strings.
    func read() -> CaretSample {
        guard AXIsProcessTrusted() else { return CaretSample(status:"permission-required") }
        guard !IsSecureEventInputEnabled() else { return CaretSample(status:"secure-input") }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system,0.3)
        let foreground = NSWorkspace.shared.frontmostApplication
        let fromPID = foreground.map { AXUIElementCreateApplication($0.processIdentifier) }
        guard let app = axElement(axAttribute(system,kAXFocusedApplicationAttribute)) ?? fromPID else {
            return CaretSample(status:"no-focused-app")
        }
        AXUIElementSetMessagingTimeout(app,0.2)
        var pid: pid_t = 0
        AXUIElementGetPid(app,&pid)
        let name = NSRunningApplication(processIdentifier:pid)?.bundleIdentifier ?? "unknown"
        if !enabled.contains(pid),["com.google.Chrome","com.openai.codex","com.todesktop.230313mzl4w4u92","com.microsoft.VSCode","com.electron"].contains(where:{name.hasPrefix($0)}) {
            enabled.insert(pid)
            let manual = AXUIElementSetAttributeValue(app,"AXManualAccessibility" as CFString,kCFBooleanTrue)
            if manual != .success { _ = AXUIElementSetAttributeValue(app,"AXEnhancedUserInterface" as CFString,kCFBooleanTrue) }
        }
        guard let focused = axElement(axAttribute(app,kAXFocusedUIElementAttribute)) else {
            return CaretSample(app:name,status:"no-focused-element")
        }
        AXUIElementSetMessagingTimeout(focused,0.2)
        let role = axAttribute(focused,kAXRoleAttribute) as? String ?? ""
        let subrole = axAttribute(focused,kAXSubroleAttribute) as? String ?? ""
        guard subrole != kAXSecureTextFieldSubrole else { return CaretSample(app:name,role:role,status:"secure-input") }
        guard let range = axRange(focused) else {
            if let bounds = axMarkerCaret(focused) { return CaretSample(rect:bounds,app:name,role:role,status:"exact-marker") }
            return CaretSample(app:name,role:role,status:"range-unavailable")
        }
        // Do not guess which end of a non-empty selection is the insertion end.
        guard range.length == 0 else { return CaretSample(app:name,role:role,status:"selection-active") }
        guard let bounds = axBounds(focused,range:range), bounds.width <= 5 else {
            if let bounds = axMarkerCaret(focused) { return CaretSample(rect:bounds,app:name,role:role,status:"exact-marker") }
            if let bounds = axCharacterEdge(focused,index:range.location) { return CaretSample(rect:bounds,app:name,role:role,status:"character-edge") }
            return CaretSample(app:name,role:role,status:"caret-bounds-unavailable")
        }
        return CaretSample(rect:bounds,app:name,role:role,status:"exact")
    }
}

final class CaretTracker {
    let queue = DispatchQueue(label:"local.tarooctopus.caret",qos:.userInitiated)
    let reader = CaretReader()
    var timer: DispatchSourceTimer?
    var onSample: ((CaretSample)->Void)?
    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue:queue)
        t.schedule(deadline:.now(),repeating:.milliseconds(50),leeway:.milliseconds(8))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            let sample = self.reader.read()
            DispatchQueue.main.async { self.onSample?(sample) }
        }
        timer = t; t.resume()
    }
    func stop() { timer?.cancel(); timer = nil }
}

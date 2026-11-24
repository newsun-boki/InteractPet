import AppKit
import ApplicationServices
import Carbon

@main struct WeChatCapabilities {
    static func main() {
        _ = NSApplication.shared
        for bundle in ["com.tencent.xinWeChat","com.tencent.WeChat"] {
            guard let process = NSRunningApplication.runningApplications(withBundleIdentifier:bundle).first else { continue }
            let app = AXUIElementCreateApplication(process.processIdentifier)
            AXUIElementSetMessagingTimeout(app,0.4)
            var focus: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(app,kAXFocusedUIElementAttribute as CFString,&focus)
            var result:[String:Any] = ["app":bundle,"trusted":AXIsProcessTrusted(),"focusedElementError":error.rawValue]
            if let el = axElement(focus) {
                result["role"] = axAttribute(el,kAXRoleAttribute) as? String ?? ""
                result["subrole"] = axAttribute(el,kAXSubroleAttribute) as? String ?? ""
                var attrs: CFArray?,params: CFArray?
                AXUIElementCopyAttributeNames(el,&attrs)
                AXUIElementCopyParameterizedAttributeNames(el,&params)
                result["attributes"] = attrs as? [String] ?? []
                result["parameterizedAttributes"] = params as? [String] ?? []
                result["hasSelectionRange"] = axRange(el) != nil
                if let range = axRange(el) {
                    result["hasCaretBounds"] = axBounds(el,range:range) != nil
                }
                result["hasTextMarkerCaret"] = axMarkerCaret(el) != nil
            }
            let data = try! JSONSerialization.data(withJSONObject:result,options:[.sortedKeys,.prettyPrinted])
            print(String(data:data,encoding:.utf8)!)
        }
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let raw = TISGetInputSourceProperty(source,kTISPropertyInputSourceID) {
            let id = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue()
            print("currentInputSource:",id)
        }
    }
}

import AppKit
import CoreGraphics

@main struct ScreenGeometryProbe {
    static func main() {
        _ = NSApplication.shared
        let screens = NSScreen.screens,top = screens.first?.frame.maxY ?? 0
        func rect(_ r: CGRect) -> [String:Double] { ["x":r.minX,"y":r.minY,"width":r.width,"height":r.height] }
        let result = screens.map { s -> [String:Any] in
            let id = (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
            let corners = [V(s.frame.minX,s.frame.minY),V(s.frame.maxX,s.frame.maxY)]
            let error = corners.map { p in let ax = V(p.x,top-p.y);return (V(ax.x,top-ax.y)-p).length }.max() ?? 0
            precondition(error < 0.001 && s.frame.contains(s.visibleFrame))
            return ["id":id,"name":s.localizedName,"framePoints":rect(s.frame),"usablePoints":rect(s.visibleFrame),
                    "backingScale":s.backingScaleFactor,"pixelWidth":CGDisplayPixelsWide(id),"pixelHeight":CGDisplayPixelsHigh(id),
                    "coordinateRoundTripError":error]
        }
        let data = try! JSONSerialization.data(withJSONObject:["screens":result,"passed":!screens.isEmpty],options:[.prettyPrinted,.sortedKeys])
        if CommandLine.arguments.count > 1 { try! data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]),options:.atomic) }
        print(String(data:data,encoding:.utf8)!)
    }
}

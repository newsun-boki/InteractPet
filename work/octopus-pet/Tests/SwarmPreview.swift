import AppKit
@main struct SwarmPreview {
    static func frame(_ m:SwarmMotion,_ r:SwarmRenderer,_ style:SwarmStyle) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:540,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g;let c = g.cgContext
        c.setFillColor(skinColor("#151C2C"));c.fill(CGRect(x:0,y:0,width:960,height:540))
        func text(_ t:String,_ x:Double,_ y:Double,_ size:Double,_ color:String) { (t as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor(color)]) }
        text("INTERACTPET / 16 COURIERS",36,488,12,"#A5ADC7");text(style.name,36,442,27,"#F1EAF8")
        c.addPath(CGPath(roundedRect:CGRect(x:230,y:260,width:500,height:80),cornerWidth:18,cornerHeight:18,transform:nil));c.setFillColor(skinColor("#242D42"));c.fillPath()
        text("hello, little lights",260,289,21,"#F0E7F7")
        c.setFillColor(skinColor("#C9BBF5"));c.fill(CGRect(x:560,y:285,width:2,height:25))
        r.draw(m,in:c)
        text("从四边飞入  ·  携带字母  ·  聚拢发光  ·  轻轻散开",36,45,16,"#B8B4CD")
        NSGraphicsContext.restoreGraphicsState();return rep.representation(using:.png,properties:[:])!
    }
    static func main() throws {
        _ = NSApplication.shared
        let out = URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let r = SwarmRenderer()
        for style in SwarmStyle.allCases {
            let m = SwarmMotion();m.select(style);m.layout([CGRect(x:0,y:0,width:960,height:540)]);m.scale = 1.25
            let pipe = Pipe(),encoder = Process();encoder.executableURL = URL(fileURLWithPath:"/usr/bin/env")
            encoder.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30","-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","19","-pix_fmt","yuv420p",out.appendingPathComponent(style.rawValue+".mp4").path]
            encoder.standardInput = pipe;try encoder.run()
            for f in 0..<180 {
                if [3,17,31].contains(f) { let id = m.emit(at:V(560,285))!;_ = m.accept(f==3 ? "f" : f==17 ? "l" : "y",for:id) }
                if f==108 { _ = m.emit(at:V(380,195),click:true) }
                m.step(1.0/60);m.step(1.0/60)
                let data = frame(m,r,style);pipe.fileHandleForWriting.write(data)
                if [20,53,83,165].contains(f) { try data.write(to:out.appendingPathComponent(style.rawValue+"-\(f).png")) }
            }
            try pipe.fileHandleForWriting.close();encoder.waitUntilExit();precondition(encoder.terminationStatus==0)
            print("Rendered",style.rawValue)
        }
    }
}

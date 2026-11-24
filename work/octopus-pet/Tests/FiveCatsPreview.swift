import AppKit

@main struct FiveCatsPreview {
    static func text(_ value: String,_ x:Double,_ y:Double,_ size:Double) {
        (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor("#705449")])
    }
    static func frame(_ m:PetMotion,_ renderer:PetRenderer,_ stage:String) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1280,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g
        let c = g.cgContext;c.setFillColor(skinColor("#FFF9F2"));c.fill(CGRect(x:0,y:0,width:1280,height:720))
        text("五只小猫 · 排排坐",45,646,34);text(stage,45,603,20)
        c.setFillColor(skinColor("#FFFFFF"));c.fill(m.boundary.frame)
        c.setStrokeColor(skinColor("#E8D6C9"));c.setLineWidth(1.5);c.stroke(m.boundary.frame)
        if let target = m.target {
            text("hello, kittens",90,440,22)
            c.setFillColor(skinColor("#B28975"));c.fill(CGRect(x:target.x,y:target.y,width:2,height:23))
        }
        renderer.draw(m,in:c)
        text("同一个节奏轻轻摇 · 五只轮流伸爪 · 可单独关闭摇摆",45,42,20)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using:.png,properties:[:])!
    }
    static func main() throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments,assets = URL(fileURLWithPath:args[1]),out = URL(fileURLWithPath:args[2])
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let skin = PetSkin.catalog(in:assets).first {$0.id == "five-kittens"}!
        let r = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"));precondition(r.setSkin(skin,resources:assets))
        precondition(r.fiveCatsArtwork?.sourceRects.count == 5)
        let m = PetMotion();m.configure(.fivecats);m.scale = 1.6
        m.place(frame:CGRect(x:40,y:110,width:1200,height:450),visible:CGRect(x:40,y:110,width:1200,height:450),enter:true)
        let pipe = Pipe(),encoder = Process();encoder.executableURL = URL(fileURLWithPath:"/usr/bin/env")
        encoder.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30","-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",out.appendingPathComponent("five-kittens-motion.mp4").path]
        encoder.standardInput = pipe;try encoder.run()
        for f in 0..<360 {
            let t = Double(f)/30
            if f >= 150 && f < 270 {
                m.target = V(250,400)
                if f%9 == 0 {
                    let i = m.nextArm;m.input(at:t)
                    _ = m.arms[i].acceptGlyph(String(Array("hello")[i]),forStrike:m.arms[i].strikeCount,at:t)
                }
            } else { m.target = nil }
            if f == 270 { m.fiveCats.swayEnabled = false }
            for s in 0..<2 { m.step(to:t+Double(s)/60,dt:1.0/60) }
            let data = frame(m,r,f < 150 ? "一起摇摆 · 耳朵轻动，眨眼错开" : f < 270 ? "摇摆不停 · 轮流递来小字牌" : "关闭摇摆 · 安静坐好")
            pipe.fileHandleForWriting.write(data)
            if f%30 == 0 || [40,79,80,81].contains(f) { try data.write(to:out.appendingPathComponent(String(format:"five-kittens-%03d.png",f))) }
        }
        try pipe.fileHandleForWriting.close();encoder.waitUntilExit();precondition(encoder.terminationStatus == 0)
        let boxes = r.fiveCatsArtwork!.sourceRects.map {[$0.minX,$0.minY,$0.width,$0.height]}
        try JSONSerialization.data(withJSONObject:["atlasRects":boxes,"frames":360,"fps":30,"version":"0.7.0"],options:.prettyPrinted).write(to:out.appendingPathComponent("preview-info.json"))
        print("Rendered five kittens: synchronized sway, blinking, delivery and sway-off; 12-second native video")
    }
}

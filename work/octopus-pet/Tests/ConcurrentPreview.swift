import AppKit

@main struct ConcurrentPreview {
    static func text(_ value: String,_ x: Double,_ y: Double,_ size: Double) {
        (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor("#634B72")])
    }
    static func frame(_ m: PetMotion,_ renderer: PetRenderer,_ title: String,_ mode: Int,_ target: V) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:540,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g
        let c = g.cgContext
        c.setFillColor(skinColor("#FAF6FC"));c.fill(CGRect(x:0,y:0,width:960,height:540))
        text(title+" · "+["边走边送字","边爬边送字","点击也不中断动作"][mode],30,492,26)
        c.setFillColor(skinColor("#FFFFFF"));c.fill(m.boundary.frame)
        c.setStrokeColor(skinColor("#D7C3E2"));c.setLineWidth(2);c.stroke(m.boundary.frame)
        c.setFillColor(skinColor("#F4EDF8"));c.fill(CGRect(x:92,y:250,width:340,height:136))
        text(mode == 2 ? "点击这里" : "正在输入：hello",115,351,19)
        c.setStrokeColor(skinColor("#9366AC"));c.setLineWidth(2)
        if mode == 2 { c.strokeEllipse(in:CGRect(x:target.x-12,y:target.y-12,width:24,height:24)) }
        else { c.move(to:target.point);c.addLine(to:(target+V(0,22)).point);c.strokePath() }
        renderer.draw(m,in:c)
        text("移动和递送同时进行 · 身体移动时，连接点随身体更新",30,18,17)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using:.png,properties:[:])!
    }
    static func main() throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments,assets = URL(fileURLWithPath:args[1]),out = URL(fileURLWithPath:args[2]),id = args[3]
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let skin = PetSkin.catalog(in:assets).first {$0.id == id}!
        let renderer = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"));_ = renderer.setSkin(skin,resources:assets)
        let m = PetMotion();m.configure(skin.form)
        m.place(frame:CGRect(x:30,y:56,width:900,height:418),visible:CGRect(x:30,y:56,width:900,height:418),enter:false);m.boundary.showcase()
        var t = 0.0
        func step() { t += 1.0/60;m.step(to:t,dt:1.0/60) }
        for _ in 0..<90 { step() }
        let pipe = Pipe(),encoder = Process()
        encoder.executableURL = URL(fileURLWithPath:"/usr/bin/env")
        encoder.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30","-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",out.appendingPathComponent(id+"-concurrent.mp4").path]
        encoder.standardInput = pipe;try encoder.run()
        for mode in 0..<3 {
            if mode == 1 {
                m.invalidateTarget(all:true)
                while m.boundary.phase != .climbing || m.boundary.elapsed < 3.2 { step() }
            }
            let target = mode == 2 ? V(285,285) : V(215,300)
            m.target = mode == 2 ? nil : target
            for f in 0..<90 {
                if mode < 2 && f%6 == 0 {
                    let i = m.nextArm;m.input(at:t)
                    _ = m.arms[i].acceptGlyph(String(Array("hello")[(f/6)%5]),forStrike:m.arms[i].strikeCount,at:t)
                }
                if mode == 2 && f == 0 { m.click(at:target,time:t) }
                step();step()
                let data = frame(m,renderer,skin.name,mode,target)
                pipe.fileHandleForWriting.write(data)
                if [0,45,89].contains(f) { try data.write(to:out.appendingPathComponent("\(id)-concurrent-\(mode)-\(f).png")) }
            }
        }
        try pipe.fileHandleForWriting.close();encoder.waitUntilExit();precondition(encoder.terminationStatus == 0)
        print("Rendered \(id): 9 seconds of simultaneous walking/climbing and typing/clicking")
    }
}

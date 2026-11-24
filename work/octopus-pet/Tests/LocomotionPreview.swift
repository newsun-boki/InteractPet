import AppKit

@main struct LocomotionPreview {
    static func png(_ draw:(CGContext)->Void) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:540,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g
        draw(g.cgContext);NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using:.png,properties:[:])!
    }
    static func text(_ string:String,_ x:Double,_ y:Double,_ size:Double) {
        (string as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor("#594366")])
    }
    static func frame(_ m:PetMotion,_ renderer:PetRenderer,_ name:String,_ stage:String) -> Data {
        png { c in
            c.setFillColor(skinColor("#FAF6FC"));c.fill(CGRect(x:0,y:0,width:960,height:540))
            text(name+" · "+stage,25,490,26)
            text("角色实际渲染",25,454,17);text("动作辅助观察",505,454,17)
            for panel in 0..<2 {
                c.saveGState();c.clip(to:CGRect(x:panel*480,y:50,width:480,height:390))
                c.translateBy(x:Double(panel*480+240),y:260)
                let zoom = m.kind == .jellyfish ? 1.65 : 2.0
                c.scaleBy(x:zoom,y:zoom);c.translateBy(x:-m.body.x,y:-m.body.y)
                c.setStrokeColor(skinColor("#D4C3DE"));c.setLineWidth(1)
                if m.locomotion.onWall {
                    c.move(to:CGPoint(x:m.boundary.area.maxX,y:m.body.y-150));c.addLine(to:CGPoint(x:m.boundary.area.maxX,y:m.body.y+150))
                    for y in stride(from:floor((m.body.y-150)/20)*20,to:m.body.y+150,by:20) {
                        c.move(to:CGPoint(x:m.boundary.area.maxX,y:y));c.addLine(to:CGPoint(x:m.boundary.area.maxX+4,y:y))
                    }
                } else {
                    c.move(to:CGPoint(x:m.body.x-150,y:m.boundary.area.minY));c.addLine(to:CGPoint(x:m.body.x+150,y:m.boundary.area.minY))
                    for x in stride(from:floor((m.body.x-150)/20)*20,to:m.body.x+150,by:20) {
                        c.move(to:CGPoint(x:x,y:m.boundary.area.minY));c.addLine(to:CGPoint(x:x,y:m.boundary.area.minY-4))
                    }
                }
                c.strokePath();renderer.draw(m,in:c)
                if panel == 1 && m.locomotion.weight > 0.01 {
                    for pose in m.locomotion.poses {
                        c.setStrokeColor(skinColor("#5B426D",0.7));c.setLineWidth(1)
                        c.move(to:pose.root.point);c.addLine(to:pose.knee.point);c.addLine(to:pose.tip.point);c.strokePath()
                        for point in [pose.root,pose.knee] { c.setFillColor(skinColor("#654576"));c.fillEllipse(in:CGRect(x:point.x-2,y:point.y-2,width:4,height:4)) }
                        c.setFillColor(skinColor(pose.planted ? "#25A47C" : "#E98B39"));c.fillEllipse(in:CGRect(x:pose.tip.x-3,y:pose.tip.y-3,width:6,height:6))
                    }
                }
                c.restoreGState()
            }
            let caption = !m.boundary.enabled ? "行走已关闭 · 呼吸与送字保留" : m.locomotion.poses.isEmpty ? "柔软身体随运动轻轻起伏" : m.locomotion.weight < 0.01 ? "休息中 · 呼吸与送字保留" : "绿点：支撑固定   橙点：抬起摆动"
            text(caption,505,24,17)
        }
    }
    static func main() throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments,assets = URL(fileURLWithPath:args[1]),out = URL(fileURLWithPath:args[2])
        let selected = args.count > 3 ? args[3] : "chameleon"
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let skin = PetSkin.catalog(in:assets).first {$0.id == selected}!
        let renderer = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"));_ = renderer.setSkin(skin,resources:assets)
        let m = PetMotion();m.configure(skin.form);m.place(frame:CGRect(x:0,y:0,width:1000,height:700),visible:CGRect(x:0,y:0,width:1000,height:700),enter:false);m.boundary.showcase()
        var t = 0.0
        func step() { t += 1.0/60;m.step(to:t,dt:1.0/60) }
        for _ in 0..<90 { step() }
        let started = Date()
        if args.contains("--benchmark") {
            let c = CGContext(data:nil,width:600,height:600,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            for _ in 0..<300 {
                step();c.clear(CGRect(x:0,y:0,width:600,height:600));c.saveGState()
                c.translateBy(x:300,y:300);c.scaleBy(x:2,y:2);c.translateBy(x:-m.body.x,y:-m.body.y)
                renderer.draw(m,in:c);c.restoreGState()
            }
            print("\(selected): 300 native Retina frames, mean \((Date().timeIntervalSince(started)/300*1000).rounded()) ms/frame")
            return
        }
        let video = args.contains("--video")
        let routine = args.contains("--routine")
        let filename = selected+(routine ? "-routine" : "")
        let pipe = Pipe(),encoder = Process()
        if video {
            encoder.executableURL = URL(fileURLWithPath:"/usr/bin/env")
            encoder.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30","-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",out.appendingPathComponent(filename+".mp4").path]
            encoder.standardInput = pipe;try encoder.run()
        }
        for mode in 0..<(routine ? 1 : 3) {
            if mode == 1 { while m.boundary.phase != .climbing || m.boundary.elapsed < 3.2 { step() } }
            if mode == 2 { m.setLocomotionEnabled(false);for _ in 0..<90 { step() } }
            for f in 0..<(routine ? 1260 : 90) {
                step();step()
                if video || f%(routine ? 30 : 10) == 0 {
                    let label = routine ? m.boundary.phase.rawValue+String(format:" · %.1f s",t) : [m.boundary.floating ? "漂浮循环" : "行走循环",m.boundary.floating ? "沿边游动" : "攀爬循环","关闭走路：静止待机"][mode]
                    let data = frame(m,renderer,skin.name,label)
                    if video { pipe.fileHandleForWriting.write(data) }
                    if f%(routine ? 30 : 10) == 0 { try data.write(to:out.appendingPathComponent("\(filename)-\(mode)-\(f/(routine ? 30 : 10)).png")) }
                }
            }
        }
        if video { try pipe.fileHandleForWriting.close();encoder.waitUntilExit();precondition(encoder.terminationStatus == 0) }
        print("Rendered \(filename), \(routine ? 42 : 27) sampled poses\(video ? " and motion video" : "") in \(Date().timeIntervalSince(started)) s")
    }
}

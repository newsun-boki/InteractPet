import AppKit

@main struct CatGroupPreview {
    static func text(_ s: String,_ x:Double,_ y:Double,_ size:Double) {
        (s as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor("#705449")])
    }
    static func drawBones(_ m: PetMotion,_ c: CGContext) {
        func point(_ p: V) -> CGPoint { (m.body+p*m.scale).point }
        for rig in m.fiveCats.rigs {
            c.setLineWidth(1.4);c.setStrokeColor(skinColor("#167F88",0.9))
            let s = rig.spine.map {point(rig.localToGroup($0))}
            c.move(to:s[0]);c.addCurve(to:s[3],control1:s[1],control2:s[2]);c.strokePath()
            c.move(to:point(rig.localToGroup(rig.head.a)));c.addLine(to:point(rig.localToGroup(rig.head.b)));c.strokePath()
            let tail = rig.tail.map {point(rig.localToGroup($0))}
            c.move(to:tail[0]);c.addCurve(to:tail[3],control1:tail[1],control2:tail[2]);c.strokePath()
            for leg in rig.legs {
                let joints = [leg.root,leg.knee,leg.tip].map {point(rig.localToGroup($0))}
                c.setStrokeColor(skinColor("#147E89",0.9));c.move(to:joints[0]);c.addLine(to:joints[1]);c.addLine(to:joints[2]);c.strokePath()
                for (j,p) in joints.enumerated() {
                    c.setFillColor(skinColor(j == 2 ? leg.planted ? "#1CA06D" : "#EF824D" : "#147E89"))
                    c.fillEllipse(in:CGRect(x:p.x-2.2,y:p.y-2.2,width:4.4,height:4.4))
                }
            }
        }
    }
    static func frame(_ m: PetMotion,_ r: PetRenderer,_ title:String,_ bones: Bool = false) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1280,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g
        let c = g.cgContext;c.setFillColor(skinColor("#FFF9F2"));c.fill(CGRect(x:0,y:0,width:1280,height:720))
        text("五只小猫 · 骨骼与屏幕互动",42,647,32);text(title,42,606,19)
        c.setFillColor(skinColor("#FFFFFF"));c.fill(m.boundary.area)
        c.setStrokeColor(skinColor("#DCC4B5"));c.setLineWidth(2);c.stroke(m.boundary.area)
        if m.target != nil { text("hello, little team",85,440,20) }
        r.draw(m,in:c)
        if bones { drawBones(m,c) }
        text(bones ? "青线：骨骼与 spline · 绿点：支撑足 · 橙点：摆动足" : "依次跟随 · 起跳扒边 · 队友回应 · 行动中照样递字",42,48,19)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using:.png,properties:[:])!
    }
    static func main() throws {
        _ = NSApplication.shared
        let a = CommandLine.arguments,assets = URL(fileURLWithPath:a[1]),out = URL(fileURLWithPath:a[2]),video = a.contains("--video")
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let r = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"))
        precondition(r.setSkin(PetSkin.catalog(in:assets).first {$0.id == "five-kittens"}!,resources:assets))
        let m = PetMotion();m.configure(.fivecats);m.scale = 1.5
        m.place(frame:CGRect(x:40,y:110,width:1200,height:450),visible:CGRect(x:40,y:110,width:1200,height:450),enter:false)
        let encoder = Process(),pipe = Pipe()
        if video {
            encoder.executableURL = URL(fileURLWithPath:"/usr/bin/env")
            encoder.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30","-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",out.appendingPathComponent("five-cats-group-motion.mp4").path]
            encoder.standardInput = pipe;try encoder.run()
        }
        let samples: Set<Int> = [0,30,75,90,120,150,180,225,270,330,390,420,450,480,510,540,570,630,660,690,720,750,810,840,870]
        var maxRender = 0.0,totalRender = 0.0,renderCount = 0
        for f in 0..<900 {
            let t = Double(f)/30
            if f == 45 { m.fiveCats.formation.showcase() }
            if f == 810 { m.setLocomotionEnabled(false) }
            if (f >= 240 && f < 315) || (f >= 495 && f < 645) {
                m.target = V(260,410)
                if f%9 == 0 { let i = m.nextArm;m.input(at:t);_ = m.arms[i].acceptGlyph(String(Array("hello")[i]),forStrike:m.arms[i].strikeCount,at:t) }
            } else { m.target = nil }
            for s in 0..<2 { m.step(to:t+Double(s)/60,dt:1.0/60) }
            let stage = !m.boundary.enabled ? "关闭屏幕互动 · 回到排排坐，保留摇摆与递字" : m.fiveCats.formation.phase == .walking ? "领队迈步，队友依次跟随 · 四肢交替落脚" : m.fiveCats.formation.phase == .edge ? "右侧小猫起跳、攀爬、探头 · 其他猫抬头与抬爪回应" : "同步摇摆 · 头、脊柱、耳朵与尾巴分别运动"
            if video || samples.contains(f) {
                let start = ProcessInfo.processInfo.systemUptime,data = frame(m,r,stage)
                let duration = ProcessInfo.processInfo.systemUptime-start;maxRender = max(maxRender,duration);totalRender += duration;renderCount += 1
                if video { pipe.fileHandleForWriting.write(data) }
                if samples.contains(f) {
                    try data.write(to:out.appendingPathComponent(String(format:"group-%03d.png",f)))
                    if [90,150,450,540].contains(f) { try frame(m,r,stage,true).write(to:out.appendingPathComponent(String(format:"rig-%03d.png",f))) }
                }
            }
        }
        if video { try pipe.fileHandleForWriting.close();encoder.waitUntilExit();precondition(encoder.terminationStatus == 0) }
        let info: [String:Any] = ["version":"0.8.0","video":video,"seconds":30,"frames":900,"fps":30,"pngEncodeIncludedInTiming":true,"averageRenderMS":totalRender/Double(renderCount)*1000,"maxRenderMS":maxRender*1000]
        try JSONSerialization.data(withJSONObject:info,options:.prettyPrinted).write(to:out.appendingPathComponent("preview-info.json"))
        print(info)
    }
}

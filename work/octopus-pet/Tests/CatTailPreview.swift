import AppKit

@main struct CatTailPreview {
    static func text(_ s: String,_ x:Double,_ y:Double,_ size:Double) {
        (s as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor("#705449")])
    }
    static func frame(_ m: PetMotion,_ r: PetRenderer,_ detail: Bool,_ time: Double,_ debug: Bool = false) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1280,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g
        let c = g.cgContext;c.setFillColor(skinColor("#FFF9F2"));c.fill(CGRect(x:0,y:0,width:1280,height:720))
        text(detail ? "五只小猫 · 尾巴小剧场" : "尾巴来递字 · 小队继续活动",42,647,32)
        if detail {
            let index = min(4,Int(time/3.6)),arm = m.arms[index]
            let names = ["橘猫 · 轻轻扫尾","奶油猫 · 问号卷尾","银灰猫 · 尾尖打个卷","三花猫 · 活泼甩尾","黑白猫 · 尾尖慢半拍"]
            text(names[index],42,607,20)
            c.saveGState();c.clip(to:CGRect(x:40,y:95,width:1200,height:490))
            let pivot = m.body+m.fiveCats.pivot(index)*m.scale
            c.translateBy(x:720,y:155);c.scaleBy(x:2.7,y:2.7);c.translateBy(x:-pivot.x,y:-pivot.y)
            r.drawArm(arm,scale:m.scale,context:c);r.drawCatMember(m,index:index,context:c)
            if debug {
                c.setStrokeColor(skinColor("#16848B",0.7));c.setLineWidth(0.6)
                let knots = arm.catTail!.controls;c.move(to:knots[0].point)
                for p in knots.dropFirst() { c.addLine(to:p.point) };c.strokePath()
                for p in knots { c.setFillColor(skinColor("#16848B"));c.fillEllipse(in:CGRect(x:p.x-1.6,y:p.y-1.6,width:3.2,height:3.2)) }
            }
            c.restoreGState()
            text(debug ? "八个控制点 · 弹簧滞后 · 连续 spline" : "轻扫、问号卷尾、绕尾、甩尾 · 每只猫略有不同",42,45,19)
        } else {
            text(!m.fiveCats.tailPlayEnabled ? "关闭待机小动作 · 仍能伸尾递字" : m.fiveCats.formation.phase == .edge ? "攀爬时尾巴仍能递字 · 尾根跟随身体" : "尾根预摆 → 伸长送字 → 尾尖轻点 → 卷回身边",42,607,20)
            c.setFillColor(skinColor("#FFFFFF"));c.fill(m.boundary.area)
            c.setStrokeColor(skinColor("#DCC4B5"));c.setLineWidth(2);c.stroke(m.boundary.area)
            if m.target != nil { text("hello, little tails",85,450,21) }
            r.draw(m,in:c)
            text("字牌由小卷尾托住，离输入位置留出距离 · 走路、攀爬不被打断",42,45,18)
        }
        NSGraphicsContext.restoreGraphicsState();return rep.representation(using:.png,properties:[:])!
    }
    static func main() throws {
        _ = NSApplication.shared
        let a = CommandLine.arguments,assets = URL(fileURLWithPath:a[1]),out = URL(fileURLWithPath:a[2]),video = a.contains("--video"),detail = a.contains("--detail")
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let r = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"));precondition(r.setSkin(PetSkin.catalog(in:assets).first {$0.id == "five-kittens"}!,resources:assets))
        let m = PetMotion();m.configure(.fivecats);m.scale = 1.3;m.setLocomotionEnabled(!detail)
        m.place(frame:CGRect(x:40,y:110,width:1200,height:450),visible:CGRect(x:40,y:110,width:1200,height:450),enter:false)
        if !detail { m.fiveCats.formation.showcase() }
        let name = detail ? "tail-expressions" : "tail-delivery",frames = detail ? 540 : 840
        let encoder = Process(),pipe = Pipe()
        if video {
            encoder.executableURL = URL(fileURLWithPath:"/usr/bin/env")
            encoder.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30","-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",out.appendingPathComponent(name+".mp4").path]
            encoder.standardInput = pipe;try encoder.run()
        }
        for f in 0..<frames {
            let t = Double(f)/30
            if !detail {
                if f == 720 { m.fiveCats.tailPlayEnabled = false;m.setLocomotionEnabled(false) }
                if (f >= 60 && f < 150) || (f >= 420 && f < 570) || f >= 750 {
                    m.target = V(250,420)
                    if f%9 == 0 { let i = m.nextArm;m.input(at:t);_ = m.arms[i].acceptGlyph(String(Array("tails")[i]),forStrike:m.arms[i].strikeCount,at:t) }
                } else { m.target = nil }
                if f == 270 { m.click(at:V(550,450),time:t) }
            }
            for s in 0..<2 { m.step(to:t+Double(s)/60,dt:1.0/60) }
            if video || f%30 == 0 {
                let data = frame(m,r,detail,t)
                if video { pipe.fileHandleForWriting.write(data) }
                if f%30 == 0 { try data.write(to:out.appendingPathComponent(String(format:name+"-%03d.png",f))) }
                if detail && [180,300].contains(f) { try frame(m,r,detail,t,true).write(to:out.appendingPathComponent(String(format:"tail-controls-%03d.png",f))) }
            }
        }
        if video { try pipe.fileHandleForWriting.close();encoder.waitUntilExit();precondition(encoder.terminationStatus == 0) }
        print("Rendered",name,"frames",frames,"video",video)
    }
}

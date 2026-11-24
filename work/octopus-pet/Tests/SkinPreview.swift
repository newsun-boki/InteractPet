import AppKit

@main struct SkinPreview {
    static func bitmap(_ width: Int, _ height: Int, draw: (CGContext)->Void) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,
            bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep:rep)!
        NSGraphicsContext.current = graphics
        graphics.cgContext.clear(CGRect(x:0,y:0,width:width,height:height))
        draw(graphics.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using:.png,properties:[:])!
    }
    static func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: String, _ bold: Bool = false) {
        (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[
            .font:NSFont.systemFont(ofSize:size,weight:bold ? .semibold : .regular),.foregroundColor:skinNSColor(color)])
    }
    static func idle(_ anchor: V, _ scale: Double, _ kind: PetKind = .octopus) -> PetMotion {
        let m = PetMotion();m.anchor = anchor;m.scale = scale
        m.configure(kind)
        for frame in 0..<180 { m.step(to:Double(frame)/60,dt:1.0/60) }
        return m
    }
    static func main() throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        let assets = URL(fileURLWithPath:args[1]),output = URL(fileURLWithPath:args[2])
        let characters = args.contains("--characters")
        let folder = characters ? "characters" : "octopus"
        let skins = PetSkin.catalog(in:assets).filter {$0.id != "original" && (characters ? $0.form != .octopus : $0.form == .octopus)}
        precondition(skins.count == 10,"All ten generated skin assets must be present")
        try FileManager.default.createDirectory(at:output.appendingPathComponent(folder),withIntermediateDirectories:true)
        let renderer = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"))
        for skin in skins {
            precondition(renderer.setSkin(skin,resources:assets))
            let m = idle(V(400,365),3.1,skin.form)
            let png = bitmap(800,800) { renderer.draw(m,in:$0) }
            try png.write(to:output.appendingPathComponent("\(folder)/\(skin.id).png"))
            let reach = idle(V(980,max(185,skin.form.floorInset*1.8+20)),1.8,skin.form)
            for frame in 180..<420 {
                let t = Double(frame)/60
                reach.target = V(250,620)
                if frame == 240 {
                    let index = reach.nextArm;reach.input(at:t);reach.arms[index].glyph = String(Array("abc")[index%3])
                }
                reach.step(to:t,dt:1.0/60)
                if frame > 240,reach.arms[0].reachAmount > 0.9,
                   (reach.arms[0].nodes.last!-V(250,620)).length < 60*reach.scale { break }
            }
            let action = bitmap(1200,900) { renderer.draw(reach,in:$0) }
            try action.write(to:output.appendingPathComponent("\(folder)/\(skin.id)-reach.png"))
        }
        let overview = bitmap(2400,1300) { c in
            c.setFillColor(skinColor("#FAF5F8"));c.fill(CGRect(x:0,y:0,width:2400,height:1300))
            text(characters ? "十位新朋友，都来帮你送字了" : "奶芋小八爪的换装衣橱",52,1200,48,"#49314F",true)
            text(characters ? "10 个原创角色 · 各自的伸展结构与身体动作" : "10 款主题皮肤 · 身体、触手和字母牌一起换色",54,1155,25,"#8C758F")
            for (i,skin) in skins.enumerated() {
                let x = CGFloat(32+(i%5)*472),y = CGFloat(148+(1-i/5)*494)
                let rect = CGRect(x:x,y:y,width:448,height:474)
                c.addPath(CGPath(roundedRect:rect,cornerWidth:26,cornerHeight:26,transform:nil))
                c.setFillColor(skinColor("#FFFFFF"));c.fillPath()
                text(String(format:"%02d",i+(characters ? 11 : 1)),x+24,y+418,22,skin.accent,true)
                text(skin.name,x+72,y+412,30,skin.ink,true)
                precondition(renderer.setSkin(skin,resources:assets))
                let m = idle(V(x+224,y+(characters ? 250 : 231)),characters ? 1.72 : 1.83,skin.form)
                renderer.draw(m,in:c)
                text(characters ? skin.form.reachName : skin.note,x+30,y+25,20,"#8C758F")
            }
            text("桌宠程序实际渲染  /  菜单栏 🐙 → 更换角色 / 皮肤",54,61,26,"#8C758F")
        }
        try overview.write(to:output.appendingPathComponent("\(folder)-overview.png"))
        print("Rendered 10 full-character PNGs, 10 reaching PNGs and overview")

        if args.contains("--video") {
            let pipe = Pipe(),process = Process()
            process.executableURL = URL(fileURLWithPath:"/usr/bin/env")
            process.arguments = ["ffmpeg","-y","-hide_banner","-loglevel","error","-f","image2pipe","-framerate","30",
                "-vcodec","png","-i","pipe:0","-an","-c:v","libx264","-crf","20","-pix_fmt","yuv420p",
                output.appendingPathComponent(characters ? "characters-preview.mp4" : "octopus-skins-preview.mp4").path]
            process.standardInput = pipe
            try process.run()
            for skin in skins {
                precondition(renderer.setSkin(skin,resources:assets))
                let m = idle(V(795,max(135,skin.form.floorInset*1.4+20)),1.4,skin.form)
                for frame in 0..<75 {
                    autoreleasepool {
                        let t = 3+Double(frame)/30
                        m.target = frame > 8 && frame < 53 ? V(200+Double(frame)*1.7,430) : nil
                        if frame > 8 && frame < 53 && frame%9 == 0 {
                            let index = m.nextArm;m.input(at:t);m.arms[index].glyph = String(Array("octopus!")[index])
                        }
                        for sub in 0..<2 { m.step(to:t+Double(sub)/60,dt:1.0/60) }
                        let png = bitmap(960,640) { c in
                            c.setFillColor(skinColor("#FAF5F8"));c.fill(CGRect(x:0,y:0,width:960,height:640))
                            c.addPath(CGPath(roundedRect:CGRect(x:44,y:212,width:725,height:295),cornerWidth:20,cornerHeight:20,transform:nil))
                            c.setFillColor(skinColor("#FFFFFF"));c.fillPath()
                            text(skin.name,44,551,34,skin.ink,true)
                            text(characters ? skin.form.reachName : skin.note,46,518,18,"#8C758F")
                            text("hello, little friend",82,458,22,skin.ink)
                            if let p = m.target { c.setFillColor(skinColor(skin.accent));c.fill(CGRect(x:p.x,y:p.y,width:2,height:23)) }
                            renderer.draw(m,in:c)
                            text("程序动画演示 · "+skin.form.reachName,44,41,18,"#8C758F")
                        }
                        pipe.fileHandleForWriting.write(png)
                    }
                }
            }
            try pipe.fileHandleForWriting.close()
            process.waitUntilExit()
            precondition(process.terminationStatus == 0,"Video encoder failed")
            print("Rendered 25-second skin animation preview")
        }
    }
}

import AppKit

@main struct Preview {
    static func main() throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        let output = URL(fileURLWithPath:args[1])
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let renderer = PetRenderer(assetURL:URL(fileURLWithPath:args[2]))
        let m = PetMotion();m.anchor = V(1140,104);m.scale = 1.05
        let frameCount = args.contains("--still") ? 1 : 540
        for frame in 0..<frameCount {
            autoreleasepool {
                let t = Double(frame)/30
                if t >= 1 && t < 10.2 {
                    m.target = t < 5.2 ? V(200+(t-1)*42,520) : V(560+(t-5.2)*35,340)
                    if frame % (t < 5.2 ? 12 : 5) == 0 {
                        let index = m.nextArm;m.input(at:t)
                        m.arms[index].glyph = String(Array("octopus!")[index])
                    }
                } else { m.target = nil }
                if frame == 345 { m.click(at:V(240,420),time:t) }
                if frame == 402 { m.click(at:V(730,550),time:t) }
                for sub in 0..<2 {m.step(to:t+Double(sub)/60,dt:1.0/60)}
                let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1280,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
                let graphics = NSGraphicsContext(bitmapImageRep:rep)!
                NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current = graphics
                let c = graphics.cgContext
                c.setFillColor(rgba(0.96,0.94,0.98));c.fill(CGRect(x:0,y:0,width:1280,height:720))
                let card = CGPath(roundedRect:CGRect(x:70,y:180,width:940,height:440),cornerWidth:22,cornerHeight:22,transform:nil)
                c.addPath(card);c.setFillColor(rgba(1,1,1));c.fillPath()
                let titleAttributes:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:21,weight:.semibold),.foregroundColor:NSColor(calibratedRed:0.31,green:0.20,blue:0.39,alpha:1)]
                ("奶芋小八爪 · 动作预览" as NSString).draw(at:CGPoint(x:100,y:651),withAttributes:titleAttributes)
                let subAttributes:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.secondaryLabelColor]
                let phase = t < 1 ? "待机 · 呼吸与眨眼" : t < 5.2 ? "字母快递 · 触手拿着小字牌送过去" : t < 10.2 ? "快速输入 · 八条触手接力送字母" : t < 15.5 ? "鼠标点击 · 身体跟着受力、前倾" : "停顿 · 身体与触手柔和回位"
                (phase as NSString).draw(at:CGPoint(x:100,y:145),withAttributes:subAttributes)
                let textAttributes:[NSAttributedString.Key:Any] = [.font:NSFont.monospacedSystemFont(ofSize:21,weight:.regular),.foregroundColor:NSColor(calibratedWhite:0.3,alpha:1)]
                ("Hello, little octopus." as NSString).draw(at:CGPoint(x:120,y:565),withAttributes:textAttributes)
                ("文字出现在哪里，触手就伸向哪里。" as NSString).draw(at:CGPoint(x:120,y:390),withAttributes:textAttributes)
                if let target = m.target {
                    c.setFillColor(rgba(0.44,0.24,0.66))
                    c.fill(CGRect(x:target.x,y:target.y,width:2,height:24))
                    c.setStrokeColor(rgba(0.66,0.42,0.81,0.15));c.setLineWidth(1)
                    c.strokeEllipse(in:CGRect(x:target.x-11,y:target.y-9,width:22,height:22))
                }
                if t >= 11.5 && t < 15.5 {
                    let click = t < 13.4 ? V(240,420) : V(730,550)
                    let age = t < 13.4 ? t-11.5 : t-13.4
                    let radius = 8+min(age,0.45)*28
                    c.setStrokeColor(rgba(0.58,0.35,0.75,0.5));c.setLineWidth(1.4)
                    c.strokeEllipse(in:CGRect(x:click.x-radius,y:click.y-radius,width:radius*2,height:radius*2))
                    c.setFillColor(rgba(0.58,0.35,0.75));c.fillEllipse(in:CGRect(x:click.x-3,y:click.y-3,width:6,height:6))
                }
                renderer.draw(m,in:c)
                NSGraphicsContext.restoreGraphicsState()
                if let data = rep.representation(using:.png,properties:[:]) {
                    try! data.write(to:output.appendingPathComponent(String(format:"%04d.png",frame)))
                }
            }
        }
    }
}

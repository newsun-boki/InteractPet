import AppKit

@main struct BoundaryPreview {
    static func png(_ width: Int,_ height: Int,_ draw: (CGContext)->Void) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();let g = NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.current = g
        draw(g.cgContext);NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using:.png,properties:[:])!
    }
    static func text(_ string: String,_ x: Double,_ y: Double,_ size: Double) {
        (string as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:skinNSColor("#5B486C")])
    }
    static func main() throws {
        _ = NSApplication.shared
        let a = CommandLine.arguments,assets = URL(fileURLWithPath:a[1]),out = URL(fileURLWithPath:a[2])
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let skins = PetSkin.catalog(in:assets).filter {$0.id == "original" || $0.form != .octopus}
        let renderer = PetRenderer(assetURL:assets.appendingPathComponent("mantle.png"))
        let labels = ["从边框外进来","沿底边走动","往右边框上爬","角色专属动作","落地 / 回到角落","扒边探头送字"]
        for skin in skins {
            precondition(renderer.setSkin(skin,resources:assets))
            let m = PetMotion();m.configure(skin.form)
            m.place(frame:CGRect(x:55,y:80,width:1010,height:625),visible:CGRect(x:55,y:112,width:1010,height:565),enter:true)
            var captured = Set<Int>()
            func capture(_ index: Int) throws {
                let data = png(1120,800) { c in
                    c.setFillColor(skinColor("#F7F2FA"));c.fill(CGRect(x:0,y:0,width:1120,height:800))
                    text(skin.name+" · "+labels[index],55,742,25)
                    c.setFillColor(skinColor("#FFFFFF"));c.fill(m.boundary.frame)
                    c.setFillColor(skinColor("#F4F0F8"));c.fill(CGRect(x:55,y:80,width:1010,height:32))
                    c.fill(CGRect(x:55,y:677,width:1010,height:28))
                    c.setStrokeColor(skinColor("#C6B4D6"));c.setLineWidth(2);c.stroke(m.boundary.frame)
                    c.setStrokeColor(skinColor("#DED3E6"));c.move(to:CGPoint(x:55,y:112));c.addLine(to:CGPoint(x:1065,y:112));c.strokePath()
                    if let target = m.target { c.setFillColor(skinColor(skin.accent));c.fill(CGRect(x:target.x,y:target.y,width:2,height:24)) }
                    renderer.draw(m,in:c)
                    text("边缘动作预览 · "+labels[index],55,27,19)
                }
                try data.write(to:out.appendingPathComponent("\(skin.id)-\(index).png"));captured.insert(index)
            }
            for f in 1...2400 {
                m.step(to:Double(f)/60,dt:1.0/60)
                let b = m.boundary
                if !captured.contains(0),b.phase == .entering,b.elapsed > 0.95 { try capture(0) }
                if !captured.contains(1),b.phase == .walking,b.elapsed > 2.3 { try capture(1) }
                if !captured.contains(2),b.phase == .climbing,b.elapsed > 2.9 { try capture(2) }
                if !captured.contains(3),b.phase == .performing,b.elapsed > 1.65 { try capture(3) }
                if !captured.contains(4),captured.contains(3),
                   (b.phase == .falling && abs(b.position.y-b.ground) < 0.1 && b.compression > 0.05 || b.phase == .returning && b.elapsed > 0.7) { try capture(4) }
                if captured.count == 5 { break }
            }
            precondition(captured.count == 5,"Missing routine snapshots: \(skin.id)")
            m.boundary.peek()
            let start = m.now
            for f in 1...260 {
                let t = start+Double(f)/60
                if f > 140 {
                    m.target = V(300,480)
                    if f%6 == 0 { m.input(at:t) }
                    if f%6 == 2 {
                        let arm = m.arms[(m.nextArm+m.arms.count-1)%m.arms.count]
                        _ = arm.acceptGlyph(String(Array("hello")[(f/6)%5]),forStrike:arm.strikeCount,at:t)
                    }
                }
                m.step(to:t,dt:1.0/60)
            }
            try capture(5)
            let sheet = png(1680,800) { c in
                for i in 0..<6 {
                    let image = NSImage(contentsOf:out.appendingPathComponent("\(skin.id)-\(i).png"))!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
                    c.draw(image,in:CGRect(x:(i%3)*560,y:(1-i/3)*400,width:560,height:400))
                }
            }
            try sheet.write(to:out.appendingPathComponent("\(skin.id)-sheet.png"))
            print("Rendered six edge interactions for \(skin.id)")
        }
    }
}

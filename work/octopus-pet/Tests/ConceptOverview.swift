import AppKit

struct Concept: Decodable {
    let id: String
    let name: String
    let kind: String
    let mechanic: String
}
@main struct ConceptOverview {
    static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath:CommandLine.arguments[1])
        let data = try Data(contentsOf:root.appendingPathComponent("originals/characters.json"))
        let characters = try JSONDecoder().decode([Concept].self,from:data)
        precondition(characters.count == 10)
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2400,pixelsHigh:1450,bitsPerSample:8,
            samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep:rep)!
        NSGraphicsContext.current = graphics
        let c = graphics.cgContext
        func text(_ value: String,_ rect: CGRect,_ size: CGFloat,_ hex: String,_ bold: Bool = false) {
            let style = NSMutableParagraphStyle();style.lineSpacing = 7;style.lineBreakMode = .byWordWrapping
            (value as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:bold ? .semibold : .regular),
                .foregroundColor:skinNSColor(hex),.paragraphStyle:style])
        }
        c.setFillColor(skinColor("#F6F7FA"));c.fill(CGRect(x:0,y:0,width:2400,height:1450))
        text("还有这些小家伙，也想帮你打字",CGRect(x:52,y:1330,width:2200,height:70),48,"#384254",true)
        text("10 个原创角色 · 每个都有自己的送字方式",CGRect(x:54,y:1282,width:2200,height:46),25,"#7D8898")
        for (i,character) in characters.enumerated() {
            let x = CGFloat(32+(i%5)*472),y = CGFloat(86+(1-i/5)*584)
            c.addPath(CGPath(roundedRect:CGRect(x:x,y:y,width:448,height:560),cornerWidth:26,cornerHeight:26,transform:nil))
            c.setFillColor(skinColor("#FFFFFF"));c.fillPath()
            text(String(format:"%02d",i+11),CGRect(x:x+24,y:y+495,width:50,height:40),22,"#9B8AC1",true)
            text(character.name,CGRect(x:x+73,y:y+490,width:355,height:48),29,"#384254",true)
            let image = NSImage(contentsOf:root.appendingPathComponent("originals/\(character.id).png"))!
            let ratio = min(412/image.size.width,327/image.size.height)
            let w = image.size.width*ratio,h = image.size.height*ratio
            image.draw(in:CGRect(x:x+224-w/2,y:y+147+(327-h)/2,width:w,height:h))
            text(character.mechanic,CGRect(x:x+27,y:y+27,width:394,height:101),22,"#7D8898")
        }
        text("原创设计稿 · 已制作对应的可切换桌宠",CGRect(x:54,y:24,width:2200,height:42),23,"#7D8898")
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("originals-overview.png"))
        print("Rendered overview of all ten original characters")
    }
}

import AppKit

func rgba(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed:r,green:g,blue:b,alpha:a)
}
final class PetRenderer {
    var mantle: CGImage?
    private(set) var skin = PetSkin.original
    var frameTime: Double = 0
    var rigMesh: RigMesh?
    var fiveCatsArtwork: FiveCatsArtwork?
    init(assetURL: URL) {
        mantle = NSImage(contentsOf:assetURL)?.cgImage(forProposedRect:nil,context:nil,hints:nil)
    }
    @discardableResult func setSkin(_ next: PetSkin, resources: URL) -> Bool {
        guard let image = NSImage(contentsOf:next.imageURL(in:resources))?.cgImage(forProposedRect:nil,context:nil,hints:nil) else { return false }
        let cats = next.form == .fivecats ? FiveCatsArtwork(image:image) : nil
        if next.form == .fivecats && cats == nil { return false }
        mantle = image;skin = next;fiveCatsArtwork = cats
        rigMesh = [.octopus,.fivecats].contains(next.form) ? nil : RigMesh(image:image)
        return true
    }
    func draw(_ motion: PetMotion, in ctx: CGContext) {
        frameTime = motion.now
        ctx.saveGState()
        drawBoundary(motion,context:ctx)
        func drawAttachedArm(_ arm: Arm) {
            ctx.saveGState()
            if motion.boundary.configured && arm.reachAmount < 0.015 && motion.now >= arm.reachUntil {
                ctx.clip(to:motion.boundary.frame)
            }
            drawArm(arm,scale:motion.scale,context:ctx);ctx.restoreGState()
        }
        let foreground = skin.form == .chameleon
        if !foreground { for arm in motion.arms { drawAttachedArm(arm) } }
        ctx.saveGState()
        if motion.boundary.configured { ctx.clip(to:motion.boundary.frame) }
        // Cross-screen delivery may redraw multiple overlays. Rasterize the
        // moving character mesh only on the screen where its body is visible.
        if !ctx.boundingBoxOfClipPath.isEmpty { drawHead(motion,context:ctx) }
        ctx.restoreGState()
        if foreground { for arm in motion.arms { drawAttachedArm(arm) } }
        for arm in motion.arms { drawLetter(arm,now:motion.now,scale:motion.scale,offset:motion.letterOffset,context:ctx) }
        ctx.restoreGState()
    }
    func drawLetter(_ arm: Arm,now: Double,scale: Double,offset: Double,context c: CGContext) {
        guard let glyph = arm.glyph,arm.initialized else { return }
        let delivered = arm.deliveredAt > 0
        let age = delivered ? now-arm.deliveredAt : 0
        guard age < 0.58 else { return }
        let base = delivered ? arm.deliveredPoint : arm.letterAnchor(distance:offset*scale)
        let lift = delivered ? smooth(age/0.58)*23 : 0
        let drift = delivered ? arm.side*smooth(age/0.58)*(16+arm.rank*3) : 0
        let point = base+V(drift,16+lift)*scale
        let alpha = delivered ? pow(1-clamp(age/0.58),1.3) : min(1,0.6+arm.reachAmount*2)
        let pop = delivered ? 1+sin(clamp(age/0.23) * .pi)*0.16 : 1+sin(clamp((now-arm.strikeStarted)/0.14) * .pi)*0.06
        let rotation = delivered ? arm.side*0.07 : sin(now*8+Double(arm.index))*0.085 + arm.side*0.045
        c.saveGState();c.translateBy(x:point.x,y:point.y);c.rotate(by:rotation);c.scaleBy(x:scale*pop,y:scale*pop);c.setAlpha(alpha)
        let rect = CGRect(x:-14,y:-14,width:28,height:29)
        let path = CGPath(roundedRect:rect,cornerWidth:8,cornerHeight:8,transform:nil)
        c.setShadow(offset:CGSize(width:0,height:-2),blur:3,color:rgba(0.39,0.22,0.51,0.17))
        c.addPath(path);c.setFillColor(skinColor(skin.card));c.fillPath()
        c.setShadow(offset:.zero,blur:0,color:nil)
        c.addPath(path);c.setStrokeColor(skinColor(skin.accent,0.85));c.setLineWidth(1.2);c.strokePath()
        c.setStrokeColor(rgba(1,1,1,0.8));c.setLineWidth(1)
        c.stroke(CGRect(x:-8,y:10,width:16,height:0))
        let font = NSFont.systemFont(ofSize:18,weight:.semibold)
        let attrs:[NSAttributedString.Key:Any] = [.font:font,.foregroundColor:skinNSColor(skin.ink)]
        let text = glyph as NSString,size = text.size(withAttributes:attrs)
        text.draw(at:CGPoint(x:-size.width/2,y:-size.height/2+0.8),withAttributes:attrs)
        if !delivered {
            if skin.form != .octopus {
                drawCharacterGrip(context:c,carrierIndex:arm.index)
            } else {
            // A small curled tip wraps the bottom edge, making the letter feel carried.
            let grip = CGMutablePath();grip.move(to:CGPoint(x:-8,y:-13))
            grip.addCurve(to:CGPoint(x:9,y:-10),control1:CGPoint(x:-2,y:-20),control2:CGPoint(x:12,y:-18))
            c.addPath(grip);c.setStrokeColor(skinColor(skin.body));c.setLineWidth(4);c.setLineCap(.round);c.strokePath()
            c.setFillColor(skinColor(skin.suckers));c.fillEllipse(in:CGRect(x:5,y:-15,width:3.2,height:2.7))
            }
        } else {
            let sparkle = sin(clamp(age/0.5) * .pi)
            c.setStrokeColor(skinColor(skin.accent,sparkle));c.setLineWidth(1.5)
            for side in [-1.0,1.0] {
                let x = side*(19+age*8)
                c.move(to:CGPoint(x:x-3,y:7));c.addLine(to:CGPoint(x:x+3,y:7))
                c.move(to:CGPoint(x:x,y:4));c.addLine(to:CGPoint(x:x,y:10))
            }
            c.strokePath()
        }
        c.restoreGState()
    }
    func drawArm(_ arm: Arm,scale: Double,context c: CGContext) {
        let points = arm.nodes
        guard arm.initialized else { return }
        if arm.kind == .fivecats { drawCatTail(arm,scale:scale,context:c);return }
        if !arm.kind.idleArms && arm.reachAmount < 0.015 && arm.locomotionWeight < 0.01 { return }
        if [.plant,.cloud,.yarncat,.spider,.star,.robot,.fivecats].contains(arm.kind) {
            drawSpecialArm(arm,scale:scale,context:c);return
        }
        var upper:[V] = [],lower:[V] = []
        for i in points.indices {
            let tangent = (points[min(i+1,points.count-1)]-points[max(i-1,0)]).unit
            let t = Double(i)/Double(points.count-1)
            let radius = arm.radius(t,scale)
            upper.append(points[i]+tangent.normal*radius)
            lower.append(points[i]-tangent.normal*radius)
        }
        let p = CGMutablePath()
        let outline = upper + lower.reversed()
        p.move(to:mix(outline[0],outline[1],0.5).point)
        for i in 1...outline.count {
            let a = outline[i%outline.count],b = outline[(i+1)%outline.count]
            p.addQuadCurve(to:mix(a,b,0.5).point,control:a.point)
        }
        p.closeSubpath()
        c.saveGState()
        let visible = arm.kind.idleArms ? 1 : smooth(arm.reachAmount/0.2)
        c.setAlpha(visible * (arm.kind == .jellyfish ? 0.74 : arm.kind == .ghost ? 0.9 : 1))
        c.addPath(p);c.setFillColor(skinColor(arm.kind == .chameleon ? "#F4A1B4" : skin.body));c.fillPath()
        c.saveGState();c.addPath(p);c.clip()
        if let g = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),
                              colors:[skinColor(arm.kind == .chameleon ? "#FFD1DA" : skin.light),skinColor(arm.kind == .chameleon ? "#DB7C99" : skin.dark)] as CFArray,locations:[0,1]) {
            let bounds = p.boundingBox
            c.drawLinearGradient(g,start:CGPoint(x:bounds.midX-18*scale,y:bounds.maxY),
                                 end:CGPoint(x:bounds.midX+14*scale,y:bounds.minY),options:[])
        }
        c.restoreGState()
        c.addPath(p);c.setStrokeColor(skinColor(skin.ink,0.26));c.setLineWidth(0.9*scale);c.strokePath()
        // A slim soft highlight follows the tube rather than stretching a bitmap.
        let shine = CGMutablePath()
        for i in stride(from:3,to:points.count-4,by:1) {
            let t = Double(i)/Double(points.count-1)
            let tangent = (points[i+1]-points[i-1]).unit
            let q = points[i]+tangent.normal*(arm.radius(t,scale)*0.28)
            if i == 3 { shine.move(to:q.point) } else { shine.addLine(to:q.point) }
        }
        c.addPath(shine);c.setStrokeColor(skinColor(skin.light,0.38));c.setLineWidth(2.5*scale);c.setLineCap(.round);c.strokePath()
        if arm.kind == .jellyfish,arm.reachAmount > 0.15 {
            c.setShadow(offset:.zero,blur:5*scale,color:skinColor("#FFE9FF",arm.reachAmount*0.65))
            c.addPath(shine);c.setStrokeColor(skinColor("#FFF4FF",arm.reachAmount*0.7));c.setLineWidth(2*scale);c.strokePath()
            c.setShadow(offset:.zero,blur:0,color:nil)
        }
        if arm.kind != .octopus { c.restoreGState();return }
        // Suckers stay spaced in screen space; distal tip remains unobtrusive near text.
        var arcLength = 0.0
        for i in 1..<points.count-3 {
            arcLength += (points[i]-points[i-1]).length
            let t = Double(i)/Double(points.count-1)
            guard t > 0.37, arcLength >= 13*scale else { continue }
            arcLength = 0
            if arm.reachAmount > 0.5 && t > 0.87 { continue }
            let tangent = (points[i+1]-points[i-1]).unit
            let radius = arm.radius(t,scale)
            let position = points[i]-tangent.normal*(radius*0.39)
            c.saveGState();c.translateBy(x:position.x,y:position.y);c.rotate(by:atan2(tangent.y,tangent.x))
            let r = max(1.3*scale,radius*0.36)
            c.setFillColor(skinColor(skin.suckers,0.8))
            c.fillEllipse(in:CGRect(x:-r,y:-r*0.65,width:r*2,height:r*1.3))
            c.setStrokeColor(skinColor(skin.dark,0.2));c.setLineWidth(0.5*scale)
            c.strokeEllipse(in:CGRect(x:-r,y:-r*0.65,width:r*2,height:r*1.3))
            c.restoreGState()
        }
        c.restoreGState()
    }
    func drawHead(_ m: PetMotion,context c: CGContext) {
        if skin.form == .fivecats { drawFiveCats(m,context:c);return }
        if skin.form != .octopus { drawCharacterBody(m,context:c);return }
        c.saveGState();c.translateBy(x:m.body.x,y:m.body.y)
        c.scaleBy(x:m.scale,y:m.scale)
        let tilt = m.boundary.rotation+m.locomotion.lean-m.leanSpring.value.x*0.085 + m.gazeSpring.value.x*0.006 + sin(m.now*1.15)*0.012
        c.rotate(by:tilt)
        let breath = sin(m.now*2.1)*0.009
        let bounce = m.energy*sin(m.now*12)*0.023
        let stretch = min(0.045,m.leanSpring.value.length*0.045)
        c.scaleBy(x:1+breath-bounce-stretch*0.6+m.boundary.compression*0.6,y:1-breath+bounce+stretch-m.boundary.compression)
        if let image = mantle {
            c.draw(image,in:CGRect(x:-82,y:-63,width:164,height:151))
        } else {
            c.setFillColor(skinColor(skin.body))
            c.fillEllipse(in:CGRect(x:-66,y:-46,width:132,height:118))
        }
        let gaze = m.gazeSpring.value
        for side in [-1.0,1.0] {
            let x = side*23+gaze.x, y = 4+gaze.y
            c.saveGState();c.translateBy(x:x,y:y);c.rotate(by:side * -0.08)
            let eyeH = 21*m.blink
            c.setFillColor(skinColor(skin.ink))
            c.fillEllipse(in:CGRect(x:-8.1,y:-eyeH/2,width:16.2,height:eyeH))
            if m.blink > 0.35 {
                c.setFillColor(rgba(1,0.98,1,0.98))
                c.fillEllipse(in:CGRect(x:-4,y:eyeH*0.1,width:5,height:4.6*m.blink))
                c.setFillColor(rgba(0.96,0.83,1,0.8))
                c.fillEllipse(in:CGRect(x:2,y:-eyeH*0.32,width:2.2,height:2.2*m.blink))
            }
            c.restoreGState()
            c.setFillColor(skinColor(skin.blush,0.58+m.energy*0.15))
            c.fillEllipse(in:CGRect(x:side*35-9,y:-16,width:18,height:9))
        }
        let mouth = CGMutablePath()
        mouth.move(to:CGPoint(x:-8,y:-12))
        mouth.addCurve(to:CGPoint(x:0,y:-13),control1:CGPoint(x:-8,y:-20),control2:CGPoint(x:-1,y:-20))
        mouth.addCurve(to:CGPoint(x:8,y:-12),control1:CGPoint(x:1,y:-20),control2:CGPoint(x:8,y:-20))
        c.addPath(mouth);c.setStrokeColor(skinColor(skin.ink));c.setLineWidth(2.6);c.setLineCap(.round);c.strokePath()
        c.restoreGState()
    }
}

final class OverlayView: NSView {
    let motion: PetMotion
    let renderer: PetRenderer
    var screenOrigin = V()
    init(frame: NSRect,motion: PetMotion,renderer: PetRenderer) {
        self.motion = motion;self.renderer = renderer
        super.init(frame:frame)
    }
    required init?(coder: NSCoder) { fatalError("not supported") }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        c.clear(dirtyRect);c.saveGState()
        c.translateBy(x:-screenOrigin.x,y:-screenOrigin.y)
        renderer.draw(motion,in:c)
        c.restoreGState()
    }
}

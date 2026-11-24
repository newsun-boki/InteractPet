import AppKit

final class SwarmRenderer {
    func draw(_ m: SwarmMotion,in c: CGContext) {
        let arrived = m.waves.last { $0.glyph != nil && m.particle($0,0).progress >= 1 }?.id
        for wave in m.waves {
            c.saveGState();c.clip(to:wave.frame)
            // Keep the caret and its text row readable, including during fly-throughs.
            let cutout = CGMutablePath();cutout.addRect(wave.frame)
            cutout.addRect(CGRect(x:wave.target.x-26,y:wave.target.y-5,width:140,height:30))
            c.addPath(cutout);c.clip(using:.evenOdd)
            let age = m.now-wave.birth
            for i in wave.starts.indices.reversed() {
                let p = m.particle(wave,i)
                guard p.alpha>0.001 else { continue }
                let color = wave.style.colors[i%wave.style.colors.count]
                c.saveGState();c.setAlpha(p.alpha)
                if !m.reducedMotion {
                    let trail = CGMutablePath()
                    for k in (0...5).reversed() {
                        let old = m.particle(wave,i,age:max(0,age-Double(k)*0.028)).position
                        if k==5 { trail.move(to:old.point) } else { trail.addLine(to:old.point) }
                    }
                    c.addPath(trail);c.setStrokeColor(skinColor(color,0.23*m.intensity));c.setLineWidth(wave.style == .meteors ? 5 : 2);c.setLineCap(.round);c.strokePath()
                }
                c.translateBy(x:p.position.x,y:p.position.y);c.scaleBy(x:p.scale,y:p.scale)
                let pulse = 0.8+0.2*sin(m.now*3+Double(i))
                let glow = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[skinColor(color,0.22*m.intensity*pulse),skinColor(color,0.07*m.intensity),skinColor(color,0)] as CFArray,locations:[0,0.35,1])!
                c.drawRadialGradient(glow,startCenter:.zero,startRadius:0,endCenter:.zero,endRadius:28,options:[])
                c.saveGState()
                let tilt = wave.style.cute ? sin(m.now*5+Double(i))*0.15 : p.angle
                c.rotate(by:tilt)
                drawSprite(wave.style,color:color,time:m.now+Double(i),context:c)
                c.restoreGState()
                if i==0,let glyph = wave.glyph,p.progress<1 || wave.id==arrived {
                    // The leader physically carries a tethered letter, then releases it upward.
                    let lift = smooth((p.progress-1)/0.65)*14
                    c.setStrokeColor(skinColor(color,0.85));c.setLineWidth(1)
                    c.move(to:CGPoint(x:0,y:6));c.addLine(to:CGPoint(x:0,y:18+lift));c.strokePath()
                    let box = CGRect(x:-13,y:14+lift,width:26,height:27)
                    c.addPath(CGPath(roundedRect:box,cornerWidth:8,cornerHeight:8,transform:nil));c.setFillColor(skinColor("#FFFCF8",0.97));c.fillPath()
                    c.addPath(CGPath(roundedRect:box,cornerWidth:8,cornerHeight:8,transform:nil));c.setStrokeColor(skinColor(color));c.strokePath()
                    let attrs:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:17,weight:.semibold),.foregroundColor:skinNSColor("#44374F")]
                    let text = glyph as NSString,s = text.size(withAttributes:attrs)
                    text.draw(at:CGPoint(x:-s.width/2,y:box.midY-s.height/2),withAttributes:attrs)
                }
                c.restoreGState()
            }
            c.restoreGState()
        }
    }
    func drawSprite(_ style: SwarmStyle,color: String,time: Double,context c: CGContext) {
        func ellipse(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ hex:String,_ alpha:Double = 1) {
            c.setFillColor(skinColor(hex,alpha));c.fillEllipse(in:CGRect(x:x,y:y,width:w,height:h))
        }
        func line(_ points:[CGPoint],_ hex:String,_ width:Double = 1.3) {
            guard let first = points.first else { return };c.beginPath();c.move(to:first)
            for p in points.dropFirst() { c.addLine(to:p) };c.setStrokeColor(skinColor(hex));c.setLineWidth(width);c.setLineCap(.round);c.setLineJoin(.round);c.strokePath()
        }
        func polygon(_ points:[CGPoint],_ hex:String) {
            c.beginPath();c.move(to:points[0]);for p in points.dropFirst() { c.addLine(to:p) };c.closePath();c.setFillColor(skinColor(hex));c.fillPath()
        }
        func face(_ y:Double = 0) {
            ellipse(-4,y,1.9,2.7,"#49404F");ellipse(2,y,1.9,2.7,"#49404F")
            line([CGPoint(x:-1.5,y:y-2),CGPoint(x:0,y:y-3),CGPoint(x:1.5,y:y-2)],"#776074",0.9)
        }
        let flutter = 0.35+0.65*abs(sin(time*20))
        switch style {
        case .fireflies,.bees:
            ellipse(-15,2,13,8*flutter,"#E7FAFF",0.85);ellipse(2,2,13,8*flutter,"#E7FAFF",0.85)
            ellipse(-7,-9,14,18,color)
            if style == .bees { for y in [-4.0,1.0] { c.setFillColor(skinColor("#756044"));c.fill(CGRect(x:-6,y:y,width:12,height:2)) } }
            else { ellipse(-5,-9,10,8,"#F1FFA7");ellipse(-2,-7,4,3,"#FFFFFF") }
            ellipse(-5,4,10,9,style == .bees ? "#FFE4A7" : "#9AAB6B");face(7)
            line([CGPoint(x:-3,y:12),CGPoint(x:-5,y:16)],"#8A8660");line([CGPoint(x:3,y:12),CGPoint(x:5,y:16)],"#8A8660")
        case .butterflies:
            for s in [-1.0,1.0] { c.saveGState();c.scaleBy(x:s*flutter,y:1);ellipse(1,-4,13,18,color);ellipse(1,-10,10,12,"#DCC8FF");ellipse(5,3,3,4,"#FFF8F1");c.restoreGState() }
            ellipse(-2.5,-8,5,19,"#B69BC5");face(3)
        case .stars,.prism:
            var pts:[CGPoint] = []
            let sides = style == .stars ? 10 : 8
            for j in 0..<sides { let a = Double(j)*2 * .pi/Double(sides) + .pi/2;let r = j%2==0 ? 12.0 : 5.0;pts.append(CGPoint(x:cos(a)*r,y:sin(a)*r)) }
            polygon(pts,color);if style == .stars { face() } else { ellipse(-2,-2,4,4,"#FFFFFF") }
        case .meteors:
            polygon([CGPoint(x:-28,y:0),CGPoint(x:2,y:5),CGPoint(x:5,y:0),CGPoint(x:2,y:-5)],color)
            ellipse(-4,-5,10,10,"#E5F9FF");ellipse(0,-2,4,4,"#FFFFFF")
        case .bubbles:
            ellipse(-11,-11,22,22,color,0.2);c.setStrokeColor(skinColor(color));c.setLineWidth(1.4);c.strokeEllipse(in:CGRect(x:-11,y:-11,width:22,height:22));ellipse(-7,3,5,4,"#FFFFFF",0.85);face(-2)
        case .jellies:
            for j in -2...2 { let x = Double(j)*3;let p = CGMutablePath();p.move(to:CGPoint(x:x,y:-2));p.addCurve(to:CGPoint(x:x+sin(time*5+x)*3,y:-18),control1:CGPoint(x:x-5,y:-8),control2:CGPoint(x:x+5,y:-12));c.addPath(p);c.setStrokeColor(skinColor(color,0.8));c.setLineWidth(1.5);c.strokePath() }
            ellipse(-11,-4,22,17,color,0.85);ellipse(-7,5,6,3,"#FFFFFF",0.7);face(1)
        case .petals:
            c.rotate(by:time*0.8);let p = CGMutablePath();p.move(to:CGPoint(x:0,y:-11));p.addCurve(to:CGPoint(x:-1,y:11),control1:CGPoint(x:-18,y:0),control2:CGPoint(x:-10,y:18));p.addLine(to:CGPoint(x:2,y:7));p.addCurve(to:CGPoint(x:0,y:-11),control1:CGPoint(x:15,y:16),control2:CGPoint(x:14,y:0));c.addPath(p);c.setFillColor(skinColor(color));c.fillPath();line([CGPoint(x:0,y:-8),CGPoint(x:2,y:6)],"#FFF0F5",0.8)
        case .snow:
            c.rotate(by:time*0.35)
            for _ in 0..<6 { line([CGPoint.zero,CGPoint(x:0,y:12)],color);line([CGPoint(x:-3,y:6),CGPoint(x:0,y:9),CGPoint(x:3,y:6)],color,1);c.rotate(by:.pi/3) };ellipse(-2,-2,4,4,"#FFFFFF")
        case .ghosts:
            let p = CGMutablePath();p.move(to:CGPoint(x:-10,y:-9));p.addCurve(to:CGPoint(x:10,y:-9),control1:CGPoint(x:-16,y:19),control2:CGPoint(x:16,y:19));for j in (0...4).reversed() {p.addLine(to:CGPoint(x:-10+Double(j)*5,y:-9+(j%2==0 ? 0 : 4)))};p.closeSubpath();c.addPath(p);c.setFillColor(skinColor(color,0.94));c.fillPath();face(1);ellipse(-8,-2,4,2,"#F9BDE1",0.75);ellipse(4,-2,4,2,"#F9BDE1",0.75)
        case .fish:
            polygon([CGPoint(x:-6,y:0),CGPoint(x:-17,y:7*sin(time*9)),CGPoint(x:-17,y:-7)],color);ellipse(-9,-6,22,13,color);ellipse(5,0,3,3,"#405B70");ellipse(2,3,5,2,"#DFFFF6");line([CGPoint(x:-1,y:0),CGPoint(x:-5,y:3)],"#FFFFFF",1)
        case .hearts:
            let p = CGMutablePath();p.move(to:CGPoint(x:0,y:-10));p.addCurve(to:CGPoint(x:0,y:6),control1:CGPoint(x:-25,y:5),control2:CGPoint(x:-8,y:18));p.addCurve(to:CGPoint(x:0,y:-10),control1:CGPoint(x:8,y:18),control2:CGPoint(x:25,y:5));c.addPath(p);c.setFillColor(skinColor(color));c.fillPath();face()
        case .planes:
            c.rotate(by:sin(time*3)*0.15);polygon([CGPoint(x:17,y:7),CGPoint(x:-15,y:4),CGPoint(x:-3,y:-2),CGPoint(x:-1,y:-12)],color);line([CGPoint(x:-3,y:-2),CGPoint(x:17,y:7),CGPoint(x:-1,y:-12)],"#6D99C0",1)
        case .runes:
            c.rotate(by:time*0.8);c.setLineWidth(1);c.setStrokeColor(skinColor(color));c.strokeEllipse(in:CGRect(x:-12,y:-12,width:24,height:24));line([CGPoint(x:0,y:9),CGPoint(x:7,y:-5),CGPoint(x:-7,y:-5),CGPoint(x:0,y:9)],color);ellipse(-2,-2,4,4,"#FFF6E7")
        case .plasma:
            c.setShadow(offset:.zero,blur:6,color:skinColor(color,0.8));line([CGPoint(x:-13,y:0),CGPoint(x:-5,y:5),CGPoint(x:0,y:-3),CGPoint(x:6,y:4),CGPoint(x:13,y:0)],color,2.5);ellipse(-3,-3,6,6,"#FFFFFF");c.setShadow(offset:.zero,blur:0,color:nil)
        }
    }
}

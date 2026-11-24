import AppKit

struct RibbonSample {
    let p: V
    let n: V
    let distance: Double
}
extension PetRenderer {
    func samples(_ points: [V], spacing: Double) -> [RibbonSample] {
        var result: [RibbonSample] = [],distance = 0.0,next = 0.0
        for i in 1..<points.count {
            let delta = points[i]-points[i-1],length = delta.length
            guard length > 0.0001 else { continue }
            while next <= distance+length {
                result.append(RibbonSample(p:mix(points[i-1],points[i],clamp((next-distance)/length)),n:delta.unit.normal,distance:next))
                next += spacing
            }
            distance += length
        }
        return result
    }
    func stroke(_ points: [V],color: CGColor,width: Double,context c: CGContext) {
        guard let first = points.first else { return }
        let p = CGMutablePath();p.move(to:first.point)
        for v in points.dropFirst() { p.addLine(to:v.point) }
        c.addPath(p);c.setStrokeColor(color);c.setLineWidth(width);c.setLineCap(.round);c.setLineJoin(.round);c.strokePath()
    }
    func leaf(at position: V, angle: Double, size: Double, color: CGColor, context c: CGContext) {
        c.saveGState();c.translateBy(x:position.x,y:position.y);c.rotate(by:angle)
        let p = CGMutablePath();p.move(to:.zero)
        p.addCurve(to:CGPoint(x:size,y:0),control1:CGPoint(x:size*0.3,y:size*0.55),control2:CGPoint(x:size*0.85,y:size*0.5))
        p.addCurve(to:.zero,control1:CGPoint(x:size*0.75,y:-size*0.45),control2:CGPoint(x:size*0.3,y:-size*0.45))
        c.addPath(p);c.setFillColor(color);c.fillPath()
        c.move(to:.zero);c.addLine(to:CGPoint(x:size*0.77,y:0));c.setStrokeColor(skinColor(skin.dark,0.3));c.setLineWidth(max(0.5,size*0.045));c.strokePath()
        c.restoreGState()
    }
    func sparkle(at p: V,size: Double,context c: CGContext) {
        let path = CGMutablePath();path.move(to:CGPoint(x:p.x,y:p.y+size))
        path.addQuadCurve(to:CGPoint(x:p.x+size,y:p.y),control:CGPoint(x:p.x+size*0.2,y:p.y+size*0.2))
        path.addQuadCurve(to:CGPoint(x:p.x,y:p.y-size),control:CGPoint(x:p.x+size*0.2,y:p.y-size*0.2))
        path.addQuadCurve(to:CGPoint(x:p.x-size,y:p.y),control:CGPoint(x:p.x-size*0.2,y:p.y-size*0.2))
        path.addQuadCurve(to:CGPoint(x:p.x,y:p.y+size),control:CGPoint(x:p.x-size*0.2,y:p.y+size*0.2))
        c.addPath(path);c.setFillColor(skinColor("#FFE4A0"));c.fillPath()
    }
    func drawSpecialArm(_ arm: Arm,scale: Double,context c: CGContext) {
        let ss = samples(arm.nodes,spacing:max(0.4,(arm.kind == .robot ? 0.7 : 2)*scale))
        guard !ss.isEmpty else { return }
        c.saveGState();c.setAlpha(max(smooth(arm.reachAmount/0.2),arm.locomotionWeight))
        switch arm.kind {
        case .fivecats:
            drawCatTail(arm,scale:scale,context:c)
        case .plant:
            stroke(arm.nodes,color:skinColor(skin.dark),width:6.8*scale,context:c)
            stroke(arm.nodes,color:skinColor(skin.body),width:4.8*scale,context:c)
            stroke(ss.map{$0.p+$0.n*scale},color:skinColor(skin.light,0.7),width:1.3*scale,context:c)
            for i in stride(from:10,to:ss.count-5,by:14) {
                let s = ss[i],side = i/14%2 == 0 ? 1.0 : -1.0
                let angle = atan2(s.n.y,s.n.x)+(side < 0 ? Double.pi : 0)+sin(frameTime*2+Double(i))*0.08
                leaf(at:s.p,angle:angle,size:12*scale,color:skinColor(i%28 == 10 ? skin.light : skin.body),context:c)
            }
        case .cloud:
            stroke(arm.nodes,color:skinColor("#DDC7D5",0.45),width:17.5*scale,context:c)
            for (offset,color) in [(-5.0,"#F4B4CC"),(0.0,"#FFE3A0"),(5.0,"#B8DEC8")] {
                stroke(ss.map {$0.p+$0.n*(offset*scale)},color:skinColor(color),width:5.8*scale,context:c)
            }
            stroke(ss.map {$0.p-$0.n*(7*scale)},color:skinColor("#FFFFFF",0.5),width:0.8*scale,context:c)
        case .yarncat:
            stroke(arm.nodes,color:skinColor(skin.dark),width:7*scale,context:c)
            for phase in [0.0,Double.pi] {
                stroke(ss.map{$0.p+$0.n*(sin($0.distance/(9*scale)*Double.pi*2+phase)*1.65*scale)},
                       color:skinColor(phase == 0 ? skin.light : skin.body),width:3.8*scale,context:c)
            }
        case .spider:
            stroke(arm.nodes,color:skinColor(skin.accent,0.85),width:1.35*scale,context:c)
            stroke(ss.map {$0.p+$0.n*0.25*scale},color:skinColor("#F4EAFF",0.9),width:0.5*scale,context:c)
        case .star:
            c.setShadow(offset:.zero,blur:5*scale,color:skinColor("#D8A8F3",0.5))
            stroke(arm.nodes,color:skinColor(skin.accent,0.7),width:7*scale,context:c)
            c.setShadow(offset:.zero,blur:0,color:nil)
            stroke(arm.nodes,color:skinColor(skin.light,0.9),width:3.8*scale,context:c)
            stroke(ss.map {$0.p+$0.n*2*scale},color:skinColor("#FFE8AD",0.9),width:0.8*scale,context:c)
            for fraction in [0.35,0.68] {
                let s = ss[min(ss.count-1,Int(Double(ss.count-1)*fraction))]
                sparkle(at:s.p+s.n*9*scale,size:(2.8+sin(frameTime*4+fraction*8))*scale,context:c)
            }
        case .robot:
            let coil = ss.map { s -> V in
                let phase = s.distance/(12*scale)*Double.pi*2
                return s.p+s.n*(sin(phase)*5.5*scale)+V(s.n.y,-s.n.x)*(cos(phase)*2.8*scale)
            }
            stroke(coil,color:skinColor(skin.dark),width:3.8*scale,context:c)
            stroke(coil,color:skinColor(skin.body),width:2.7*scale,context:c)
            stroke(coil.map {$0+V(-0.45,0.7)*scale},color:skinColor(skin.light,0.8),width:1*scale,context:c)
            if let root = arm.nodes.first {
                c.setFillColor(skinColor("#9ABFB4"));c.fillEllipse(in:CGRect(x:root.x-5*scale,y:root.y-5*scale,width:10*scale,height:10*scale))
            }
        default: break
        }
        if let tip = arm.nodes.last,arm.kind == .robot || arm.kind == .yarncat {
            c.setFillColor(skinColor("#FFF0DA"));c.fillEllipse(in:CGRect(x:tip.x-5*scale,y:tip.y-5*scale,width:10*scale,height:10*scale))
        }
        c.restoreGState()
    }

    func drawCharacterGrip(context c: CGContext,carrierIndex: Int = 0) {
        switch skin.form {
        case .fivecats:
            drawCatTailGrip(index:carrierIndex,context:c)
        case .plant:
            leaf(at:V(-10,-15),angle:0.8,size:12,color:skinColor(skin.light),context:c)
            leaf(at:V(10,-15),angle:2.4,size:12,color:skinColor(skin.body),context:c)
        case .spider:
            stroke([V(-12,9),V(0,22),V(12,9)],color:skinColor(skin.accent),width:1.2,context:c)
            stroke([V(-12,9),V(-13,-10),V(0,-16),V(13,-10),V(12,9)],color:skinColor(skin.accent),width:1.3,context:c)
        case .cloud: break
        case .star:
            c.setStrokeColor(skinColor("#FFE8AD"));c.setLineWidth(1.6)
            c.strokeEllipse(in:CGRect(x:-20,y:-12,width:40,height:9))
        case .robot,.yarncat:
            c.setFillColor(skinColor("#FFF0DA"));c.fillEllipse(in:CGRect(x:7,y:-15,width:10,height:15))
            if skin.form == .yarncat {
                c.setFillColor(skinColor("#E8A5AF"));c.fillEllipse(in:CGRect(x:10,y:-9,width:3.5,height:4.5))
            }
        default:
            let color = skin.form == .chameleon ? "#F4A1B4" : skin.body
            let p = CGMutablePath();p.move(to:CGPoint(x:-10,y:-13))
            p.addCurve(to:CGPoint(x:10,y:-6),control1:CGPoint(x:5,y:-22),control2:CGPoint(x:17,y:-16))
            c.addPath(p);c.setStrokeColor(skinColor(color));c.setLineWidth(skin.form == .jellyfish ? 3 : 5);c.setLineCap(.round);c.strokePath()
        }
    }

    func drawCharacterBody(_ m: PetMotion,context c: CGContext) {
        let kind = skin.form
        c.saveGState();c.translateBy(x:m.body.x,y:m.body.y);c.scaleBy(x:m.scale,y:m.scale)
        c.rotate(by:m.characterTilt)
        c.scaleBy(x:m.characterStretch.x,y:m.characterStretch.y)
        if let mesh = rigMesh,m.locomotion.weight > 0.001 { mesh.draw(m.locomotion,context:c) }
        else if let image = mantle { c.draw(image,in:CGRect(x:-88,y:-76,width:176,height:176)) }

        var center = V(0,10),separation = 22.0,eyeWidth = 15.0,eyeHeight = 21.0
        switch kind {
        case .slime: center = V(0,-5);separation = 23
        case .ghost: center = V(0,25);separation = 21
        case .chameleon: center = V(-27,35);separation = 24;eyeWidth = 19;eyeHeight = 26
        case .plant: center = V(-5,-17);separation = 19;eyeWidth = 13;eyeHeight = 18
        case .cloud: center = V(0,1);separation = 23
        case .jellyfish: center = V(0,10);separation = 23
        case .yarncat: center = V(-8,8);separation = 19
        case .spider: center = V(-16,25);separation = 18;eyeWidth = 18;eyeHeight = 23
        case .star: center = V(0,29);separation = 18
        case .robot: center = V(0,33);separation = 16;eyeWidth = 11;eyeHeight = 17
        default: break
        }
        let ink = kind == .robot ? "#ADFFE5" : skin.ink
        for side in [-1.0,1.0] {
            var eye = center+V(side*separation,0)+m.gazeSpring.value
            if kind == .chameleon { eye = eye+V(sin(m.now*0.9+side)*1.3,side) }
            eye = m.locomotion.deform(eye)
            c.saveGState();c.translateBy(x:eye.x,y:eye.y);c.rotate(by:side * -0.07)
            let h = eyeHeight*m.blink
            c.setFillColor(skinColor(ink));c.fillEllipse(in:CGRect(x:-eyeWidth/2,y:-h/2,width:eyeWidth,height:h))
            if m.blink > 0.35 {
                c.setFillColor(skinColor("#FFFFFF",0.96));c.fillEllipse(in:CGRect(x:-eyeWidth*0.25,y:h*0.12,width:eyeWidth*0.35,height:h*0.26))
                c.setFillColor(skinColor("#F3DFFF",0.8));c.fillEllipse(in:CGRect(x:eyeWidth*0.12,y:-h*0.3,width:eyeWidth*0.15,height:h*0.13))
            }
            c.restoreGState()
            if kind != .chameleon {
                c.setFillColor(skinColor(skin.blush,kind == .robot ? 0.95 : 0.6+m.energy*0.13))
                c.fillEllipse(in:CGRect(x:center.x+side*(separation+8)-7,y:center.y-17,width:14,height:7))
            }
            if kind == .spider {
                c.setFillColor(skinColor(skin.ink));c.fillEllipse(in:CGRect(x:center.x+side*35-3,y:center.y-3,width:6,height:6*m.blink))
            }
        }
        if kind == .chameleon { c.restoreGState();return }
        let mouth = m.locomotion.deform(center+V(0,-17))
        if kind == .star || kind == .cloud {
            let p = CGMutablePath();p.move(to:CGPoint(x:mouth.x-6,y:mouth.y+2));p.addLine(to:CGPoint(x:mouth.x+6,y:mouth.y+2))
            p.addQuadCurve(to:CGPoint(x:mouth.x,y:mouth.y-7),control:CGPoint(x:mouth.x+6,y:mouth.y-6))
            p.addQuadCurve(to:CGPoint(x:mouth.x-6,y:mouth.y+2),control:CGPoint(x:mouth.x-6,y:mouth.y-6))
            c.addPath(p);c.setFillColor(skinColor(skin.ink));c.fillPath()
            c.saveGState();c.addPath(p);c.clip()
            c.setFillColor(skinColor("#EE9FAC"));c.fillEllipse(in:CGRect(x:mouth.x-4,y:mouth.y-7,width:8,height:4.5));c.restoreGState()
        } else {
            let p = CGMutablePath();p.move(to:CGPoint(x:mouth.x-7,y:mouth.y+1))
            if [.slime,.yarncat].contains(kind) {
                p.addCurve(to:mouth.point,control1:CGPoint(x:mouth.x-7,y:mouth.y-6),control2:CGPoint(x:mouth.x-1,y:mouth.y-6))
                p.addCurve(to:CGPoint(x:mouth.x+7,y:mouth.y+1),control1:CGPoint(x:mouth.x+1,y:mouth.y-6),control2:CGPoint(x:mouth.x+7,y:mouth.y-6))
            } else { p.addQuadCurve(to:CGPoint(x:mouth.x+7,y:mouth.y+1),control:CGPoint(x:mouth.x,y:mouth.y-9)) }
            c.addPath(p);c.setStrokeColor(skinColor(ink));c.setLineWidth(kind == .robot ? 2 : 2.3);c.setLineCap(.round);c.strokePath()
        }
        if kind == .yarncat {
            c.setFillColor(skinColor("#DDA0A5"));c.fillEllipse(in:CGRect(x:mouth.x-2,y:mouth.y+3,width:4,height:3))
            for side in [-1.0,1.0] {
                stroke([center+V(side*29,-11),center+V(side*36,-8)],color:skinColor("#B88775",0.65),width:1,context:c)
                stroke([center+V(side*29,-16),center+V(side*36,-18)],color:skinColor("#B88775",0.65),width:1,context:c)
            }
        }
        c.restoreGState()
    }
}

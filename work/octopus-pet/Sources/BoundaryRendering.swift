import AppKit

extension PetRenderer {
    func drawBoundary(_ m: PetMotion,context c: CGContext) {
        let b = m.boundary,s = m.scale
        guard b.configured else { return }
        c.saveGState();c.clip(to:b.frame)
        let lift = max(0,m.body.y-b.ground)
        if lift < 180*s {
            c.setFillColor(skinColor(skin.dark,0.08*(1-lift/(180*s))))
            c.fillEllipse(in:CGRect(x:m.body.x-40*s,y:b.area.minY+2,width:80*s,height:7*s))
        }
        if let top = b.threadAnchor {
            c.setStrokeColor(skinColor(skin.accent,0.7));c.setLineWidth(1.2*s)
            c.move(to:top.point);c.addLine(to:(m.body+V(0,58)*s).point);c.strokePath()
        }
        for hit in b.impacts {
            let age = hit.age/0.8,r = (8+age*55)*s
            c.saveGState();c.translateBy(x:hit.point.x,y:hit.point.y)
            c.rotate(by:atan2(hit.normal.y,hit.normal.x));c.setAlpha(1-age)
            c.setStrokeColor(skinColor(skin.accent,0.65));c.setLineWidth(1.8*s)
            for n in 0..<2 {
                let rr = r+Double(n)*10*s
                c.strokeEllipse(in:CGRect(x:-rr*0.25,y:-rr,width:rr*0.5,height:rr*2))
            }
            if m.kind == .cloud {
                for (i,color) in ["#EDB0C9","#F1D98E","#A8DCCB"].enumerated() {
                    c.setStrokeColor(skinColor(color));c.setLineWidth(3*s)
                    c.addArc(center:.zero,radius:r+Double(i)*5*s,startAngle:-.pi/2,endAngle:.pi/2,clockwise:false);c.strokePath()
                }
            }
            c.restoreGState()
        }
        for p in b.particles {
            c.saveGState();c.translateBy(x:p.point.x,y:p.point.y);c.rotate(by:p.angle)
            c.setAlpha(pow(1-p.age/p.life,1.3));c.setLineWidth(1.2*s)
            c.setFillColor(skinColor(skin.light));c.setStrokeColor(skinColor(skin.accent))
            let r = p.size
            switch m.kind {
            case .star,.robot:
                let path = CGMutablePath()
                for i in 0..<10 {
                    let a = Double(i)*Double.pi/5,rr = i%2 == 0 ? r*1.7 : r*0.65
                    let point = CGPoint(x:cos(a)*rr,y:sin(a)*rr)
                    i == 0 ? path.move(to:point) : path.addLine(to:point)
                }
                path.closeSubpath();c.addPath(path);c.drawPath(using:.fillStroke)
            case .plant,.chameleon:
                let path = CGMutablePath();path.move(to:CGPoint(x:-r*2,y:0))
                path.addQuadCurve(to:CGPoint(x:r*2,y:0),control:CGPoint(x:0,y:r*2))
                path.addQuadCurve(to:CGPoint(x:-r*2,y:0),control:CGPoint(x:0,y:-r*2))
                c.addPath(path);c.setFillColor(skinColor("#ACCD7A"));c.fillPath()
            case .ghost,.cloud:
                c.setFillColor(skinColor(skin.light,0.5));c.fillEllipse(in:CGRect(x:-r*2,y:-r,width:r*4,height:r*2))
            case .yarncat:
                c.fillEllipse(in:CGRect(x:-r,y:-r,width:r*2,height:r*1.5))
                for x in [-1.0,0,1] { c.fillEllipse(in:CGRect(x:x*r-r*0.3,y:r*0.6,width:r*0.6,height:r*0.6)) }
            case .spider:
                c.move(to:CGPoint(x:-r*2,y:0));c.addLine(to:CGPoint(x:r*2,y:0))
                c.move(to:CGPoint(x:0,y:-r*2));c.addLine(to:CGPoint(x:0,y:r*2));c.strokePath()
            default:
                c.fillEllipse(in:CGRect(x:-r,y:-r,width:r*2,height:r*2));c.strokeEllipse(in:CGRect(x:-r,y:-r,width:r*2,height:r*2))
            }
            c.restoreGState()
        }
        c.restoreGState()
    }
}

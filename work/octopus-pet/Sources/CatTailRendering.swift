import AppKit

extension PetRenderer {
    func drawCatTail(_ arm: Arm,scale: Double,context c: CGContext) {
        guard arm.initialized,arm.nodes.count > 2 else { return }
        let points = arm.nodes,coat = FiveCatsMotion.coat(arm.index)
        let extensionAmount = arm.catTail?.extensionAmount ?? arm.reachAmount
        var upper = [V](),lower = [V](),normals = [V]()
        func radius(_ t: Double) -> Double {
            (6.1-extensionAmount*1.1)*(1-0.57*smooth(t))*scale
        }
        for i in points.indices {
            let normal = (points[min(i+1,points.count-1)]-points[max(0,i-1)]).unit.normal
            let t = Double(i)/Double(points.count-1),r = radius(t)
            normals.append(normal);upper.append(points[i]+normal*r);lower.append(points[i]-normal*r)
        }
        let outline = upper+lower.reversed(),shape = CGMutablePath()
        shape.move(to:mix(outline[0],outline[1],0.5).point)
        for i in 1...outline.count {
            let a = outline[i%outline.count],b = outline[(i+1)%outline.count]
            shape.addQuadCurve(to:mix(a,b,0.5).point,control:a.point)
        }
        shape.closeSubpath()
        c.saveGState()
        c.setShadow(offset:CGSize(width:0,height:-0.7*scale),blur:1.8*scale,color:skinColor(coat.dark,0.16))
        c.addPath(shape);c.setFillColor(skinColor(coat.body));c.fillPath()
        c.setShadow(offset:.zero,blur:0,color:nil)
        c.saveGState();c.addPath(shape);c.clip()
        stroke(zip(points,normals).map {$0-$1*2.2*scale},color:skinColor(coat.dark,0.18),width:2.2*scale,context:c)
        stroke(zip(points,normals).map {$0+$1*1.8*scale},color:skinColor(coat.light,0.38),width:1.3*scale,context:c)
        if arm.index == 0 || arm.index == 2 {
            for i in stride(from:9,to:points.count-3,by:6) {
                let p = points[i],n = normals[i],r = radius(Double(i)/Double(points.count-1))
                let tangent = V(n.y,-n.x)
                let stripe = CGMutablePath();stripe.move(to:(p+n*r).point)
                stripe.addQuadCurve(to:(p-n*r).point,control:(p+tangent*2*scale).point)
                c.addPath(stripe);c.setStrokeColor(skinColor(coat.dark,0.57));c.setLineWidth(2.4*scale);c.setLineCap(.round);c.strokePath()
            }
        } else if arm.index == 3 {
            for (range,color) in [(9..<15,"#C3884B"),(24..<30,"#665047"),(37..<43,"#C3884B")] {
                stroke(Array(points[range]),color:skinColor(color,0.8),width:12*scale,context:c)
            }
        } else if arm.index == 4 {
            stroke(Array(points.suffix(9)),color:skinColor("#F6EBDD"),width:9*scale,context:c)
        }
        c.restoreGState()
        c.addPath(shape);c.setStrokeColor(skinColor(coat.dark,0.32));c.setLineWidth(0.28*scale);c.strokePath()
        let fur = CGMutablePath()
        for i in stride(from:3,to:points.count-2,by:2) {
            let t = Double(i)/Double(points.count-1),r = radius(t)
            for side in [-1.0,1.0] {
                let n = normals[i]*side,tangent = V(n.y,-n.x)
                fur.move(to:(points[i]+n*r*0.86).point)
                fur.addLine(to:(points[i]+n*(r+0.7*scale)+tangent*0.7*scale).point)
            }
        }
        c.addPath(fur);c.setStrokeColor(skinColor(coat.light,0.45));c.setLineWidth(0.35*scale);c.strokePath()
        if let tip = points.last {
            c.setFillColor(skinColor(arm.index == 4 ? "#F6EBDD" : coat.body))
            let r = radius(1)*0.82;c.fillEllipse(in:CGRect(x:tip.x-r,y:tip.y-r,width:r*2,height:r*2))
        }
        c.restoreGState()
    }
    func drawCatTailGrip(index: Int,context c: CGContext) {
        let coat = FiveCatsMotion.coat(index),curl = CGMutablePath()
        // The first point is exactly the path anchor below the card. The coil
        // cups its lower edge without entering the letter or the typing target.
        curl.move(to:CGPoint(x:0,y:-16))
        curl.addCurve(to:CGPoint(x:12,y:-11),control1:CGPoint(x:-22,y:-30),control2:CGPoint(x:19,y:-28))
        curl.addQuadCurve(to:CGPoint(x:7,y:-9),control:CGPoint(x:12,y:-5))
        for (width,color) in [(6.0,coat.dark),(4.5,index == 4 ? "#F6EBDD" : coat.body)] {
            c.addPath(curl);c.setStrokeColor(skinColor(color));c.setLineWidth(width);c.setLineCap(.round);c.strokePath()
        }
    }
}

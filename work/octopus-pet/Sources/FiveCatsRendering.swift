import AppKit

/// Runtime atlas extraction preserves the generated artwork and its alpha.
final class FiveCatsArtwork {
    let meshes: [RigMesh]
    let sourceRects: [CGRect]
    init?(image: CGImage) {
        let w = image.width,h = image.height
        var rgba = [UInt8](repeating:0,count:w*h*4)
        rgba.withUnsafeMutableBytes { bytes in
            let c = CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
        }
        var crops: [RigMesh] = [],rects: [CGRect] = []
        for i in 0..<FiveCatsMotion.count {
            let start = w*i/5,end = w*(i+1)/5
            var minX = end,maxX = start,minY = h,maxY = 0
            for y in 0..<h {
                for x in start..<end where rgba[(y*w+x)*4+3] > 24 {
                    minX = min(minX,x);maxX = max(maxX,x);minY = min(minY,y);maxY = max(maxY,y)
                }
            }
            guard maxX-minX > 20,maxY-minY > 20 else { return nil }
            let rect = CGRect(x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1)
            guard let crop = image.cropping(to:rect) else { return nil }
            rects.append(rect);crops.append(RigMesh(image:crop,dense:true))
        }
        sourceRects = rects;meshes = crops
    }
}

extension PetRenderer {
    func drawFiveCats(_ m: PetMotion,context c: CGContext) {
        for i in 0..<FiveCatsMotion.count { drawCatMember(m,index:i,context:c) }
    }
    func drawCatMember(_ m: PetMotion,index i: Int,context c: CGContext) {
        guard let art = fiveCatsArtwork else { return }
        c.saveGState();c.translateBy(x:m.body.x,y:m.body.y);c.scaleBy(x:m.scale,y:m.scale)
            let pivot = m.fiveCats.pivot(i)
            c.translateBy(x:pivot.x,y:pivot.y);c.rotate(by:m.fiveCats.angle(i))
            c.scaleBy(x:FiveCatsMotion.width/176,y:FiveCatsMotion.height/176)
            c.translateBy(x:0,y:76)
            art.meshes[i].draw(deform:{m.fiveCats.deform($0,index:i)},context:c)
        c.restoreGState()
    }
    func drawKittenPaw(at p: V,index: Int,size: Double,context c: CGContext) {
        let coat = FiveCatsMotion.coat(index)
        c.saveGState();c.translateBy(x:p.x,y:p.y);c.scaleBy(x:size,y:size)
        c.setFillColor(skinColor(coat.light));c.setStrokeColor(skinColor(coat.dark,0.55));c.setLineWidth(0.7)
        let paw = CGRect(x:-5,y:-3.5,width:10,height:8)
        c.fillEllipse(in:paw);c.strokeEllipse(in:paw)
        c.setFillColor(skinColor("#EFB1BD"));c.fillEllipse(in:CGRect(x:-1.8,y:-1.8,width:3.6,height:3))
        for x in [-2.7,0,2.7] { c.fillEllipse(in:CGRect(x:x-0.7,y:1.7,width:1.4,height:1.6)) }
        c.restoreGState()
    }
}

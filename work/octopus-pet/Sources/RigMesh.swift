import AppKit

/// A registered triangle mesh, rasterized into one small premultiplied bitmap.
/// A single draw replaces hundreds of CoreGraphics clipping/drawing operations.
final class RigMesh {
    let xs: [Double]
    let ys: [Double]
    private let sourceSide = 528
    private var source: [UInt8]
    private var pixels: [UInt8] = []
    private var side = 0
    private let extent = CGRect(x:-120,y:-112,width:240,height:240)
    private var vertices: [V] = []
    init(image: CGImage,dense: Bool = false) {
        xs = stride(from:-88.0,through:88.0,by:8).map {$0}
        ys = dense ? stride(from:-76.0,through:100.0,by:4).map {$0} : stride(from:-76.0,through:4.0,by:4).map {$0}+[12,24,40,60,80,100]
        source = [UInt8](repeating:0,count:sourceSide*sourceSide*4)
        source.withUnsafeMutableBytes { data in
            let c = CGContext(data:data.baseAddress,width:sourceSide,height:sourceSide,bitsPerComponent:8,bytesPerRow:sourceSide*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.interpolationQuality = .high;c.draw(image,in:CGRect(x:0,y:0,width:sourceSide,height:sourceSide))
        }
        for y in ys { for x in xs { vertices.append(V(x,y)) } }
    }
    func draw(_ rig: LocomotionRig,context c: CGContext) {
        draw(deform:rig.deform,context:c)
    }
    func draw(deform: (V)->V,context c: CGContext) {
        let density = min(3,max(1,ceil(hypot(c.ctm.a,c.ctm.b)-0.15)))
        let size = Int(extent.width*density)
        if side != size { side = size;pixels = [UInt8](repeating:0,count:size*size*4) }
        let destinations = vertices.map { p -> V in
            let d = deform(p)
            return V((d.x-extent.minX)*density,(extent.maxY-d.y)*density)
        }
        let texture = vertices.map { V(($0.x+88)/176*Double(sourceSide-1),(100-$0.y)/176*Double(sourceSide-1)) }
        pixels.withUnsafeMutableBufferPointer { out in
            out.initialize(repeating:0)
            source.withUnsafeBufferPointer { source in
                for row in 0..<ys.count-1 {
                    for col in 0..<xs.count-1 {
                        let i = row*xs.count+col
                        for indices in [(i,i+1,i+1+xs.count),(i,i+1+xs.count,i+xs.count)] {
                            let a = destinations[indices.0],b = destinations[indices.1],d = destinations[indices.2]
                            let u = b-a,v = d-a,det = u.x*v.y-u.y*v.x
                            guard abs(det) > 0.001 else { continue }
                            let minX = max(0,Int(floor(min(a.x,b.x,d.x)))),maxX = min(size-1,Int(ceil(max(a.x,b.x,d.x))))
                            let minY = max(0,Int(floor(min(a.y,b.y,d.y)))),maxY = min(size-1,Int(ceil(max(a.y,b.y,d.y))))
                            guard minX <= maxX,minY <= maxY else { continue }
                            let ta = texture[indices.0],tu = texture[indices.1]-ta,tv = texture[indices.2]-ta
                            for y in minY...maxY {
                                for x in minX...maxX {
                                    let dx = Double(x)+0.5-a.x,dy = Double(y)+0.5-a.y
                                    let s = (dx*v.y-dy*v.x)/det,t = (u.x*dy-u.y*dx)/det
                                    guard s >= -0.00001,t >= -0.00001,s+t <= 1.00001 else { continue }
                                    let uv = ta+tu*s+tv*t
                                    let fx = clamp(uv.x,0,Double(sourceSide-1)),fy = clamp(uv.y,0,Double(sourceSide-1))
                                    let ix = Int(fx),iy = Int(fy),jx = min(sourceSide-1,ix+1),jy = min(sourceSide-1,iy+1)
                                    let wx = fx-Double(ix),wy = fy-Double(iy)
                                    let p0 = (iy*sourceSide+ix)*4,p1 = (iy*sourceSide+jx)*4,p2 = (jy*sourceSide+ix)*4,p3 = (jy*sourceSide+jx)*4
                                    let target = (y*size+x)*4
                                    for channel in 0..<4 {
                                        let top = Double(source[p0+channel])*(1-wx)+Double(source[p1+channel])*wx
                                        let bottom = Double(source[p2+channel])*(1-wx)+Double(source[p3+channel])*wx
                                        out[target+channel] = UInt8(clamping:Int((top*(1-wy)+bottom*wy).rounded()))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        let data = Data(pixels) as CFData
        if let provider = CGDataProvider(data:data),let image = CGImage(width:size,height:size,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) {
            c.interpolationQuality = .high;c.draw(image,in:extent)
        }
    }
}

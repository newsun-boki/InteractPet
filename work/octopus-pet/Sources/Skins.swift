import AppKit

func skinColor(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
    let value = UInt32(hex.dropFirst(), radix:16) ?? 0xB886D7
    return CGColor(srgbRed:CGFloat((value >> 16) & 255)/255,
                   green:CGFloat((value >> 8) & 255)/255,
                   blue:CGFloat(value & 255)/255,alpha:alpha)
}
func skinNSColor(_ hex: String) -> NSColor { NSColor(cgColor:skinColor(hex))! }

struct PetSkin: Codable {
    let id: String
    let name: String
    let note: String
    let body: String
    let light: String
    let dark: String
    let suckers: String
    let ink: String
    let accent: String
    let card: String
    let blush: String
    var kind: PetKind? = nil
    var form: PetKind { kind ?? .octopus }

    static let original = PetSkin(id:"original",name:"奶芋团子 · 原版",note:"经典软糯紫色",
        body:"#B378D6",light:"#DBA8F2",dark:"#AB70CF",suckers:"#FCC4E8",
        ink:"#452154",accent:"#A366C2",card:"#FFF2D6",blush:"#FFA3D4")

    func imageURL(in resources: URL) -> URL {
        id == "original" ? resources.appendingPathComponent("mantle.png") :
            resources.appendingPathComponent("Skins/\(id).png")
    }
    static func catalog(in resources: URL) -> [PetSkin] {
        guard let data = try? Data(contentsOf:resources.appendingPathComponent("Skins/skins.json")),
              let skins = try? JSONDecoder().decode([PetSkin].self,from:data) else { return [.original] }
        var ids: Set<String> = ["original"]
        let valid = skins.filter { skin in
            guard skin.id.range(of:"^[a-z][a-z0-9-]*$",options:.regularExpression) != nil,
                  !ids.contains(skin.id),FileManager.default.fileExists(atPath:skin.imageURL(in:resources).path),
                  [skin.body,skin.light,skin.dark,skin.suckers,skin.ink,skin.accent,skin.card,skin.blush].allSatisfy({
                      $0.range(of:"^#[0-9a-fA-F]{6}$",options:.regularExpression) != nil
                  }) else { return false }
            ids.insert(skin.id)
            return true
        }
        return [.original]+valid
    }
}

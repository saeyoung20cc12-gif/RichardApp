import Foundation
import SceneKit

let url = URL(fileURLWithPath: "/Users/mac/Documents/duck/RichardApp/RichardApp/Views/anima_richard.usdz")
let scene = try! SCNScene(url: url, options: nil)

func inspect(_ node: SCNNode, indent: String = "") {
    let pos = node.position
    let scale = node.scale
    let euler = node.eulerAngles
    print("\(indent)[\(node.name ?? "unnamed")]")
    print("\(indent)  pos=(\(pos.x),\(pos.y),\(pos.z)) scale=(\(scale.x),\(scale.y),\(scale.z)) euler=(\(euler.x),\(euler.y),\(euler.z))")
    print("\(indent)  animKeys=\(node.animationKeys)")
    if let geo = node.geometry {
        print("\(indent)  geometry: \(geo.name ?? "unnamed"), materials: \(geo.materials.count)")
    }
    for child in node.childNodes { inspect(child, indent: indent + "  ") }
}
inspect(scene.rootNode)

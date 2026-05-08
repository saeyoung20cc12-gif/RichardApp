import Foundation
import SceneKit

let url = URL(fileURLWithPath: "/Users/mac/Documents/duck/RichardApp/RichardApp/Views/anima_richard.usdz")
do {
    let scene = try SCNScene(url: url, options: nil)
    func checkNode(_ node: SCNNode, prefix: String) {
        print("\(prefix)Node: \(node.name ?? "unnamed")")
        if !node.animationKeys.isEmpty {
            print("\(prefix)  -> Animations: \(node.animationKeys)")
        }
        for child in node.childNodes {
            checkNode(child, prefix: prefix + "  ")
        }
    }
    checkNode(scene.rootNode, prefix: "")
} catch {
    print("Error: \(error)")
}

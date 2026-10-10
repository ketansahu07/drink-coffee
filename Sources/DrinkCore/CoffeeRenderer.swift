import Foundation

/// Pure terminal-sized frames: a cyan computer sipping from an amber mug.
public struct CoffeeRenderer {
    private let stationary: [CoffeePoint]

    public init() {
        stationary = CoffeeMesh.computer().points
    }

    public func frame(elapsed: Double, columns: Int, rows: Int, remaining: Int, color: Bool) -> String {
        let width = min(160, max(1, columns))
        let height = min(60, max(1, rows))
        let seconds = max(0, remaining)
        let timeLabel = Self.duration(seconds)
        if width < 30 || height < 16 {
            let lines = ["Coffee / \(timeLabel) left", "Enlarge terminal to 30 x 16", "Ctrl+C to finish"]
            return lines.prefix(height).map { String($0.prefix(width)) }.joined(separator: "\n")
        }
        let sceneRows = height - 4
        let t = elapsed.isFinite ? max(0, elapsed).truncatingRemainder(dividingBy: 86400) : 0
        let dynamic = CoffeeMesh.sip(at: t)
        let yaw = 0.27 + 0.13 * sin(t * 0.22)
        let cy = cos(yaw), sy = sin(yaw), ce = cos(0.17), se = sin(0.17)
        let focal = min(Double(sceneRows) * 2.55, Double(width) * 0.87)
        let light = CoffeeVector(-0.46, 0.72, 0.52)
        var glyphs = [UInt8](repeating: 32, count: width * sceneRows)
        var shades = [Int](repeating: 0, count: width * sceneRows)
        var depths = [Double](repeating: -.infinity, count: width * sceneRows)

        for point in stationary + dynamic.mesh.points {
            let p = point.position - CoffeeVector(0, 1.03, 0)
            let x = p.x * cy + p.z * sy
            let yawZ = p.z * cy - p.x * sy
            let y = p.y * ce - yawZ * se
            let z = p.y * se + yawZ * ce
            let distance = 7.7 - z
            let column = Int(Double(width) / 2 + x * focal * 2.05 / distance)
            let row = Int(Double(sceneRows) / 2 - y * focal / distance)
            guard column >= 0, column < width, row >= 0, row < sceneRows else { continue }
            let index = row * width + column
            guard z >= depths[index] else { continue }
            let lighting = max(0, coffeeDot(point.normal, light))
            var brightness = 0.16 + 0.73 * lighting
            switch point.material {
            case .glass: brightness *= 0.18
            case .face: brightness = 1
            case .steam: brightness = 0.55
            case .rim: brightness = 0.85 + 0.15 * lighting
            case .coffee: brightness *= 0.24
            case .casing, .mug: break
            }
            let level = min(7, max(0, Int(brightness * 7.99)))
            let hash = Int((p.x + 4) * 79) ^ Int((p.y + 4) * 61) ^ Int((p.z + 4) * 91)
            let dimGlyphs: [UInt8] = [58, 46, 58, 43]
            glyphs[index] = point.glyph ?? (level >= 3 ? UInt8(48 + (hash & 1)) : dimGlyphs[level])
            shades[index] = level + (point.material.isWarm ? 8 : 0)
            depths[index] = z
        }

        var output = [String]()
        output.reserveCapacity(height)
        for row in 0..<sceneRows {
            let start = row * width
            var end = start + width
            while end > start && glyphs[end - 1] == 32 { end -= 1 }
            if !color {
                output.append(String(decoding: glyphs[start..<end], as: UTF8.self))
                continue
            }
            var bytes = [UInt8]()
            bytes.reserveCapacity(width * 8)
            var previous = -1
            for index in start..<end {
                if glyphs[index] != 32 && shades[index] != previous {
                    bytes.append(contentsOf: Self.paletteCodes[shades[index]])
                    previous = shades[index]
                }
                bytes.append(glyphs[index])
            }
            if previous >= 0 { bytes.append(contentsOf: [27, 91, 48, 109]) }
            output.append(String(decoding: bytes, as: UTF8.self))
        }
        let status = seconds == 0 ? "COFFEE FINISHED" : "\(dynamic.sipping ? "SIPPING" : "STAYING AWAKE") / \(timeLabel)"
        output.append(Self.center("D R I N K   C O F F E E", width: width, shade: 6, color: color))
        output.append(Self.center(status, width: width, shade: 4, color: color))
        output.append("")
        output.append(Self.center("Ctrl+C to finish early", width: width, shade: 3, color: color))
        return output.joined(separator: "\n")
    }

    private static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let tail = String(format: "%02d", seconds % 60)
        if minutes >= 60 {
            return "\(minutes / 60):" + String(format: "%02d", minutes % 60) + ":" + tail
        }
        return String(format: "%02d", minutes) + ":" + tail
    }

    private static func center(_ text: String, width: Int, shade: Int, color: Bool) -> String {
        let clipped = String(text.prefix(width))
        let padded = String(repeating: " ", count: max(0, (width - clipped.count) / 2)) + clipped
        return color ? String(decoding: paletteCodes[shade], as: UTF8.self) + padded + "\u{1B}[0m" : padded
    }

    private static let paletteCodes: [[UInt8]] = [
        (10, 38, 46), (12, 64, 76), (15, 94, 110), (25, 123, 142),
        (35, 153, 174), (59, 186, 204), (100, 221, 229), (159, 247, 250),
        (48, 24, 9), (79, 41, 12), (118, 63, 16), (155, 88, 22),
        (192, 117, 31), (226, 151, 48), (247, 188, 78), (255, 220, 139)
    ].map { Array("\u{1B}[38;2;\($0.0);\($0.1);\($0.2)m".utf8) }
}

private typealias CoffeeVector = SIMD3<Double>

private func coffeeDot(_ a: CoffeeVector, _ b: CoffeeVector) -> Double {
    a.x * b.x + a.y * b.y + a.z * b.z
}

private func coffeeCross(_ a: CoffeeVector, _ b: CoffeeVector) -> CoffeeVector {
    CoffeeVector(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

private func coffeeUnit(_ a: CoffeeVector) -> CoffeeVector {
    a / max(1e-9, sqrt(coffeeDot(a, a)))
}

private enum CoffeeMaterial {
    case casing, glass, face, steam, mug, rim, coffee
    var isWarm: Bool { self == .mug || self == .rim || self == .coffee }
}

private struct CoffeePoint {
    let position: CoffeeVector
    let normal: CoffeeVector
    let material: CoffeeMaterial
    let glyph: UInt8?
}

private struct CoffeeMesh {
    var points = [CoffeePoint]()
    private static let step = 0.055

    mutating func point(_ p: CoffeeVector, _ normal: CoffeeVector, _ material: CoffeeMaterial = .casing, glyph: UInt8? = nil) {
        points.append(CoffeePoint(position: p, normal: normal, material: material, glyph: glyph))
    }

    mutating func box(_ center: CoffeeVector, _ size: CoffeeVector, _ material: CoffeeMaterial = .casing) {
        for axis in 0..<3 {
            let u = (axis + 1) % 3, v = (axis + 2) % 3
            let nu = max(2, Int(ceil(size[u] / Self.step)))
            let nv = max(2, Int(ceil(size[v] / Self.step)))
            for side in [-1.0, 1.0] {
                var normal = CoffeeVector.zero
                normal[axis] = side
                for i in 0...nu {
                    for j in 0...nv {
                        var p = center
                        p[axis] += side * size[axis] / 2
                        p[u] += size[u] * (Double(i) / Double(nu) - 0.5)
                        p[v] += size[v] * (Double(j) / Double(nv) - 0.5)
                        point(p, normal, material)
                    }
                }
            }
        }
    }

    mutating func rod(_ a: CoffeeVector, _ b: CoffeeVector, _ radius: Double, _ material: CoffeeMaterial = .casing) {
        let axis = coffeeUnit(b - a)
        let tangent = coffeeUnit(coffeeCross(axis, abs(axis.y) < 0.9 ? CoffeeVector(0, 1, 0) : CoffeeVector(1, 0, 0)))
        let bitangent = coffeeCross(axis, tangent)
        let nlong = max(2, Int(ceil(sqrt(coffeeDot(b - a, b - a)) / Self.step)))
        let nr = max(10, Int(ceil(2 * Double.pi * radius / Self.step)))
        for i in 0...nlong {
            let center = a + (b - a) * (Double(i) / Double(nlong))
            for j in 0..<nr {
                let angle = Double(j) * 2 * .pi / Double(nr)
                let normal = tangent * cos(angle) + bitangent * sin(angle)
                point(center + normal * radius, normal, material)
            }
        }
    }

    mutating func ball(_ center: CoffeeVector, _ radius: Double, _ material: CoffeeMaterial = .casing) {
        for i in 0...12 {
            let phi = Double.pi * Double(i) / 12
            for j in 0..<24 {
                let theta = 2 * Double.pi * Double(j) / 24
                let normal = CoffeeVector(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
                point(center + normal * radius, normal, material)
            }
        }
    }

    mutating func torus(_ center: CoffeeVector, _ radius: Double, _ tube: Double, _ material: CoffeeMaterial, handle: Bool = false) {
        for i in 0..<52 {
            let a = 2 * Double.pi * Double(i) / 52
            for j in 0..<10 {
                let b = 2 * Double.pi * Double(j) / 10
                let r = radius + tube * cos(b)
                let p: CoffeeVector
                let normal: CoffeeVector
                if handle {
                    p = CoffeeVector(r * cos(a), r * sin(a), tube * sin(b))
                    normal = CoffeeVector(cos(b) * cos(a), cos(b) * sin(a), sin(b))
                } else {
                    p = CoffeeVector(r * cos(a), tube * sin(b), r * sin(a))
                    normal = CoffeeVector(cos(b) * cos(a), sin(b), cos(b) * sin(a))
                }
                point(center + p, normal, material)
            }
        }
    }

    static func computer() -> CoffeeMesh {
        var mesh = CoffeeMesh()
        mesh.points.reserveCapacity(15000)
        mesh.box(CoffeeVector(0, 1.25, -0.02), CoffeeVector(1.98, 1.43, 0.75))
        mesh.box(CoffeeVector(0, 1.25, 0.383), CoffeeVector(1.72, 1.12, 0.045), .glass)
        mesh.box(CoffeeVector(0, 0.29, -0.02), CoffeeVector(0.32, 0.45, 0.36))
        mesh.box(CoffeeVector(0, 0.065, 0.05), CoffeeVector(1, 0.12, 0.66))
        for x in [0.59, 0.71, 0.82] {
            mesh.ball(CoffeeVector(x, 0.65, 0.405), 0.03, .face)
        }
        for x in [-0.70, -0.52, -0.34, -0.16, 0.02, 0.20, 0.38, 0.56, 0.74] {
            mesh.box(CoffeeVector(x, 1.974, -0.08), CoffeeVector(0.055, 0.014, 0.42), .glass)
        }
        mesh.rod(CoffeeVector(-1.03, 1.04, 0.02), CoffeeVector(-1.39, 0.55, 0.23), 0.11)
        mesh.ball(CoffeeVector(-1.39, 0.55, 0.23), 0.14)
        mesh.rod(CoffeeVector(-1.39, 0.55, 0.23), CoffeeVector(-1.03, 0.155, 0.59), 0.105)
        mesh.ball(CoffeeVector(-1.03, 0.155, 0.59), 0.15)
        return mesh
    }

    static func sip(at time: Double) -> (mesh: CoffeeMesh, sipping: Bool) {
        var mesh = CoffeeMesh()
        mesh.points.reserveCapacity(4000)
        let phase = time.truncatingRemainder(dividingBy: 12)
        func smooth(_ value: Double) -> Double {
            let x = min(1, max(0, value))
            return x * x * (3 - 2 * x)
        }
        let lift = smooth((phase - 1.8) / 2.4) * (1 - smooth((phase - 7.1) / 2.6))
        let restingCup = CoffeeVector(1.52, 0.285, 0.86)
        let sippingCup = CoffeeVector(0.28, 0.995, 0.94)
        let cup = restingCup + (sippingCup - restingCup) * lift
        let hand = cup + CoffeeVector(0.27, -0.10, 0)
        let elbow = CoffeeVector(1.34 + 0.30 * lift, 0.47 + 0.08 * lift, 0.23)
        mesh.rod(CoffeeVector(1.03, 1.04, 0.02), elbow, 0.11)
        mesh.ball(elbow, 0.14)
        mesh.rod(elbow, hand, 0.105)
        mesh.ball(hand, 0.14)
        mesh.rod(cup + CoffeeVector(0, -0.26, 0), cup + CoffeeVector(0, 0.15, 0), 0.23, .mug)
        mesh.torus(cup + CoffeeVector(0, 0.155, 0), 0.23, 0.028, .rim)
        mesh.torus(cup + CoffeeVector(0.29, -0.045, 0), 0.15, 0.038, .mug, handle: true)
        for i in 0..<12 {
            let radius = 0.215 * Double(i) / 11
            for j in 0..<32 {
                let a = 2 * Double.pi * Double(j) / 32
                mesh.point(cup + CoffeeVector(radius * cos(a), 0.13, radius * sin(a)), CoffeeVector(0, 1, 0), .coffee)
            }
        }
        for k in 0..<3 {
            for i in 0..<32 {
                let s = Double(i) / 31
                let x = Double(k - 1) * 0.12 + 0.07 * sin(s * 9 - time * 2.7 + Double(k))
                let z = 0.02 * cos(s * 8 - time * 2)
                mesh.point(cup + CoffeeVector(x, 0.23 + s * 0.65, z), CoffeeVector(0, 0, 1), .steam, glyph: i % 2 == 0 ? 58 : 46)
            }
        }
        let blink = phase < 0.16 || (phase > 10.2 && phase < 10.34)
        let smiling = lift > 0.83
        for side in [-1.0, 1.0] {
            for i in 0..<15 {
                let q = Double(i) / 14
                let x = side * 0.38 + (q - 0.5) * 0.24
                let y = 1.38 + (smiling && !blink ? 0.08 * sin(q * .pi) : 0)
                for dy in (blink || smiling ? [0.0, 0.03] : [-0.07, -0.035, 0, 0.035, 0.07]) {
                    mesh.point(CoffeeVector(x, y + dy, 0.414), CoffeeVector(0, 0, 1), .face, glyph: 35)
                }
            }
        }
        for i in 0..<28 {
            let q = Double(i) / 27
            mesh.point(CoffeeVector((q - 0.5) * 0.48, 1.09 - 0.095 * sin(q * .pi), 0.416), CoffeeVector(0, 0, 1), .face, glyph: 61)
        }
        return (mesh, smiling)
    }
}

// Run on macOS: swift tool/generate_icons.swift
// AppKit renders the single SVG source; RGB PNGs have no iOS-disallowed alpha.
import AppKit

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("assets/identity/collapse.svg")
guard let icon = NSImage(contentsOf: source) else {
    fatalError("Cannot read \(source.path)")
}

var outputs = [
    "web/favicon.png": 16,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
]
for (density, size) in ["mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192] {
    outputs["android/app/src/main/res/mipmap-\(density)/ic_launcher.png"] = size
}

let ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
let manifestData = try Data(contentsOf: root.appendingPathComponent(ios + "Contents.json"))
let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
for entry in manifest["images"] as! [[String: String]] {
    guard let filename = entry["filename"],
          let points = Double(entry["size"]!.split(separator: "x")[0]),
          let scale = Double(entry["scale"]!.dropLast()) else {
        fatalError("Invalid icon size in Contents.json")
    }
    outputs[ios + filename] = Int(points * scale)
}

for (path, size) in outputs.sorted(by: { $0.key < $1.key }) {
    try autoreleasepool {
        let bitmap = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let context = NSGraphicsContext(cgContext: bitmap, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSBitmapImageRep(cgImage: bitmap.makeImage()!)
        let png = image.representation(using: .png, properties: [:])!
        try png.write(to: root.appendingPathComponent(path), options: .atomic)
        let check = NSBitmapImageRep(data: png)!
        precondition(!check.hasAlpha && check.pixelsWide == size && check.pixelsHigh == size)
        print("\(size)x\(size) RGB \(path)")
    }
}

// Finds the pixel boxes of sensitive values or tokens in a still frame with the
// macOS Vision text recognizer. It reads an image file and nothing else.
//
//   swift ocr_boxes.swift <frame.png> values "<value>|<value>|..."
//   swift ocr_boxes.swift <frame.png> tokens ["NAME|EMAIL_ADDRESS|..."]
//   swift ocr_boxes.swift <frame.png> lines
//
// Tokens look like Skyflow vault tokens such as [NAME_AJbrIud]. The optional
// list names the entity types to match and defaults to the five below.
//
// Prints a JSON list of {text, x, y, w, h} in the image's pixels, top-left origin.
// The boxes drift a few pixels vertically, so run fit_boxes.py on them next.
import AppKit
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count >= 3,
      let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("usage: ocr_boxes.swift <frame.png> values|tokens [values]\n".data(using: .utf8)!)
    exit(2)
}
let mode = args[2]
let values = mode == "values" && args.count > 3
    ? args[3].split(separator: "|").map(String.init).sorted { $0.count > $1.count } : []
let types = mode == "tokens" && args.count > 3 ? args[3] : "NAME|EMAIL_ADDRESS|PHONE_NUMBER|CREDIT_CARD|LOCATION"
let width = Double(cg.width), height = Double(cg.height)
// OCR reads a bracket as I or l and an underscore as a space, so match the
// token types loosely rather than the exact token shape.
let loose = types.replacingOccurrences(of: "_", with: "[_ ]*")
let token = try! NSRegularExpression(pattern:
    "[\\[Il|(]?\\s?(?:\(loose))[_ ]+[A-Za-z0-9/]{5,9}[\\]1l|)]?")

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: cg).perform([request])

var found: [[String: Any]] = []
for observation in request.results ?? [] {
    guard let candidate = observation.topCandidates(1).first else { continue }
    let text = candidate.string
    if mode == "lines" { print(text); continue }
    var ranges: [Range<String.Index>] = []
    if mode == "tokens" {
        for m in token.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let r = Range(m.range, in: text) { ranges.append(r) }
        }
    } else {
        for value in values {
            var start = text.startIndex
            while let r = text.range(of: value, range: start..<text.endIndex) {
                if !ranges.contains(where: { $0.overlaps(r) }) { ranges.append(r) }
                start = r.upperBound
            }
        }
    }
    for r in ranges {
        guard let box = try? candidate.boundingBox(for: r)?.boundingBox else { continue }
        found.append([
            "text": String(text[r]),
            "x": box.minX * width, "y": (1 - box.maxY) * height,
            "w": box.width * width, "h": box.height * height,
        ])
    }
}
found.sort { ($0["y"] as! Double, $0["x"] as! Double) < ($1["y"] as! Double, $1["x"] as! Double) }
let data = try JSONSerialization.data(withJSONObject: found, options: [.prettyPrinted])
print(String(data: data, encoding: .utf8)!)

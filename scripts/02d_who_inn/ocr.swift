import Foundation
import PDFKit
import Vision
import AppKit
let args = CommandLine.arguments
let doc = PDFDocument(url: URL(fileURLWithPath: args[1]))!
var out = ""
for i in 0..<doc.pageCount {
  guard let page = doc.page(at: i) else { continue }
  let r = page.bounds(for: .mediaBox); let scale: CGFloat = 3
  let img = page.thumbnail(of: NSSize(width: r.width*scale, height: r.height*scale), for: .mediaBox)
  guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
  let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate; req.usesLanguageCorrection = false
  try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
  let obs = (req.results ?? []).sorted { $0.boundingBox.minY > $1.boundingBox.minY }
  out += "=== page \(i+1)\n" + obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") + "\n"
}
try! out.write(toFile: args[2], atomically: true, encoding: .utf8)

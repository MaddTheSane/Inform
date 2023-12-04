//
//  ThumbnailProvider.swift
//  InformThumb
//
//  Created by C.W. Betts on 2/13/23.
//

import QuickLookThumbnailing
import UniformTypeIdentifiers
import AppKit

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        do {
            
            var isInform6 = false
            var sourceCodeString: String? = nil

            let resKeys = try request.fileURL.resourceValues(forKeys: [.contentTypeKey])
            
            let uti = resKeys.contentType!
            
            switch uti {
                case UTType("org.inform-fiction.source.inform7"),
                UTType("org.inform-fiction.inform7.extension"):
                // ni file

                sourceCodeString = try String(contentsOf: request.fileURL, encoding: .utf8)
                
            case UTType("org.inform-fiction.source.inform6"):
                // inf file

                isInform6 = true
                sourceCodeString = try String(contentsOf: request.fileURL, encoding: .isoLatin1)
                
            case UTType("org.inform-fiction.project"):
                // project file

                isInform6 = false
                sourceCodeString = try? String(contentsOf: request.fileURL.appendingPathComponent("Source").appendingPathComponent("story.ni"), encoding: .utf8)
                
                if sourceCodeString == nil {
                    sourceCodeString = try String(contentsOf: request.fileURL.appendingPathComponent("Source").appendingPathComponent("main.inf"), encoding: .isoLatin1)
                    isInform6 = true

                }
                
            case UTType("org.inform-fiction.xproject"):
                // extension project file

                isInform6 = false
                sourceCodeString = try String(contentsOf: request.fileURL.appendingPathComponent("Source").appendingPathComponent("extension.i7x"), encoding: .utf8)
            default:
                NSLog("Unknown UTI: \(uti)")
                throw CocoaError(.fileReadCorruptFile)
            }
            
            guard let sourceCodeString else {
                throw CocoaError(.fileReadCorruptFile)
            }
            
            // Produce the result
            let size = CGSize(width: 800, height: 840)
            let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: { () -> Bool in
                // Create a suitable storage object and highlighter
                var theIdx = sourceCodeString.startIndex
                _=sourceCodeString.formIndex(&theIdx, offsetBy: 4096, limitedBy: sourceCodeString.endIndex)
                let storage = NSTextStorage(string: String(sourceCodeString[sourceCodeString.startIndex ..< theIdx]))
                IFSyntaxManager.register(storage, name: "Thumbnail", type: isInform6 ? .inform6 : .inform7, intelligence: nil, undoManager: nil)
                
                // Start drawing
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.imageInterpolation = .high
                
                // Draw the background
                let shadow = NSShadow()
                shadow.shadowOffset = NSSize(width: 0, height: -7)
                shadow.shadowBlurRadius = 7
                shadow.set()
                let gradient = NSGradient(starting: NSColor(deviceRed: 0.95, green: 0.95, blue: 0.95, alpha: 1), ending: .white)
                gradient?.draw(in: NSRect(x: 8, y: 16, width: size.width-16, height: size.height - 24), angle: 250)
                NSGraphicsContext.restoreGraphicsState()
                
                // Draw the source text
                storage.draw(in: NSRect(x: 16, y: 24, width: size.width - 32, height: size.height - 40))
                
                // Draw 'Inform'
                let centered = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                centered.alignment = .center
                "Inform".draw(in: .zero, withAttributes: [.font: NSFont.boldSystemFont(ofSize: 64),
                                                          .foregroundColor: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0.6),
                                                          .paragraphStyle: centered])
                // Done with the drawing
                NSGraphicsContext.restoreGraphicsState()
                
                IFSyntaxManager.unregisterTextStorage(storage)

                // Return true if the thumbnail was successfully drawn inside this block.
                return true
            })
            handler(reply, nil)
            
        } catch {
            handler(nil, error)
        }
    }
}

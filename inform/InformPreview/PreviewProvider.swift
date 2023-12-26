//
//  PreviewProvider.swift
//  InformPreview
//
//  Created by C.W. Betts on 2/13/23.
//

import Cocoa
import Quartz

class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
    
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
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        
        let contentType = UTType.rtf // replace with your data type
        
        let reply = QLPreviewReply.init(dataOfContentType: contentType, contentSize: CGSize.init(width: 800, height: 600)) { (replyToUpdate : QLPreviewReply) in

            let storage = NSTextStorage(string: sourceCodeString)
            IFSyntaxManager.register(storage, name: "Thumbnail", type: isInform6 ? .inform6 : .inform7, intelligence: nil, undoManager: nil)

            var theRTF: Data?
            if storage.length > 0 {
                theRTF = storage.rtf(from: NSMakeRange(0, storage.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf.rawValue])
            }
            
            IFSyntaxManager.unregisterTextStorage(storage)
            
            guard let theRTF else {
                throw CocoaError(.fileReadUnknown)
            }
            return theRTF
        }
                
        return reply
    }
}

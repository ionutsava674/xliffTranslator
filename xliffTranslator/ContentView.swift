//
//  ContentView.swift
//  xliffTranslator
//
//  Created by Ionut Sava on 21.01.2023.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @State private var selectedFile: URL?
    var selectedFileName: String {
        selectedFile?.lastPathComponent ?? "no file selected"
    } //cv
    @State private var eol = "\r\n"
    @State private var valSep = ".\t"
    @State private var extractedText = ""
    @State private var extractedLines = [String]()
    @State private var extractedChunked: [String] = []

    var body: some View {
        VStack {
            Button("choose file") {
                browseForFile()
            } //btn
            Text(selectedFileName)
            Button("extract lines") {
                if let el = extractLines( fromXLIFFAtPath: self.selectedFile, onlyWithoutTarget: false) {
                    self.extractedText = el.joined(separator: self.eol)
                    self.extractedLines = el
                }
            } //btn
            .disabled(self.selectedFile == nil)
            HStack {
                    TextEditor(text: $extractedText)
                        .padding()
            } //hs
            Text("\(self.extractedText.count) characters")
            Button("save to breaked docs") {
                saveExtractedBroken( maxChars: 5000)
            } //btn
            .disabled(self.selectedFile == nil)
            Link(destination: URL(string: "https://translate.google.com/?sl=ro&tl=en&op=docs")!) {
                Text("Translate doc")
            } //link
            Divider()
            ForEach(0 ..< extractedChunked.count, id: \.self) { chunkIndex in
                Text(self.extractedChunked[chunkIndex])
            } //fe
        } //vs
        .padding()
    }//body
    func saveExtractedBroken( maxChars: Int) -> Void {
        guard let _ = self.selectedFile,
              !extractedLines.isEmpty else {
            return
        } //gua
        let panel = NSSavePanel()
        panel.title = "Save extracted lines"
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "out.txt"
        guard panel.runModal() == .OK,
              let surl = panel.url else {
            return
        } //gua
        var broken = [[String]]()
        let eolCount = self.eol.count
        let calculatedLengths = self.extractedLines.map({
            $0.count + eolCount
        })
        guard !calculatedLengths.contains(where: { $0 > maxChars }) else {
            return
        }
        var charCounter = 0
        var lastSavedLine = -1
        for i in calculatedLengths.startIndex ..< calculatedLengths.endIndex {
            if charCounter + calculatedLengths[i] > maxChars {
                //time to break
                broken.append(Array( self.extractedLines[ (lastSavedLine + 1) ..< i ] ))
                lastSavedLine = i - 1
                charCounter = 0
            }
            charCounter += calculatedLengths[i]
        } //for
        //last break
        broken.append(Array( self.extractedLines[ (lastSavedLine + 1) ..< calculatedLengths.endIndex ] ))
print("got here")
        self.extractedChunked = broken.map({
            $0.joined(separator: self.eol)
        })
        do {
            let dstloc = surl.deletingLastPathComponent()
            let dstbasefile = surl.deletingPathExtension().lastPathComponent
            let dstext = surl.pathExtension
            for i in broken.startIndex ..< broken.endIndex {
                let dst = dstloc.appendingPathComponent("\(dstbasefile)_\(i + 1)\(dstext)")
                let chunk = broken[i].joined(separator: self.eol)
                try chunk.write(to: dst, atomically: true, encoding: String.Encoding.utf8)
                print("wrote to \(dst.path)")
            } //for
            //NSWorkspace.shared.activateFileViewerSelecting([surl])
        } catch {
            print(error.localizedDescription)
        }
    } //func
    func saveExtracted() -> Void {
        guard let _ = self.selectedFile else {
            return
        } //gua
        let panel = NSSavePanel()
        panel.title = "Save extracted lines"
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "out.txt"
        guard panel.runModal() == .OK,
              let surl = panel.url else {
            return
        } //gua
        do {
            //let url = url.deletingLastPathComponent().appendingPathComponent("out.txt")
            //let surl = URL.downloadsDirectory.appendingPathComponent("out.txt")
            try self.extractedText.write(to: surl, atomically: true, encoding: String.Encoding.utf8)
            //NSWorkspace.shared.activateFileViewerSelecting([surl])
        } catch {
            print(error.localizedDescription)
        }
    } //func
    func browseForFile() -> Void {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            self.selectedFile = panel.url
        } //if
    } //func
    func extractLines( fromXLIFFAtPath path: URL?, onlyWithoutTarget: Bool = true) -> [String]? {

        guard let path = path,
              let data = FileManager.default.contents(atPath: path.path),
              let doc = try? XMLDocument(data: data) else {
            print("Failed to read XLIFF file at path: \(path?.path ?? "nil")")
            return nil
        } //gua
        var output = ["Index\(valSep)Source\(valSep)Note"]
        var index = 0

        for eachXliff in doc.childrenWithName("xliff") {
            for eachFile in eachXliff.childrenWithName("file") {
                if let b = eachFile.firstChild(named: "body") {
                    for eachTU in b.childrenWithName("trans-unit") {
                        if let s = eachTU.firstChild(named: "source") {
                            index += 1
                            let t = eachTU.firstChild( named: "target")
                            if !onlyWithoutTarget || (t == nil) {
                                let c = eachTU.firstChild(named: "note")?.stringValue ?? ""
                                //output += "\(index)\(valSep)\(s.stringValue ?? "")\(valSep)\(c)\(eol)"
                                output.append("\(index)\(valSep)\(s.stringValue ?? "")\(valSep)\(c)")
                            } //if
                        } //if src
                    } //for
                } //if
            } //for
        } //for
        return output
    } //func
} //str


extension XMLNode {
    func childrenWithName(_ name: String) -> [XMLNode] {
        (self.children ?? []).filter({ $0.name == name })
    } //func
    func firstChild(named: String) -> XMLNode? {
        self.children?.first(where: { $0.name == named })
    } //func
} //ext

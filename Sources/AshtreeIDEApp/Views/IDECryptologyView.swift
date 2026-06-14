// IDECryptologyView.swift — Full Lead Edge Cryptology
// Port of ashtreeide.html cryptology section
// Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
// Features: message encrypt, file attach, maze key generation,
// maze interchange dimensions, ZIP export/import, decrypt from ZIP
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
// ZIP implemented natively below (no external dependency)

// MARK: - Cryptology ViewModel

@MainActor
final class CryptologyVM: ObservableObject {

    // State
    @Published var messageText      = ""
    @Published var attachedFiles: [(name: String, data: Data)] = []
    @Published var privateKey       = ""
    @Published var publicKey        = ""
    @Published var outputLog        = ""
    @Published var status           = ""
    @Published var encryptedZip: Data? = nil
    @Published var decryptedOutput: String = ""
    @Published var showDecryptInput = false
    @Published var pastedPrivateKey = ""

    // Maze layers / interchange dims
    @Published var rootMazeLayers: [(w: Int, h: Int, d: Int, mode: String)] = [(w:8,h:8,d:4,mode:"cubic")]
    @Published var interchangeDims: [(id: Int, w: Int, h: Int, d: Int, mode: String)] = []
    @Published var nextDimId = 0

    // Decryption zip
    @Published var decryptionZip: Data? = nil
    @Published var decryptionZipName   = ""
    @Published var decryptedZip: Data? = nil

    // MARK: Key generation

    func generateMazeKeys(editorContent: String) async {
        outputLog = "◈ Generating maze-based keys…\n"
        // Build maze topology from layers
        var allSegments: [[String: Any]] = []
        for layer in rootMazeLayers {
            let segs = generateMazeSegments(w: layer.w, h: layer.h, d: layer.d, mode: layer.mode)
            allSegments.append(["type": layer.mode, "segments": segs, "config": ["w": layer.w, "h": layer.h, "d": layer.d]])
        }
        for dim in interchangeDims {
            let segs = generateMazeSegments(w: dim.w, h: dim.h, d: dim.d, mode: dim.mode)
            allSegments.append(["type": "interchange_\(dim.id)", "segments": segs])
        }

        let combinedSeed = messageText + editorContent + "\(allSegments)"
        let (priv, pub) = await deriveKeyPair(from: combinedSeed)
        privateKey = priv
        publicKey  = pub
        outputLog += "◈ SHA-256 keys generated from maze structure.\n"
        outputLog += "Private: \(priv.prefix(32))…\n"
        outputLog += "Public:  \(pub.prefix(32))…\n"
    }

    private func generateMazeSegments(w: Int, h: Int, d: Int, mode: String) -> Int {
        // LEMAC segment count heuristic
        if mode == "cubic" { return (w*h*d * 3) / 4 }
        return (w*h * 2) / 3
    }

    private func deriveKeyPair(from seed: String) async -> (String, String) {
        let entropy    = seed + "\(Date().timeIntervalSince1970)"
        let privSeed   = sha256Hex(entropy + "priv" + randomHex(8))
        let pubSeed    = sha256Hex(entropy + "pub"  + randomHex(8))
        let privateKey = "DART_PRIV_" + privSeed + randomHex(4) + "END"
        let publicKey  = "DART_PUB_"  + pubSeed  + randomHex(4) + "END"
        return (privateKey, publicKey)
    }

    // MARK: Encrypt

    func encryptAndPackageZip(editorContent: String) async {
        guard !privateKey.isEmpty else {
            outputLog = "⚠ Generate maze keys first.\n"; return
        }
        outputLog = "Encrypting…\n"

        // Combine message + editor + attached files
        var combined = messageText + editorContent
        let fileMetadata: [[String: String]] = attachedFiles.map { f in
            combined += String(f.data.map { Character(UnicodeScalar($0)) })
            return ["name": f.name, "size": "\(f.data.count)"]
        }

        let (shuffled, sequence) = randomInterchange(combined)
        outputLog += "Encrypted \(combined.utf8.count) bytes via interchange.\n"
        outputLog += "Preview: \(String(shuffled.prefix(80)))…\n"

        // Build ZIP in memory using raw zip format
        var zipEntries: [(name: String, data: Data)] = [
            ("encrypted_data.txt",       Data(shuffled.utf8)),
            ("public_key.txt",           Data(publicKey.utf8)),
            ("private_key.txt",          Data(privateKey.utf8)),
            ("shuffle_sequence.json",    Data(jsonString(sequence).utf8)),
            ("files_manifest.json",      Data(jsonString(fileMetadata).utf8)),
        ]
        if !attachedFiles.isEmpty {
            for f in attachedFiles { zipEntries.append(("attached_\(f.name)", f.data)) }
        }

        if let zipData = buildZip(entries: zipEntries) {
            encryptedZip = zipData
            outputLog += "✓ Encrypted ZIP ready — \(zipData.count / 1024) KB\n"
        } else {
            outputLog += "⚠ ZIP build failed.\n"
        }
    }

    // MARK: Decrypt

    func decryptFromZip() async {
        guard let zipData = decryptionZip else {
            outputLog = "⚠ No ZIP file loaded for decryption.\n"; return
        }
        guard !pastedPrivateKey.isEmpty else {
            outputLog = "⚠ Paste your private key to decrypt.\n"; return
        }
        outputLog = "Decrypting…\n"

        // Parse ZIP entries
        guard let entries = extractZip(zipData) else {
            outputLog = "⚠ Failed to read ZIP file.\n"; return
        }

        guard let encData = entries["encrypted_data.txt"].flatMap({ String(data: $0, encoding: .utf8) }) else {
            outputLog = "⚠ encrypted_data.txt not found in ZIP.\n"; return
        }
        guard let seqData = entries["shuffle_sequence.json"],
              let seqStr  = String(data: seqData, encoding: .utf8) else {
            outputLog = "⚠ shuffle_sequence.json not found in ZIP.\n"; return
        }

        // Parse sequence
        guard let seq = parseShuffleSequence(seqStr) else {
            outputLog = "⚠ Could not parse shuffle sequence.\n"; return
        }

        let decrypted = reverseInterchange(encData, sequence: seq)
        decryptedOutput = decrypted
        outputLog += "✓ Decryption complete. \(decrypted.utf8.count) bytes recovered.\n"
        outputLog += "Preview: \(String(decrypted.prefix(200)))\n"

        // Build output ZIP
        if let outZip = buildZip(entries: [("decrypted_content.txt", Data(decrypted.utf8))]) {
            decryptedZip = outZip
            outputLog += "✓ Decrypted ZIP ready.\n"
        }
    }

    // MARK: Interchange cipher

    private func randomInterchange(_ input: String) -> (String, [[Int]]) {
        var chars = Array(input)
        var seq: [[Int]] = []
        for i in 0..<chars.count {
            let j = Int.random(in: 0..<chars.count)
            seq.append([i, j])
            chars.swapAt(i, j)
        }
        return (String(chars), seq)
    }

    private func reverseInterchange(_ input: String, sequence: [[Int]]) -> String {
        var chars = Array(input)
        for pair in sequence.reversed() {
            guard pair.count == 2 else { continue }
            let i = pair[0], j = pair[1]
            guard i < chars.count && j < chars.count else { continue }
            chars.swapAt(i, j)
        }
        return String(chars)
    }

    private func parseShuffleSequence(_ json: String) -> [[Int]]? {
        guard let data = json.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[Int]] else { return nil }
        return arr
    }

    // MARK: ZIP helpers (raw format without ZIPFoundation dependency)

    private func buildZip(entries: [(name: String, data: Data)]) -> Data? {
        var zip = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        func u16(_ v: Int) -> Data { var n = UInt16(v); return Data(bytes: &n, count: 2) }
        func u32(_ v: Int) -> Data { var n = UInt32(v); return Data(bytes: &n, count: 4) }

        for entry in entries {
            let nameBytes  = Data(entry.name.utf8)
            let fileData   = entry.data
            let crc        = crc32(fileData)
            let offset     = UInt32(zip.count)
            offsets.append(offset)

            // Local file header
            var local = Data()
            local += Data([0x50,0x4B,0x03,0x04]) // signature
            local += u16(20)   // version needed
            local += u16(0)    // flags
            local += u16(0)    // compression: stored
            local += u16(0)    // mod time
            local += u16(0)    // mod date
            local += u32(Int(crc))
            local += u32(fileData.count)
            local += u32(fileData.count)
            local += u16(nameBytes.count)
            local += u16(0)    // extra length
            local += nameBytes
            local += fileData
            zip += local

            // Central directory entry
            var cd = Data()
            cd += Data([0x50,0x4B,0x01,0x02])
            cd += u16(20); cd += u16(20); cd += u16(0); cd += u16(0)
            cd += u16(0); cd += u16(0); cd += u16(0)
            cd += u32(Int(crc))
            cd += u32(fileData.count); cd += u32(fileData.count)
            cd += u16(nameBytes.count); cd += u16(0); cd += u16(0)
            cd += u16(0); cd += u16(0)
            cd += u32(0); cd += u32(Int(offset))
            cd += nameBytes
            centralDirectory += cd
        }

        let cdOffset = UInt32(zip.count)
        let cdSize   = UInt32(centralDirectory.count)
        zip += centralDirectory

        // End of central directory
        var eocd = Data()
        eocd += Data([0x50,0x4B,0x05,0x06])
        eocd += u16(0); eocd += u16(0)
        eocd += u16(entries.count); eocd += u16(entries.count)
        eocd += u32(Int(cdSize)); eocd += u32(Int(cdOffset))
        eocd += u16(0)
        zip += eocd
        return zip
    }

    private func extractZip(_ data: Data) -> [String: Data]? {
        var result: [String: Data] = [:]
        var i = 0
        while i + 30 < data.count {
            // Find local file header signature
            let sig = data[i..<i+4]
            if sig != Data([0x50,0x4B,0x03,0x04]) { i += 1; continue }
            let nameLen  = Int(data[i+26]) | (Int(data[i+27]) << 8)
            let extraLen = Int(data[i+28]) | (Int(data[i+29]) << 8)
            let compSize = Int(data[i+18]) | (Int(data[i+19]) << 8) | (Int(data[i+20]) << 16) | (Int(data[i+21]) << 24)
            let nameStart = i + 30
            let dataStart = nameStart + nameLen + extraLen
            guard nameStart + nameLen <= data.count, dataStart + compSize <= data.count else { break }
            let name    = String(data: data[nameStart..<nameStart+nameLen], encoding: .utf8) ?? ""
            let content = data[dataStart..<dataStart+compSize]
            result[name] = content
            i = dataStart + compSize
        }
        return result.isEmpty ? nil : result
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var v = UInt32(i)
            for _ in 0..<8 { v = (v & 1) != 0 ? (v >> 1) ^ 0xEDB88320 : v >> 1 }
            table[i] = v
        }
        for byte in data { crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)] }
        return crc ^ 0xFFFFFFFF
    }

    // MARK: Helpers

    private func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format:"%02x",$0) }.joined()
    }

    private func randomHex(_ length: Int) -> String {
        (0..<length).map { _ in String(format:"%02x", UInt8.random(in: 0...255)) }.joined()
    }

    private func jsonString<T: Encodable>(_ value: T) -> String {
        (try? String(data: JSONEncoder().encode(value), encoding: .utf8)) ?? "[]"
    }

    private func jsonString(_ value: Any) -> String {
        (try? String(data: JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]), encoding: .utf8)) ?? "[]"
    }

    func clearAll() {
        messageText = ""; attachedFiles = []; privateKey = ""; publicKey = ""
        outputLog = ""; encryptedZip = nil; decryptedOutput = ""
        decryptionZip = nil; decryptedZip = nil; pastedPrivateKey = ""
    }
}

// MARK: - Cryptology View

struct IDECryptologyView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @StateObject private var vm = CryptologyVM()

    @State private var showFilePicker     = false
    @State private var showZipPicker      = false
    @State private var showDecryptSection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // ── Header ────────────────────────────────────────────
                HStack(spacing: 5) {
                    Circle().fill(Color(hex:"#ff5f57")).frame(width:8,height:8)
                    Circle().fill(Color(hex:"#febc2e")).frame(width:8,height:8)
                    Circle().fill(Color(hex:"#28c840")).frame(width:8,height:8)
                    Text("◈ LEAD EDGE CRYPTOLOGY")
                        .font(.system(size:9,weight:.semibold,design:.monospaced))
                        .foregroundColor(Color(hex:"#00ffcc")).kerning(1.5)
                }

                Text("Integrate cryptology logic into Ash programs using AshTreeCrypto. Maze geometry provides entropy for SHA-256 key hashing.")
                    .font(.system(size:9,design:.monospaced))
                    .foregroundColor(Color(hex:"#4a5568"))
                    .fixedSize(horizontal:false,vertical:true)

                // ── Message input ─────────────────────────────────────
                CryptoSectionHeader("MESSAGE TO ENCRYPT")
                ZStack(alignment:.topLeading) {
                    TextEditor(text: $vm.messageText)
                        .font(.system(size:11,design:.monospaced))
                        .foregroundColor(Color(hex:"#c9d1d9"))
                        .frame(minHeight:60,maxHeight:100)
                        .background(Color(hex:"#0d1117")).cornerRadius(4)
                    if vm.messageText.isEmpty {
                        Text("Type a message to encrypt (optional)…")
                            .font(.system(size:10,design:.monospaced))
                            .foregroundColor(Color(hex:"#4a5568")).padding(8).allowsHitTesting(false)
                    }
                }

                // ── File attachment ───────────────────────────────────
                CryptoSectionHeader("ATTACH FILES")
                Button {
                    showFilePicker = true
                } label: {
                    Label("Select Files to Encrypt", systemImage:"doc.badge.plus")
                        .font(.system(size:10,weight:.medium,design:.monospaced))
                        .foregroundColor(Color(hex:"#0088ff"))
                        .padding(.vertical,6).padding(.horizontal,10)
                        .background(Color(hex:"#0088ff").opacity(0.1))
                        .cornerRadius(5)
                }
                .fileImporter(isPresented:$showFilePicker,
                              allowedContentTypes:[.item],
                              allowsMultipleSelection:true) { result in
                    if case .success(let urls) = result {
                        for url in urls {
                            _ = url.startAccessingSecurityScopedResource()
                            if let data = try? Data(contentsOf: url) {
                                vm.attachedFiles.append((name: url.lastPathComponent, data: data))
                            }
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }

                if !vm.attachedFiles.isEmpty {
                    VStack(alignment:.leading,spacing:2) {
                        ForEach(vm.attachedFiles, id:\.name) { f in
                            HStack {
                                Image(systemName:"doc.fill").font(.system(size:10)).foregroundColor(Color(hex:"#0088ff"))
                                Text(f.name).font(.system(size:9,design:.monospaced)).foregroundColor(Color(hex:"#8ab4cc"))
                                Text("(\(f.data.count / 1024) KB)").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568"))
                                Spacer()
                                Button { vm.attachedFiles.removeAll{$0.name==f.name} } label: {
                                    Image(systemName:"xmark").font(.system(size:9)).foregroundColor(Color(hex:"#ff4466"))
                                }
                            }
                        }
                    }
                    .padding(8).background(Color(hex:"#0d1117")).cornerRadius(4)
                }

                // ── Maze layer configuration ──────────────────────────
                CryptoSectionHeader("ROOT MAZE LAYERS")
                ForEach(vm.rootMazeLayers.indices, id:\.self) { i in
                    CryptoMazeLayerRow(layer: $vm.rootMazeLayers[i], onDelete: {
                        vm.rootMazeLayers.remove(at:i)
                    })
                }
                Button {
                    vm.rootMazeLayers.append((w:6,h:6,d:4,mode:"cubic"))
                } label: {
                    Label("Add Root Maze Layer", systemImage:"plus.square")
                        .font(.system(size:9,design:.monospaced)).foregroundColor(Color(hex:"#00ffcc"))
                }

                CryptoSectionHeader("INTERCHANGE DIMENSIONS")
                ForEach(vm.interchangeDims.indices, id:\.self) { i in
                    CryptoInterchangeDimRow(dim: $vm.interchangeDims[i], onDelete: {
                        vm.interchangeDims.remove(at:i)
                    })
                }
                Button {
                    vm.interchangeDims.append((id:vm.nextDimId, w:5, h:5, d:3, mode:"planar"))
                    vm.nextDimId += 1
                } label: {
                    Label("Add Interchange Dimension", systemImage:"arrow.left.arrow.right")
                        .font(.system(size:9,design:.monospaced)).foregroundColor(Color(hex:"#0088ff"))
                }

                // ── Key generation ────────────────────────────────────
                CryptoSectionHeader("MAZE KEYS")
                HStack(spacing:8) {
                    CryptoBtn(label:"◈ Generate Keys", color:Color(hex:"#00ffcc")) {
                        Task { await vm.generateMazeKeys(editorContent: ideVM.sourceCode) }
                    }
                    CryptoBtn(label:"✕ Clear All", color:Color(hex:"#ff4466")) { vm.clearAll() }
                }

                if !vm.privateKey.isEmpty {
                    VStack(alignment:.leading,spacing:4) {
                        CryptoKeyRow(label:"Private Key", value:vm.privateKey)
                        CryptoKeyRow(label:"Public Key",  value:vm.publicKey)
                    }
                    .padding(8).background(Color(hex:"#0a1628")).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius:6).stroke(Color(hex:"#21262d"),lineWidth:0.5))
                }

                // ── Encrypt / Download ────────────────────────────────
                CryptoSectionHeader("ENCRYPT & EXPORT")
                CryptoBtn(label:"▲ Encrypt → ZIP", color:Color(hex:"#00ffcc")) {
                    Task { await vm.encryptAndPackageZip(editorContent: ideVM.sourceCode) }
                }

                if let zipData = vm.encryptedZip {
                    ShareLink(item:zipData, preview: SharePreview("encrypted_ash_tree.zip")) {
                        Label("⬇ Download Encrypted ZIP", systemImage:"arrow.down.doc")
                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                            .foregroundColor(Color(hex:"#e5c07b"))
                            .padding(.vertical,7).padding(.horizontal,12)
                            .background(Color(hex:"#e5c07b").opacity(0.1))
                            .cornerRadius(5)
                    }
                }

                // ── Decrypt ───────────────────────────────────────────
                Divider().background(Color(hex:"#21262d"))
                Button {
                    withAnimation { showDecryptSection.toggle() }
                } label: {
                    HStack {
                        Text("▼ DECRYPT FROM ZIP")
                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                            .foregroundColor(Color(hex:"#0088ff")).kerning(1)
                        Spacer()
                        Image(systemName: showDecryptSection ? "chevron.up" : "chevron.down")
                            .font(.system(size:10)).foregroundColor(Color(hex:"#4a5568"))
                    }
                }

                if showDecryptSection {
                    VStack(alignment:.leading,spacing:8) {
                        // Upload ZIP
                        Button { showZipPicker = true } label: {
                            Label(vm.decryptionZipName.isEmpty ? "Select Encrypted ZIP" : vm.decryptionZipName,
                                  systemImage:"doc.zipper")
                                .font(.system(size:9,design:.monospaced))
                                .foregroundColor(Color(hex:"#0088ff"))
                                .padding(.vertical,6).padding(.horizontal,10)
                                .background(Color(hex:"#0088ff").opacity(0.1)).cornerRadius(5)
                        }
                        .fileImporter(isPresented:$showZipPicker, allowedContentTypes:[.zip]) { result in
                            if case .success(let url) = result {
                                _ = url.startAccessingSecurityScopedResource()
                                vm.decryptionZip  = try? Data(contentsOf: url)
                                vm.decryptionZipName = url.lastPathComponent
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        ZStack(alignment:.topLeading) {
                            TextEditor(text: $vm.pastedPrivateKey)
                                .font(.system(size:9,design:.monospaced))
                                .foregroundColor(Color(hex:"#c9d1d9"))
                                .frame(minHeight:50,maxHeight:80)
                                .background(Color(hex:"#0d1117")).cornerRadius(4)
                            if vm.pastedPrivateKey.isEmpty {
                                Text("Paste private key here…")
                                    .font(.system(size:9,design:.monospaced))
                                    .foregroundColor(Color(hex:"#4a5568")).padding(8).allowsHitTesting(false)
                            }
                        }

                        CryptoBtn(label:"▼ Decrypt", color:Color(hex:"#bf5fff")) {
                            Task { await vm.decryptFromZip() }
                        }

                        if let dZip = vm.decryptedZip {
                            ShareLink(item:dZip, preview: SharePreview("decrypted_output.zip")) {
                                Label("⬇ Download Decrypted ZIP", systemImage:"arrow.down.doc")
                                    .font(.system(size:9,weight:.semibold,design:.monospaced))
                                    .foregroundColor(Color(hex:"#e5c07b"))
                                    .padding(.vertical,7).padding(.horizontal,12)
                                    .background(Color(hex:"#e5c07b").opacity(0.1)).cornerRadius(5)
                            }
                        }
                    }
                    .transition(.move(edge:.top).combined(with:.opacity))
                }

                // ── Output log ────────────────────────────────────────
                if !vm.outputLog.isEmpty {
                    Divider().background(Color(hex:"#21262d"))
                    Text("OUTPUT")
                        .font(.system(size:7,weight:.semibold,design:.monospaced))
                        .foregroundColor(Color(hex:"#4a5568")).kerning(1.5)
                    Text(vm.outputLog)
                        .font(.system(size:9,design:.monospaced))
                        .foregroundColor(Color(hex:"#4a8a7a"))
                        .fixedSize(horizontal:false,vertical:true)
                        .padding(8).background(Color(hex:"#0d1117")).cornerRadius(4)
                }
            }
            .padding(12)
        }
    }
}

// MARK: Sub-views

struct CryptoSectionHeader: View {
    let t: String; init(_ t: String) { self.t = t }
    var body: some View {
        Text(t).font(.system(size:7,weight:.semibold,design:.monospaced))
            .foregroundColor(Color(hex:"#4a5568")).kerning(1.5)
    }
}

struct CryptoBtn: View {
    let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action:action) {
            Text(label).font(.system(size:9,weight:.semibold,design:.monospaced))
                .foregroundColor(color).frame(maxWidth:.infinity)
                .padding(.vertical,7).background(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius:4).stroke(color.opacity(0.25),lineWidth:0.5))
                .cornerRadius(4)
        }
    }
}

struct CryptoKeyRow: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment:.leading,spacing:2) {
            Text(label).font(.system(size:7,weight:.semibold,design:.monospaced))
                .foregroundColor(Color(hex:"#4a5568")).kerning(1)
            HStack {
                Text(value.prefix(36)+"…").font(.system(size:8,design:.monospaced))
                    .foregroundColor(Color(hex:"#00ffcc"))
                Spacer()
                Button { UIPasteboard.general.string = value } label: {
                    Image(systemName:"doc.on.doc").font(.system(size:10))
                        .foregroundColor(Color(hex:"#4a5568"))
                }
            }
        }
    }
}

struct CryptoMazeLayerRow: View {
    @Binding var layer: (w: Int, h: Int, d: Int, mode: String)
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            HStack {
                Text("ROOT MAZE LAYER")
                    .font(.system(size:7,weight:.semibold,design:.monospaced))
                    .foregroundColor(Color(hex:"#00ffcc"))
                Spacer()
                Button(action:onDelete) {
                    Image(systemName:"minus.circle")
                        .font(.system(size:12)).foregroundColor(Color(hex:"#ff4466"))
                }
            }
            HStack(spacing:8) {
                Text("W").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568"))
                Stepper("\(layer.w)",value:$layer.w,in:3...50)
                    .font(.system(size:9,design:.monospaced)).labelsHidden()
                Text("H").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568"))
                Stepper("\(layer.h)",value:$layer.h,in:3...50)
                    .font(.system(size:9,design:.monospaced)).labelsHidden()
                Text("D").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568"))
                Stepper("\(layer.d)",value:$layer.d,in:1...20)
                    .font(.system(size:9,design:.monospaced)).labelsHidden()
            }
            Text("W:\(layer.w)  H:\(layer.h)  D:\(layer.d)")
                .font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#8ab4cc"))
        }
        .padding(8).background(Color(hex:"#0a1628")).cornerRadius(6)
    }
}

struct CryptoInterchangeDimRow: View {
    @Binding var dim: (id: Int, w: Int, h: Int, d: Int, mode: String)
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            HStack {
                Text("DIM \(dim.id)")
                    .font(.system(size:7,weight:.semibold,design:.monospaced))
                    .foregroundColor(Color(hex:"#0088ff"))
                Picker("",selection:$dim.mode){
                    Text("Cubic").tag("cubic")
                    Text("Planar").tag("planar")
                }.pickerStyle(.segmented).frame(maxWidth:120)
                Spacer()
                Button(action:onDelete) {
                    Image(systemName:"minus.circle")
                        .font(.system(size:12)).foregroundColor(Color(hex:"#ff4466"))
                }
            }
            HStack(spacing:8) {
                Text("W").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568"))
                Stepper("\(dim.w)",value:$dim.w,in:3...30)
                    .font(.system(size:9,design:.monospaced)).labelsHidden()
                Text("H").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568"))
                Stepper("\(dim.h)",value:$dim.h,in:3...30)
                    .font(.system(size:9,design:.monospaced)).labelsHidden()
            }
            Text("W:\(dim.w)  H:\(dim.h)  Mode:\(dim.mode)")
                .font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#8ab4cc"))
        }
        .padding(8).background(Color(hex:"#0a1628")).cornerRadius(6)
    }
}

// Make Data transferable for ShareLink
extension Data: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .data) { $0 } importing: { $0 }
    }
}

// IDEProjectSystem.swift
// Full project management system for Ash Tree IDE
// © 2025 DART Meadow | Radical Deepscale LLC.
//
// A Project is a named container of files + folders.
// Projects are stored in UserDefaults under "ide_projects" as JSON.
// Each project can optionally sync to a GitHub repository.
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Node (file or folder)

public struct IDEFileNode: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var isFolder: Bool
    public var children: [IDEFileNode]?  // nil = file, [] = empty folder
    public var language: String          // e.g. "ash", "html", "python"

    public var ext: String {
        IDELanguageEnv.find(id: language).ext
    }
    public var icon: String {
        if isFolder { return "folder.fill" }
        switch language {
        case "html":       return "globe"
        case "css":        return "paintbrush"
        case "javascript", "threejs", "react", "vue": return "j.square"
        case "typescript": return "t.square"
        case "python", "python_ml": return "p.circle"
        case "bash":       return "terminal"
        case "ruby":       return "diamond"
        case "swift":      return "swift"
        case "rust":       return "gearshape.2"
        case "go":         return "g.circle"
        case "cpp":        return "c.square"
        case "kotlin":     return "k.circle"
        case "dart":       return "d.circle"
        case "sql":        return "tablecells"
        case "r":          return "r.circle"
        case "php":        return "p.square"
        default:           return "doc.text"
        }
    }
    public var displayName: String { name }
    public var fullPath: String { name }  // within project

    public static func newFile(name: String, language: String) -> IDEFileNode {
        IDEFileNode(id: UUID().uuidString, name: name, isFolder: false,
                    children: nil, language: language)
    }
    public static func newFolder(name: String) -> IDEFileNode {
        IDEFileNode(id: UUID().uuidString, name: name, isFolder: true,
                    children: [], language: "ash")
    }
}

// MARK: - Project Model

public struct IDEProject: Identifiable, Codable {
    public let id: String
    public var name: String
    public var primaryLanguage: String     // main language for new files
    public var files: [IDEFileNode]        // top-level files + folders
    public var repoOwner: String?          // GitHub owner if synced
    public var repoName: String?           // GitHub repo name if synced
    public var syncEnabled: Bool           // auto-push on save
    public var createdAt: Double           // timestamp
    public var modifiedAt: Double

    // Flat list of all file paths in the project
    public var allFilePaths: [String] {
        flatPaths(nodes: files, prefix: "")
    }
    private func flatPaths(nodes: [IDEFileNode], prefix: String) -> [String] {
        var result: [String] = []
        for node in nodes {
            let path = prefix.isEmpty ? node.name : "\(prefix)/\(node.name)"
            if node.isFolder, let children = node.children {
                result.append(contentsOf: flatPaths(nodes: children, prefix: path))
            } else {
                result.append(path)
            }
        }
        return result
    }

    // Content key for UserDefaults
    public func contentKey(for path: String) -> String {
        "ide_proj_\(id)_\(path)"
    }

    // Default template files for a language
    public static func defaultFiles(for languageId: String, projectName: String) -> [IDEFileNode] {
        let env = IDELanguageEnv.find(id: languageId)
        switch languageId {
        case "html":
            return [
                IDEFileNode.newFile(name: "index.html",  language: "html"),
                IDEFileNode.newFile(name: "style.css",   language: "css"),
                IDEFileNode.newFile(name: "script.js",   language: "javascript"),
                IDEFileNode.newFolder(name: "assets"),
            ]
        case "python", "python_ml":
            return [
                IDEFileNode.newFile(name: "main.py",        language: "python"),
                IDEFileNode.newFile(name: "requirements.txt", language: "ash"),
                IDEFileNode.newFolder(name: "src"),
            ]
        case "react":
            return [
                IDEFileNode.newFile(name: "App.jsx",       language: "react"),
                IDEFileNode.newFile(name: "index.html",    language: "html"),
                IDEFileNode.newFile(name: "index.css",     language: "css"),
                IDEFileNode.newFolder(name: "components"),
            ]
        case "threejs":
            return [
                IDEFileNode.newFile(name: "index.html",   language: "html"),
                IDEFileNode.newFile(name: "main.js",      language: "threejs"),
                IDEFileNode.newFile(name: "style.css",    language: "css"),
            ]
        case "swift":
            return [
                IDEFileNode.newFile(name: "\(projectName).swift", language: "swift"),
                IDEFileNode.newFolder(name: "Sources"),
            ]
        case "cpp":
            return [
                IDEFileNode.newFile(name: "main.cpp",    language: "cpp"),
                IDEFileNode.newFile(name: "CMakeLists.txt", language: "ash"),
            ]
        default:
            let fname = projectName.lowercased().replacingOccurrences(of:" ",with:"_")
            return [IDEFileNode.newFile(name: fname + env.ext, language: languageId)]
        }
    }

    // Starter content for each template file
    public static func starterContent(node: IDEFileNode, projectName: String) -> String {
        let env = IDELanguageEnv.find(id: node.language)
        switch node.language {
        case "html":
            if node.name.hasSuffix(".txt") || node.name == "requirements.txt" { return "" }
            return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>\(projectName)</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>\(projectName)</h1>
    <script src="script.js"></script>
</body>
</html>
"""
        case "css":
            return """
/* \(projectName) — styles */
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    background: #0d1117;
    color: #c9d1d9;
    font-family: monospace;
}
h1 { color: #00ffcc; padding: 20px; }
"""
        case "javascript", "threejs":
            if node.name.hasSuffix(".js") && node.name.contains("main") && node.language == "threejs" {
                return """
// Three.js Scene — \(projectName)
import * as THREE from 'https://cdn.skypack.dev/three@0.152.0';

const scene    = new THREE.Scene();
const camera   = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

const geometry = new THREE.BoxGeometry(1, 1, 1);
const material = new THREE.MeshStandardMaterial({ color: 0x00ffcc });
const cube     = new THREE.Mesh(geometry, material);
scene.add(cube);

const light = new THREE.DirectionalLight(0xffffff, 1);
light.position.set(5, 5, 5);
scene.add(light);
camera.position.z = 3;

function animate() {
    requestAnimationFrame(animate);
    cube.rotation.x += 0.01;
    cube.rotation.y += 0.01;
    renderer.render(scene, camera);
}
animate();
"""
            }
            return """
// \(projectName) — JavaScript
'use strict';

document.addEventListener('DOMContentLoaded', () => {
    console.log('\(projectName) loaded');
});
"""
        case "python", "python_ml":
            if node.name == "requirements.txt" {
                return node.language == "python_ml"
                    ? "numpy\npandas\ntorch\nscikit-learn\n"
                    : "# Add dependencies here\n"
            }
            return """
#!/usr/bin/env python3
# \(projectName)

def main():
    print("Hello from \(projectName)")

if __name__ == "__main__":
    main()
"""
        case "react":
            if node.name.hasSuffix(".jsx") {
                return """
// \(projectName) — React App
import React, { useState } from 'react';

function App() {
    const [count, setCount] = useState(0);
    return (
        <div className="App">
            <h1>\(projectName)</h1>
            <button onClick={() => setCount(c => c + 1)}>
                Count: {count}
            </button>
        </div>
    );
}

export default App;
"""
            }
            return ""
        case "swift":
            return """
// \(projectName) — Swift
import Foundation

struct \(projectName.replacingOccurrences(of:" ",with:"").capitalized) {
    var greeting = "Hello, World!"
}

let app = \(projectName.replacingOccurrences(of:" ",with:"").capitalized)()
print(app.greeting)
"""
        case "cpp":
            return """
// \(projectName) — C++
#include <iostream>
#include <string>

int main() {
    std::cout << "Hello from \(projectName)!" << std::endl;
    return 0;
}
"""
        default:
            // Ash or unknown — use Ash template
            return """
// \(node.name)
// \(projectName) · Ash Edge Language · LEATR v2
{{env:\(projectName.replacingOccurrences(of:" ",with:""))}}
[[script:\(node.name.replacingOccurrences(of:".ash",with:""))]]
[poly: data-matrix]

(MainNode):-: {
    with var (s) {
        irin ("Hello: \(projectName)")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|';'|
"""
        }
    }
}

// MARK: - Project Store

@MainActor
public final class IDEProjectStore: ObservableObject {
    public static let shared = IDEProjectStore()

    @Published public var projects: [IDEProject] = []
    @Published public var activeProjectId: String? = nil
    @Published public var activeFilePath: String? = nil
    @Published public var expandedFolders: Set<String> = []

    // Load immediately on init so first render has data
    private init() { load() }

    public var activeProject: IDEProject? {
        guard let id = activeProjectId else { return nil }
        return projects.first { $0.id == id }
    }

    // MARK: Persistence

    public func load() {
        guard let data = UserDefaults.standard.data(forKey: "ide_projects_v2"),
              let loaded = try? JSONDecoder().decode([IDEProject].self, from: data)
        else { return }
        projects = loaded
        activeProjectId = UserDefaults.standard.string(forKey: "ide_active_project")
    }

    public func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "ide_projects_v2")
        }
        UserDefaults.standard.set(activeProjectId, forKey: "ide_active_project")
        UserDefaults.standard.synchronize()
    }

    // MARK: CRUD

    public func createProject(name: String, language: String) -> IDEProject {
        let files   = IDEProject.defaultFiles(for: language, projectName: name)
        let project = IDEProject(
            id: UUID().uuidString, name: name, primaryLanguage: language,
            files: files, repoOwner: nil, repoName: nil, syncEnabled: false,
            createdAt: Date().timeIntervalSince1970,
            modifiedAt: Date().timeIntervalSince1970
        )
        // Write starter content for each file
        for node in files where !node.isFolder {
            let content = IDEProject.starterContent(node: node, projectName: name)
            UserDefaults.standard.set(content, forKey: project.contentKey(for: node.name))
        }
        projects.append(project)
        activeProjectId = project.id
        save()
        return project
    }

    public func deleteProject(_ id: String) {
        guard let proj = projects.first(where: {$0.id == id}) else { return }
        // Remove all file contents from UserDefaults
        for path in proj.allFilePaths {
            UserDefaults.standard.removeObject(forKey: proj.contentKey(for: path))
        }
        projects.removeAll { $0.id == id }
        if activeProjectId == id { activeProjectId = projects.first?.id }
        save()
    }

    public func renameProject(_ id: String, to name: String) {
        guard let idx = projects.firstIndex(where: {$0.id == id}) else { return }
        projects[idx].name = name
        projects[idx].modifiedAt = Date().timeIntervalSince1970
        save()
    }

    public func setActive(_ id: String) {
        activeProjectId = id
        activeFilePath  = nil
        save()
    }

    // MARK: File operations within a project

    public func addFile(to projectId: String, name: String, language: String,
                        inFolder folderName: String? = nil) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        let node = IDEFileNode.newFile(name: name, language: language)
        let content = IDEProject.starterContent(node: node,
                                                projectName: projects[idx].name)
        UserDefaults.standard.set(content, forKey: projects[idx].contentKey(for: name))
        if let folder = folderName {
            addNodeToFolder(&projects[idx].files, folder: folder, node: node)
        } else {
            projects[idx].files.append(node)
        }
        projects[idx].modifiedAt = Date().timeIntervalSince1970
        save()
    }

    public func addFolder(to projectId: String, name: String, inFolder: String? = nil) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        let node = IDEFileNode.newFolder(name: name)
        if let folder = inFolder {
            addNodeToFolder(&projects[idx].files, folder: folder, node: node)
        } else {
            projects[idx].files.append(node)
        }
        projects[idx].modifiedAt = Date().timeIntervalSince1970
        save()
    }

    public func deleteFile(in projectId: String, path: String) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        UserDefaults.standard.removeObject(forKey: projects[idx].contentKey(for: path))
        removeNode(&projects[idx].files, name: path.components(separatedBy:"/").last ?? path)
        projects[idx].modifiedAt = Date().timeIntervalSince1970
        if activeFilePath == path { activeFilePath = nil }
        save()
    }

    public func readFile(in projectId: String, path: String) -> String {
        guard let proj = projects.first(where: {$0.id == projectId}) else { return "" }
        return UserDefaults.standard.string(forKey: proj.contentKey(for: path)) ?? ""
    }

    public func writeFile(in projectId: String, path: String, content: String) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        UserDefaults.standard.set(content, forKey: projects[idx].contentKey(for: path))
        projects[idx].modifiedAt = Date().timeIntervalSince1970
        UserDefaults.standard.synchronize()
        // Auto-sync to GitHub if enabled
        if projects[idx].syncEnabled,
           let owner = projects[idx].repoOwner,
           let repo  = projects[idx].repoName {
            Task {
                try? await IDEGitHubClient.shared.writeFile(
                    owner: owner, repo: repo, path: path,
                    content: content, message: "Ash Tree IDE: \(path)")
            }
        }
    }

    public func importFile(in projectId: String, name: String, data: Data) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        let ext  = URL(fileURLWithPath: name).pathExtension
        let lang = IDELanguageEnv.all.first { $0.ext == "." + ext }?.id ?? "ash"
        let node = IDEFileNode.newFile(name: name, language: lang)
        let content = String(data: data, encoding: .utf8) ?? ""
        UserDefaults.standard.set(content, forKey: projects[idx].contentKey(for: name))
        projects[idx].files.append(node)
        projects[idx].modifiedAt = Date().timeIntervalSince1970
        save()
    }

    // MARK: GitHub repo operations

    public func linkRepo(projectId: String, owner: String, repo: String) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        projects[idx].repoOwner   = owner
        projects[idx].repoName    = repo
        projects[idx].syncEnabled = true
        save()
    }

    public func unlinkRepo(projectId: String) {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        projects[idx].repoOwner   = nil
        projects[idx].repoName    = nil
        projects[idx].syncEnabled = false
        save()
    }

    public func pushProjectToNewRepo(projectId: String, repoName: String,
                                     owner: String, isPrivate: Bool) async throws {
        guard let idx = projects.firstIndex(where: {$0.id == projectId}) else { return }
        let proj = projects[idx]
        // Create repo
        let created = try await IDEGitHubClient.shared.createRepo(name: repoName, isPrivate: isPrivate)
        // Push all files
        for path in proj.allFilePaths {
            let content = readFile(in: projectId, path: path)
            try await IDEGitHubClient.shared.writeFile(
                owner: owner, repo: repoName, path: path,
                content: content, message: "Initial commit from Ash Tree IDE")
        }
        linkRepo(projectId: projectId, owner: owner, repo: repoName)
    }

    public func syncProjectFromRepo(projectId: String) async throws {
        guard let proj = projects.first(where: {$0.id == projectId}),
              let owner = proj.repoOwner, let repo = proj.repoName else { return }
        // Fetch file list and update local copies
        let repoFiles = try await IDEGitHubClient.shared.listFiles(owner: owner, repo: repo)
        for f in repoFiles where f.type == "file" {
            let content = try await IDEGitHubClient.shared.readFile(
                owner: owner, repo: repo, path: f.path)
            writeFile(in: projectId, path: f.path, content: content)
        }
    }

    // MARK: Tree helpers

    private func addNodeToFolder(_ nodes: inout [IDEFileNode], folder: String, node: IDEFileNode) {
        for i in nodes.indices {
            if nodes[i].isFolder && nodes[i].name == folder {
                nodes[i].children?.append(node); return
            }
            if var children = nodes[i].children {
                addNodeToFolder(&children, folder: folder, node: node)
                nodes[i].children = children
            }
        }
    }

    private func removeNode(_ nodes: inout [IDEFileNode], name: String) {
        nodes.removeAll { $0.name == name }
        for i in nodes.indices where nodes[i].isFolder {
            removeNode(&nodes[i].children!, name: name)
        }
    }
}

// IDELanguageEnvironment.swift
// Ash Tree IDE · Multi-language environment system
// © 2025 DART Meadow | Radical Deepscale LLC.
//
// All non-Ash languages stay in Ash syntax.
// The language environment tells the IDE which wrapper nodes
// and file extension to use. Export converts the Ash wrapper
// to native output (HTML file, .py file, etc.)
import SwiftUI

// MARK: - Language Environment Model

public struct IDELanguageEnv: Identifiable, Hashable {
    public let id: String          // unique key e.g. "ash", "python"
    public let name: String        // display name
    public let icon: String        // SF Symbol
    public let ext: String         // file extension e.g. ".ash", ".py"
    public let category: Category  // for grouping in the picker
    public let color: String       // hex accent color
    public let ashWrapper: String  // the Ash node block that wraps this env
    public let templateCode: String // starter template code in Ash syntax

    public enum Category: String, CaseIterable {
        case native    = "Native"
        case web       = "Web"
        case scripting = "Scripting"
        case data      = "Data & ML"
        case systems   = "Systems"
        case mobile    = "Mobile"
        case other     = "Other"
    }

    // MARK: - All supported environments

    public static let all: [IDELanguageEnv] = [

        // ── Native Ash (default) ─────────────────────────────
        IDELanguageEnv(
            id: "ash", name: "Ash Edge Language", icon: "tree.fill", ext: ".ash",
            category: .native, color: "#00ffcc",
            ashWrapper: "",   // no wrapper — pure Ash
            templateCode: """
// Ash Edge Language · LEATR v2
// © 2025 DART Meadow | Radical Deepscale LLC.
{{env:MyProject}}
[[script:main]]
[poly: data-matrix]
[net: layer-0]

(MainNode):-: {
    with var (s) {
        irin ("Hello: World")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        // ── Web ─────────────────────────────────────────────
        IDELanguageEnv(
            id: "html", name: "HTML5", icon: "globe", ext: ".html",
            category: .web, color: "#e34c26",
            ashWrapper: "(HTMLNode)",
            templateCode: """
// HTML5 via Ash Edge Language
{{env:WebProject}}
[[script:html-doc]]
[poly: dom-tree]

(HTMLNode):-: {
    irin ("doctype:html lang:en title:My Page")
    gl.dom
    thenplace var (html) with var (doc)
    irout ("Result: " placeto (html))
}|\';\'|

(HeadNode):-: {
    with var (meta) {
        irin ("charset:UTF-8 viewport:width=device-width,initial-scale=1")
        thenplace var (meta) with var (meta)
    }
    irout ("Result: " placeto (meta))
}|\';\'|

(BodyNode):-: {
    with var (content) {
        irin ("tag:h1 text:Hello World")
        irin ("tag:p text:Built with Ash Edge Language")
        thenplace var (content) with var (content)
    }
    irout ("Result: " placeto (content))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "css", name: "CSS3", icon: "paintbrush", ext: ".css",
            category: .web, color: "#264de4",
            ashWrapper: "(CSSNode)",
            templateCode: """
// CSS3 via Ash Edge Language
{{env:StyleProject}}
[[script:stylesheet]]
[poly: style-tree]

(CSSNode):-: {
    irin ("selector:body bg:#0d1117 color:#c9d1d9 font:monospace")
    thenplace var (s) with var (s)
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "javascript", name: "JavaScript", icon: "j.square", ext: ".js",
            category: .web, color: "#f7df1e",
            ashWrapper: "(JSNode)",
            templateCode: """
// JavaScript via Ash Edge Language
{{env:JSProject}}
[[script:js-main]]
[poly: js-runtime]
[net: event-loop]

(JSNode):-: {
    with var (ctx) {
        irin ("runtime:browser strict:true")
        thenplace var (ctx) with var (ctx)
    }
    irout ("Result: " placeto (ctx))
}|\';\'|

(FunctionNode):-: {
    with var (fn) var (result) {
        irin ("name:main args:none body:console.log")
        thenplace var (result) with var (fn)
    }
    irout ("Result: " placeto (result))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "typescript", name: "TypeScript", icon: "t.square", ext: ".ts",
            category: .web, color: "#3178c6",
            ashWrapper: "(TSNode)",
            templateCode: """
// TypeScript via Ash Edge Language
{{env:TSProject}}
[[script:ts-main]]
[poly: ts-runtime]

(TSNode):-: {
    with var (ctx) {
        irin ("runtime:node strict:true module:commonjs")
        thenplace var (ctx) with var (ctx)
    }
    irout ("Result: " placeto (ctx))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "threejs", name: "Three.js", icon: "cube", ext: ".js",
            category: .web, color: "#049ef4",
            ashWrapper: "(ThreeJSNode)",
            templateCode: """
// Three.js 3D Scene via Ash Edge Language
import (GLDrivers)
{{env:ThreeProject}}
[[script:three-scene]]
[poly: webgl-geometry]
[net: render-loop]

(ThreeJSNode):-: {
    with var (scene) var (s) {
        irin ("renderer:WebGLRenderer antialias:true bg:#000000")
        irin ("camera:PerspectiveCamera fov:75 near:0.1 far:1000 z:5")
        gl.scene
        gl.render
        thenplace var (scene) with var (s)
    }
    irout ("Result: " placeto (scene))
}|\';\'|

(MeshNode):-: {
    [poly: mesh-geometry]
    with var (mesh) {
        irin ("geometry:BoxGeometry w:1 h:1 d:1 material:MeshStandardMaterial color:#00ffcc")
        gl.mesh
        thenplace var (mesh) with var (mesh)
    }
    irout ("Result: " placeto (mesh))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "react", name: "React / JSX", icon: "r.square", ext: ".jsx",
            category: .web, color: "#61dafb",
            ashWrapper: "(ReactNode)",
            templateCode: """
// React JSX via Ash Edge Language
{{env:ReactProject}}
[[script:react-app]]
[poly: component-tree]
[net: virtual-dom]

(ReactNode):-: {
    with var (component) {
        irin ("name:App state:count=0 props:none hooks:useState")
        thenplace var (component) with var (component)
    }
    irout ("Result: " placeto (component))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "vue", name: "Vue.js", icon: "v.square", ext: ".vue",
            category: .web, color: "#42b883",
            ashWrapper: "(VueNode)",
            templateCode: """
// Vue.js SFC via Ash Edge Language
{{env:VueProject}}
[[script:vue-component]]
[poly: sfc-tree]

(VueNode):-: {
    with var (sfc) {
        irin ("template:div script:setup style:scoped lang:js")
        thenplace var (sfc) with var (sfc)
    }
    irout ("Result: " placeto (sfc))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "php", name: "PHP", icon: "p.square", ext: ".php",
            category: .web, color: "#8892bf",
            ashWrapper: "(PHPNode)",
            templateCode: """
// PHP via Ash Edge Language
{{env:PHPProject}}
[[script:php-script]]
[poly: php-runtime]

(PHPNode):-: {
    with var (s) {
        irin ("version:8.2 strict:true namespace:App")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        // ── Scripting ────────────────────────────────────────
        IDELanguageEnv(
            id: "python", name: "Python 3", icon: "p.circle", ext: ".py",
            category: .scripting, color: "#3776ab",
            ashWrapper: "(PythonNode)",
            templateCode: """
// Python 3 via Ash Edge Language
{{env:PythonProject}}
[[script:py-main]]
[poly: py-runtime]
[net: interpreter-loop]

(PythonNode):-: {
    with var (env) {
        irin ("version:3.11 strict:true encoding:utf-8")
        thenplace var (env) with var (env)
    }
    irout ("Result: " placeto (env))
}|\';\'|

(FunctionNode):-: {
    [poly: py-function]
    with var (fn) var (result) {
        irin ("name:main args:none returns:None body:print")
        thenplace var (result) with var (fn)
    }
    irout ("Result: " placeto (result))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "bash", name: "Bash / Shell", icon: "terminal", ext: ".sh",
            category: .scripting, color: "#4eaa25",
            ashWrapper: "(BashNode)",
            templateCode: """
// Bash Script via Ash Edge Language
{{env:ShellProject}}
[[script:bash-main]]
[poly: shell-runtime]

(BashNode):-: {
    with var (s) {
        irin ("shell:/bin/bash set:-euo pipefail")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "ruby", name: "Ruby", icon: "diamond", ext: ".rb",
            category: .scripting, color: "#cc342d",
            ashWrapper: "(RubyNode)",
            templateCode: """
// Ruby via Ash Edge Language
{{env:RubyProject}}
[[script:rb-main]]
[poly: ruby-runtime]

(RubyNode):-: {
    with var (s) {
        irin ("version:3.2 frozen_string_literal:true encoding:utf-8")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        // ── Data & ML ────────────────────────────────────────
        IDELanguageEnv(
            id: "python_ml", name: "Python · ML/Data", icon: "brain", ext: ".py",
            category: .data, color: "#ff6f00",
            ashWrapper: "(MLNode)",
            templateCode: """
// Python ML / Data Science via Ash Edge Language
{{env:MLProject}}
[[script:ml-pipeline]]
[poly: tensor-graph]
[net: neural-signal]

(MLNode):-: {
    with var (env) {
        irin ("libs:numpy,pandas,torch,sklearn version:3.11")
        thenplace var (env) with var (env)
    }
    irout ("Result: " placeto (env))
}|\';\'|

(DatasetNode):-: {
    [poly: data-matrix]
    with var (data) {
        irin ("source:csv path:data.csv target:label features:all")
        thenplace var (data) with var (data)
    }
    irout ("Result: " placeto (data))
}|\';\'|

(ModelNode):-: {
    [poly: neural-geometry]
    with var (model) var (result) {
        irin ("arch:transformer layers:6 heads:8 hidden:512 activation:relu")
        thenplace var (result) with var (model)
    }
    irout ("Result: " placeto (result))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "sql", name: "SQL", icon: "tablecells", ext: ".sql",
            category: .data, color: "#336791",
            ashWrapper: "(SQLNode)",
            templateCode: """
// SQL via Ash Edge Language
{{env:SQLProject}}
[[script:sql-query]]
[poly: db-schema]

(SQLNode):-: {
    with var (db) {
        irin ("dialect:postgresql version:15 schema:public")
        thenplace var (db) with var (db)
    }
    irout ("Result: " placeto (db))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "r", name: "R", icon: "r.circle", ext: ".r",
            category: .data, color: "#276dc3",
            ashWrapper: "(RStatNode)",
            templateCode: """
// R Statistical Language via Ash Edge Language
{{env:RProject}}
[[script:r-analysis]]
[poly: stat-model]

(RStatNode):-: {
    with var (s) {
        irin ("version:4.3 tidyverse:true ggplot2:true")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        // ── Systems ──────────────────────────────────────────
        IDELanguageEnv(
            id: "swift", name: "Swift", icon: "swift", ext: ".swift",
            category: .systems, color: "#fa7343",
            ashWrapper: "(SwiftNode)",
            templateCode: """
// Swift via Ash Edge Language
{{env:SwiftProject}}
[[script:swift-main]]
[poly: swift-runtime]

(SwiftNode):-: {
    with var (s) {
        irin ("version:5.10 platform:iOS,macOS strict:true")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "rust", name: "Rust", icon: "gearshape.2", ext: ".rs",
            category: .systems, color: "#dea584",
            ashWrapper: "(RustNode)",
            templateCode: """
// Rust via Ash Edge Language
{{env:RustProject}}
[[script:rust-main]]
[poly: ownership-graph]

(RustNode):-: {
    with var (s) {
        irin ("edition:2021 features:async,tokio target:release")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "go", name: "Go", icon: "g.circle", ext: ".go",
            category: .systems, color: "#00acd7",
            ashWrapper: "(GoNode)",
            templateCode: """
// Go via Ash Edge Language
{{env:GoProject}}
[[script:go-main]]
[poly: goroutine-graph]

(GoNode):-: {
    with var (s) {
        irin ("version:1.22 module:main goroutines:true")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "cpp", name: "C++", icon: "c.square", ext: ".cpp",
            category: .systems, color: "#00599c",
            ashWrapper: "(CppNode)",
            templateCode: """
// C++ via Ash Edge Language
{{env:CppProject}}
[[script:cpp-main]]
[poly: memory-graph]

(CppNode):-: {
    with var (s) {
        irin ("standard:c++23 compiler:clang optimize:O2")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        // ── Mobile ───────────────────────────────────────────
        IDELanguageEnv(
            id: "kotlin", name: "Kotlin", icon: "k.circle", ext: ".kt",
            category: .mobile, color: "#7f52ff",
            ashWrapper: "(KotlinNode)",
            templateCode: """
// Kotlin via Ash Edge Language
{{env:KotlinProject}}
[[script:kotlin-main]]
[poly: jvm-runtime]

(KotlinNode):-: {
    with var (s) {
        irin ("version:1.9 target:android jvm:17")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),

        IDELanguageEnv(
            id: "dart", name: "Dart / Flutter", icon: "d.circle", ext: ".dart",
            category: .mobile, color: "#54c5f8",
            ashWrapper: "(DartNode)",
            templateCode: """
// Dart / Flutter via Ash Edge Language
{{env:DartProject}}
[[script:dart-main]]
[poly: widget-tree]

(DartNode):-: {
    with var (s) {
        irin ("sdk:dart version:3.3 flutter:3.19")
        thenplace var (s) with var (s)
    }
    irout ("Result: " placeto (s))
}|\';\'|
"""
        ),
    ]

    // Convenience lookup
    public static func find(id: String) -> IDELanguageEnv {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - Active Environment Store

@MainActor
public final class IDELanguageStore: ObservableObject {
    public static let shared = IDELanguageStore()
    @Published public var activeEnv: IDELanguageEnv = IDELanguageEnv.find(id: "ash")

    public func setEnv(_ env: IDELanguageEnv) {
        activeEnv = env
        UserDefaults.standard.set(env.id, forKey: "ide_active_language_env")
    }

    public func restore() {
        let id = UserDefaults.standard.string(forKey: "ide_active_language_env") ?? "ash"
        activeEnv = IDELanguageEnv.find(id: id)
    }
}

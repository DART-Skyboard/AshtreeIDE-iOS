# Ash Tree IDE — iOS

**LEATR v2 · Lead Edge Ash Tree Reflex**  
© 2026 DART Meadow | Radical Deepscale
Author: Justin Craig Venable

---

## Overview

Ash Tree IDE is a native iOS/macOS/visionOS app for writing, compiling, and running programs in the **Ash language** — a custom programming language built on the **LEATR v2 compiler standard** (Lead Edge Ash Tree Reflex).

The compiler wraps every syntax pattern in algebra that encodes/decodes syntax as executable parameters, using the switch equations `(xa²√xa)±1` to open and close each syntax block like a transistor gate — magnetizing the syntax into a runnable program.

---

## Compiler Standard (LEATR v2)

```
Switch OPEN  (0→1):  (xa²√xa) - 1
Switch CLOSE (1→0):  (xa²√xa) + 1
```

Every Ash node is wrapped in this algebra. The outer frame (hardware shell) isolates the syntax environment. The inner tag system ensures multi-user script identity isolation (no cross-compilation).

### Tag System

| Tag | Purpose |
|-----|---------|
| `{{outer-tag}}` | Environment isolation shell (hardware compiler frame) |
| `[[inner-tag]]` | Script ownership identity — double-tagging |
| `[poly:...]` | Polynomial/physics/math container — isolated from syntax |
| `[net:...]` | Network syntax layer — logarithmic iterative form |

### Node Structure

```ash
{{env:MyProject}}
[[script:my-node-v1]]

(MyNode):-: {
  {{env:MyProject}}
  [[owner:username]]
  [poly: data-matrix]
  with
    var (s)   // Data Set
    var (c)   // Cognition
  {
    irin ("Data: input here")
    Maze
    thenplace var (s) with var (c)
  }
  irout ("Result: " placeto (s))
}|';'|
```

### Order of Operations (19 Natural Orders)

**Natural Tools (1–7):** Maze · Puzzle · Envelope · Hammer · Stick · Knife · Scissors  
**Math/Physics (8–19):** Parentheses · Exponents · Multiplication · Division · Addition · Subtraction · Logarithm · Trigonometry · Temperature · Velocity · Pressure · Mass  
**Senses (AI):** Touch · Taste · Vision · Smell · Hear

### BRPN — Buoyancy Reflex Pendulum Node

After compile, the pendulum routes the result to a shell:
- `GEOLOGICAL` — high-formation (buoyancy ≥ 0.76)
- `MARITIME` — medium (buoyancy ≥ 0.44)
- `AEROSPACE` — sparse (buoyancy < 0.44)

---

## App Features

- Full **Ash language editor** with syntax highlighting
- **LEATR v2 compiler** — lexer, parser, switch equations, BRPN routing
- **LEATR App Runtime terminal** — build and run output
- **GitHub sign-in** (Device Flow, no redirect needed) — auto-creates your private `Ash-Tree-IDE-Projects` repo
- **Sign in with Apple** — full AuthenticationServices integration
- **File browser** — read/write `.ash` files straight to your GitHub repo
- **Docs tab** — full LEATR compiler standard reference built in
- **Split-pane layout** — editor + compiler output side by side on iPad/landscape
- Supports **iOS 17+**, **macCatalyst**, **visionOS**

---

## GitHub Secrets Required (for CI/TestFlight)

| Secret | Value |
|--------|-------|
| `BUILD_CERTIFICATE_BASE64` | Distribution certificate (p12, base64) |
| `P12_PASSWORD` | P12 password |
| `KEYCHAIN_PASSWORD` | Any temp password |
| `BUILD_PROVISION_PROFILE_BASE64` | App Store provisioning profile (base64) |
| `PROVISIONING_PROFILE_NAME` | Profile display name |
| `ASC_KEY_ID` | App Store Connect API key ID (`NQXQ595W59`) |
| `ASC_ISSUER_ID` | ASC issuer ID |
| `ASC_KEY_CONTENT` | ASC `.p8` key content (base64) |

---

## Bundle ID

`DART-Meadow-LLC.AshtreeIDE`

## Team

`L7AHWS9Q6V` — DART Meadow LLC

---

Built with SwiftUI · xcodegen · GitHub Actions · TestFlight  
© 2025 DART Meadow | Radical Deepscale LLC.

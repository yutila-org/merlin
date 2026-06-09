<div align="center">

  <img src="logo.svg" alt="Merlin Logo" width="200" />

  <br />

  <h1>Merlin</h1>
   
  **A cross-platform build orchestrator and TUI for C projects.**

  <a href="https://dlang.org/" target="_blank" style="text-decoration: none;">
    <img src="https://img.shields.io/badge/D-B03931?style=for-the-badge&logo=d&logoColor=white" alt="D" />
  </a>
  <a href="https://github.com/ldc-developers/ldc" target="_blank" style="text-decoration: none;">
    <img src="https://img.shields.io/badge/LDC-8A2BE2?style=for-the-badge&logo=llvm&logoColor=white" alt="LDC" />
  </a>
  <a href="https://www.apache.org/licenses/LICENSE-2.0" target="_blank" style="text-decoration: none;">
    <img src="https://img.shields.io/badge/Apache_2.0-D22128?style=for-the-badge&logo=apache&logoColor=white" alt="Apache-2.0" />
  </a>

</div>

<br />

## <img src="https://cdn.simpleicons.org/blueprint/137CBD" width="24" style="vertical-align: bottom;" /> Scope
Merlin is a specialized, interactive build orchestrator designed explicitly to manage C projects like Camelot. It is written entirely in D to remain highly portable and to leverage native compilation performance without the heavyweight runtime requirements of Python or Node.js. It features an interactive TUI (Text User Interface), automatic cross-platform compilation logic, test suite interception, and dynamic path resolution.

## <img src="https://cdn.simpleicons.org/sentry/FB4226" width="24" style="vertical-align: bottom;" /> Guarantee Model
*   **Compiler-Agnostic**: Dynamically adapts flag syntax for `ldc2`, `dmd`, and `gdc`.
*   **Platform-Independent**: Manages Windows `.exe` suffixes, PE/ELF security flags, and standard compliance.
*   **Security-First**: Enforces `-Werror`, `-fstack-protector-strong`, ASLR, and non-executable stack flags seamlessly for downstream C code.

## <img src="https://cdn.simpleicons.org/polywork/543DE0" width="24" style="vertical-align: bottom;" /> Architecture
Merlin operates via an interactive dashboard or a traditional CLI model.

| Component | Responsibility |
| :--- | :--- |
| **Builder (`builder.d`)** | Compiles project files, tests, and links executables dynamically. |
| **Dashboard (`tui.d`)** | Renders an animated magic-themed dashboard displaying project metrics. |
| **CLI (`app.d`)** | Routes arguments (`all`, `test`, `run`, `clean`, `init`) or launches the interactive prompt. |

## <img src="https://cdn.simpleicons.org/powershell/5391FE" width="24" style="vertical-align: bottom;" /> Usage
Run `make` to bootstrap the binary, then invoke `merlin`.
*   `merlin all` - Builds your target executable.
*   `merlin test` - Orchestrates and compiles your tests.
*   `merlin clean` - Purges the cache and objects.

## <img src="https://cdn.simpleicons.org/github/888888" width="24" style="vertical-align: bottom;" /> Integration
Merlin is typically integrated as a fallback orchestrator via `Makefile` rules, meaning it can be summoned transparently when calling standard `make test` workflows.

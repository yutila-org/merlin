<div align="center">

  <img src="logo.svg" alt="Merlin Logo" width="200" />

  <br />

  <h1>Merlin</h1>
   
  **A cross-platform build orchestrator and TUI for C projects.**

  [![D](https://img.shields.io/badge/D-B03931?style=for-the-badge&logo=d&logoColor=white)](https://dlang.org/)
  [![LDC](https://img.shields.io/badge/LDC-8A2BE2?style=for-the-badge&logo=llvm&logoColor=white)](https://github.com/ldc-developers/ldc)
  [![Make](https://img.shields.io/badge/Make-A42E2B?style=for-the-badge&logo=gnu&logoColor=white)](https://www.gnu.org/software/make/)
  [![Apache-2.0](https://img.shields.io/badge/Apache_2.0-FF8C00?style=for-the-badge&logo=apache&logoColor=white)](https://www.apache.org/licenses/LICENSE-2.0)

</div>

<br />

## <img src="https://cdn.simpleicons.org/blueprint/137CBD" width="24" style="vertical-align: bottom;" /> Scope & Benefits
Merlin is an interactive build orchestrator designed to manage C and C++ projects. It is written in D to remain portable and compile to a native binary without the runtime requirements of Python or Node.js.

###### Why use Merlin over Make or CMake?
Unlike traditional tools, Merlin provides a zero-configuration interactive TUI, automatic cross-platform compilation logic, test suite interception and dynamic path resolution without requiring manually maintained build scripts. While it is tailored primarily as the build engine for the **Camelot utility library**, Merlin is capable of orchestrating standalone C and C++ projects.
## <img src="https://cdn.simpleicons.org/sentry/FB4226" width="24" style="vertical-align: bottom;" /> Guarantee Model
*   **Compiler-Agnostic**: Dynamically adapts flag syntax for `ldc2`, `dmd` and `gdc`.
*   **Platform-Independent**: Manages Windows `.exe` suffixes, PE/ELF security flags and standard compliance.
*   **Compiler-Enforced**: Enforces `-Werror`, `-fstack-protector-strong`, ASLR and non-executable stack flags for downstream C code.

## <img src="https://cdn.simpleicons.org/polywork/543DE0" width="24" style="vertical-align: bottom;" /> Architecture
Merlin operates via an interactive dashboard or a traditional CLI model.

| Component | Responsibility |
| :--- | :--- |
| **Builder (`builder.d`)** | Compiles project files, tests and links executables dynamically. |
| **Dashboard (`tui.d`)** | Renders a TUI dashboard displaying project metrics. |
| **CLI (`app.d`)** | Routes arguments (`all`, `test`, `run`, `clean`, `init`) or launches the interactive prompt. |

## <img src="https://cdn.simpleicons.org/gnometerminal/60FF60" width="24" style="vertical-align: bottom;" /> Installation
The quickest way to get Merlin is via our automated install scripts. By default, they will pull the latest release.

**Linux & macOS:**
```bash
curl -sSL https://github.com/yutila-org/merlin/releases/latest/download/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr https://github.com/yutila-org/merlin/releases/latest/download/install.ps1 -useb | iex
```

### Installing a Specific Version
To install a specific version, pass the tag as an argument (replace `VERSION_NAME` with the exact version name you want):

**Linux & macOS:**
```bash
curl -sSL https://github.com/yutila-org/merlin/releases/latest/download/install.sh | bash -s -- VERSION_NAME
```

**Windows (PowerShell):**
```powershell
$script = Invoke-WebRequest -Uri "https://github.com/yutila-org/merlin/releases/latest/download/install.ps1" -UseBasicParsing
Invoke-Command -ScriptBlock ([Scriptblock]::Create($script.Content)) -ArgumentList "VERSION_NAME"
```

## <img src="https://api.iconify.design/mdi:tools.svg?color=%23a855f7" width="24" style="vertical-align: bottom;" /> Usage
Once installed (or manually bootstrapped via `make`), invoke `merlin` in your project folder.
*   `merlin init <project_name>` - Scaffolds a new C project with editor tasks.
*   `merlin all` - Builds your target executable.
*   `merlin test` - Orchestrates and compiles your tests.
*   `merlin clean` - Purges the cache and objects.

## <img src="https://cdn.simpleicons.org/github/888888" width="24" style="vertical-align: bottom;" /> Integration
Merlin is typically integrated as a fallback orchestrator via `Makefile` rules, meaning it can be summoned transparently when calling standard `make test` workflows.

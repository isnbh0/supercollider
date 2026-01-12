# SuperCollider Development Guide

## Project Overview

SuperCollider is an audio programming environment with three major components:

| Component | Directory | Status |
|-----------|-----------|--------|
| **SCIDE** (IDE) | `editors/sc-ide/` | Documented below |
| **sclang** (Language) | `lang/` | Not yet documented for CLAUDE contribution |
| **scsynth/supernova** (Server) | `server/` | Not yet documented for CLAUDE contribution |

## Build System

- **Build Tool**: CMake 3.12+
- **Code Style**: clang-format (WebKit-based, 4-space indent, 120-char limit)
- **Config Files**: `.clang-format`, `.editorconfig`, `.kateconfig`

## Building SuperCollider

### Prerequisites (All Platforms)

```bash
git clone --recursive https://github.com/SuperCollider/SuperCollider.git
cd SuperCollider
```

The `--recursive` flag clones required submodules. If you forgot it:
```bash
git submodule update --init --recursive
```

### macOS

**Install dependencies:**
```bash
xcode-select --install
brew install git libsndfile readline qt@6
# Optional for supernova:
brew install portaudio
```

**CMake version:** Requires CMake 3.x (3.12 - 3.31). CMake 4.x is incompatible.
- Homebrew's `cmake` formula may install 4.x
- Download CMake 3.x from https://cmake.org/download/ and install the .dmg
- Use `/Applications/CMake.app/Contents/bin/cmake` for builds

**Build:**
```bash
mkdir -p build && cd build
/Applications/CMake.app/Contents/bin/cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
/Applications/CMake.app/Contents/bin/cmake --build . -j$(sysctl -n hw.ncpu)
/Applications/CMake.app/Contents/bin/cmake --build . --target install
```

**Rebuild after changes:**
```bash
cd build
/Applications/CMake.app/Contents/bin/cmake --build . -j$(sysctl -n hw.ncpu) && /Applications/CMake.app/Contents/bin/cmake --build . --target install
```

The `--target install` step is required to update the app bundle in `build/Install/SuperCollider/`. Without it, changes are only compiled but not copied to the runnable app.

**Run:**
```bash
open build/Install/SuperCollider/SuperCollider.app
```

The app bundle is created in `build/Install/SuperCollider/`.

**With Xcode generator:**
```bash
mkdir -p build && cd build
/Applications/CMake.app/Contents/bin/cmake -G Xcode ..
/Applications/CMake.app/Contents/bin/cmake --build . --target install --config RelWithDebInfo
```

### Linux (Debian/Ubuntu)

**Install dependencies:**
```bash
# Core dependencies
sudo apt-get install build-essential cmake libjack-jackd2-dev \
  libsndfile1-dev libfftw3-dev libxt-dev libavahi-client-dev libudev-dev

# sclang dependencies
sudo apt-get install git libasound2-dev libicu-dev libreadline6-dev \
  pkg-config libncurses5-dev

# Qt6 (Ubuntu 22.04+)
sudo apt-get install qt6-base-dev qt6-base-dev-tools qt6-tools-dev \
  qt6-tools-dev-tools libqt6websockets6-dev qt6-webengine-dev \
  libqt6svgwidgets6 libqt6opengl6-dev
```

**Build:**
```bash
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

### Windows

**Required:**
- Visual Studio 2017+
- CMake 3.12+
- Qt 6.2+ (msvc variant matching your VS version)
- libsndfile
- Windows SDK

**Optional:** fftw, ASIO SDK

**Build:**
```cmd
SET PATH=C:\Qt\6.2\msvc2019_64\bin;%PATH%
SET CMAKE_PREFIX_PATH=C:\Qt\6.2.0\msvc2019_64
mkdir build && cd build
cmake -G "Visual Studio 16 2019" -A x64 ..
cmake --build . --config Release
```

### Common CMake Options

| Option | Description |
|--------|-------------|
| `-DSUPERNOVA=ON` | Build parallel audio server |
| `-DNATIVE=ON` | CPU-specific optimizations (not for distribution) |
| `-DCMAKE_BUILD_TYPE=Release` | Release build (Linux/macOS make) |
| `-DCMAKE_INSTALL_PREFIX=/path` | Custom install location |
| `-DSC_QT=OFF` | Build without Qt (no IDE) |
| `-DSC_IDE=OFF` | Build without IDE (keeps Qt in sclang) |

### Build Configurations

- **Debug**: No optimization, debug symbols
- **Release**: Full optimization
- **RelWithDebInfo**: Optimization + debug info (recommended for dev)
- **MinSizeRel**: Optimized for size

### Troubleshooting

**Clean build state:**
```bash
rm CMakeCache.txt           # Reset CMake config
cmake --build . --target clean  # Clean object files
rm -rf build                # Nuclear option
```

**Check dependencies:**
```bash
# macOS
brew info qt@6

# Linux
apt-cache policy qt6-base-dev
```

---

# SCIDE (SuperCollider IDE)

## Architecture Overview

The IDE follows a layered architecture:

```
┌─────────────────────────────────┐
│   UI Layer (MainWindow)         │
├─────────────────────────────────┤
│   Editor Layer                  │
│   (MultiEditor, ScCodeEditor)   │
├─────────────────────────────────┤
│   Tool & Dialog Layer           │
│   (PostWindow, HelpBrowser)     │
├─────────────────────────────────┤
│   Core Management Layer         │
│   (Main, DocumentManager)       │
├─────────────────────────────────┤
│   Process Control Layer         │
│   (ScProcess, ScServer)         │
└─────────────────────────────────┘
```

## Directory Structure

```
editors/sc-ide/
├── core/                    # Core management classes
│   ├── main.cpp             # IDE singleton, coordinates all components
│   ├── doc_manager.cpp      # Document lifecycle (open, save, close)
│   ├── sc_process.cpp       # Controls sclang interpreter, IPC
│   ├── sc_server.cpp        # Manages audio server, OSC communication
│   ├── sc_introspection.cpp # Class library parsing for autocompletion
│   ├── sc_lexer.cpp         # Tokenizer for syntax highlighting
│   ├── session_manager.cpp  # Workspace session management
│   ├── settings/            # Configuration management
│   └── util/                # Shared utilities
│
├── widgets/                 # UI components
│   ├── main_window.cpp      # Main app window, menus, docking
│   ├── multi_editor.cpp     # Tabbed editor interface
│   ├── editor_box.cpp       # Editor container widget
│   ├── post_window.cpp      # Interpreter output display
│   ├── cmd_line.cpp         # Command line panel
│   ├── help_browser.cpp     # Documentation viewer (WebEngine)
│   ├── find_replace_tool.cpp
│   ├── lookup_dialog.cpp    # Class/method lookup
│   │
│   ├── code_editor/         # Editor implementation
│   │   ├── editor.cpp       # Base editor (QPlainTextEdit)
│   │   ├── sc_editor.cpp    # SC-specific features
│   │   ├── highlighter.cpp  # Syntax highlighting
│   │   ├── autocompleter.cpp
│   │   └── line_indicator.cpp
│   │
│   ├── settings/            # Settings dialog pages
│   └── util/                # Widget utilities
│
├── forms/                   # Qt Designer UI files (.ui)
├── primitives/              # IPC utilities
└── translations/            # i18n files (.ts)
```

## Key Components

### Core Layer

| Class | File | Purpose |
|-------|------|---------|
| `Main` | `core/main.cpp` | Singleton hub coordinating all IDE components |
| `DocumentManager` | `core/doc_manager.cpp` | Document lifecycle management |
| `ScProcess` | `core/sc_process.cpp` | sclang process control and IPC |
| `ScServer` | `core/sc_server.cpp` | Audio server management via OSC |
| `ScIntrospection` | `core/sc_introspection.cpp` | Class library introspection |
| `SessionManager` | `core/session_manager.cpp` | Workspace session handling |
| `Settings::Manager` | `core/settings/manager.cpp` | Configuration persistence |

### Widget Layer

| Class | File | Purpose |
|-------|------|---------|
| `MainWindow` | `widgets/main_window.cpp` | Main window, menus, actions |
| `MultiEditor` | `widgets/multi_editor.cpp` | Tabbed document interface |
| `ScCodeEditor` | `widgets/code_editor/sc_editor.cpp` | SC code editor widget |
| `SyntaxHighlighter` | `widgets/code_editor/highlighter.cpp` | Syntax coloring |
| `AutoCompleter` | `widgets/code_editor/autocompleter.cpp` | Code completion |
| `PostWindow` | `widgets/post_window.cpp` | Interpreter output |
| `HelpBrowser` | `widgets/help_browser.cpp` | Documentation viewer |

## Component Relationships

```
MainWindow
├── Main (singleton)
├── MultiEditor
│   └── CodeEditorBox[]
│       └── ScCodeEditor
│          ├── SyntaxHighlighter
│          ├── AutoCompleter
│          └── LineIndicator
├── PostWindow
├── HelpBrowserDocklet
└── DocumentsDocklet

Main
├── ScProcess ─── ScIntrospectionParser
├── ScServer
├── DocumentManager
├── SettingsManager
└── SessionManager
```

## Code Conventions

### Namespace

All IDE code is in `namespace ScIDE`. Settings use `ScIDE::Settings`.

### Class Naming

- UI classes inherit from Qt base classes (QMainWindow, QWidget)
- Manager suffix for coordination classes (DocumentManager, SessionManager)
- Docklet suffix for dockable panels (PostDocklet, DocumentsDocklet)

### Qt Patterns

- Signal/slot mechanism for inter-component communication
- Qt parent-child ownership for memory management
- Q_OBJECT macro for all QObject subclasses
- MOC, UIC, RCC for code generation

### Qt Keyboard Shortcuts (macOS Key Mapping)

**Important:** Qt swaps Ctrl and Meta on macOS. When defining shortcuts:

| Qt Modifier | macOS Key | Windows/Linux Key |
|-------------|-----------|-------------------|
| `Ctrl` | Command (⌘) | Ctrl |
| `Meta` | Control (⌃) | Win |
| `Alt` | Option (⌥) | Alt |

Example: To map **Cmd+Backspace** on macOS, use `Ctrl+Backspace` in Qt code.

See [Qt QKeySequence docs](https://doc.qt.io/qt-6/qkeysequence.html) for details.

### Header Structure

```cpp
#pragma once

// Standard library
// Qt headers
// Local project headers

namespace ScIDE {

class MyClass : public QWidget {
    Q_OBJECT
public:
    // Public methods

Q_SIGNALS:
    // Signals

public Q_SLOTS:
    // Public slots

private Q_SLOTS:
    // Private slots

private:
    // Private members
};

} // namespace ScIDE
```

## Dependencies

- **Qt 5.14+ or Qt 6.0+**: Core, Widgets, Network, Concurrent, WebEngine (optional)
- **yaml-cpp**: Settings serialization
- **oscpack**: OSC communication with audio server

## Platform Notes

| Platform | Notes |
|----------|-------|
| macOS | App bundle, code signing, Objective-C++ in `hacks_mac.mm` |
| Windows | Resource files (.rc), DLL deployment with windeployqt |
| Linux | X11 integration, .desktop launcher |

## Common Modification Patterns

### Adding a New Setting

1. Add to `core/settings/manager.hpp` (declare key)
2. Add default in `core/settings/manager.cpp`
3. Add UI in appropriate `widgets/settings/*_page.cpp`
4. Connect to functionality in relevant component

### Adding a New Tool Panel

1. Create widget in `widgets/`
2. Create docklet wrapper using `Docklet` class
3. Register in `MainWindow::createDocklets()`
4. Add menu action in `MainWindow::createActions()`

### Adding Editor Features

1. For generic features: modify `widgets/code_editor/editor.cpp`
2. For SC-specific features: modify `widgets/code_editor/sc_editor.cpp`
3. For syntax: modify `widgets/code_editor/highlighter.cpp`
4. For completion: modify `widgets/code_editor/autocompleter.cpp`

### Modifying Interpreter Communication

1. IPC protocol in `core/sc_process.cpp`
2. Commands sent via `ScProcess::evaluateCode()`
3. Responses handled via signals

## File Size Reference

Largest files (complexity indicators):
- `widgets/code_editor/editor.cpp` (~41KB)
- `widgets/code_editor/sc_editor.cpp` (~41KB)
- `widgets/code_editor/autocompleter.cpp` (~39KB)
- `widgets/main_window.cpp` (~40KB)
- `core/doc_manager.cpp` (~40KB)

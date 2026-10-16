# ue-linux-win64

Cross-compile and package **Unreal Engine 5.8** C++ and Blueprint projects from **Linux (`x86_64-linux`) to Windows (`Win64`)** using `clang-cl`, `lld-link`, `llvm-rc`, and `xwin` (MSVC + Windows 11 SDK sysroot) with **Vulkan SM5/SM6** shaders and **Intel ISPC** SIMD acceleration (`SSE4`, `AVX`, `AVX2`, `AVX-512`).

No Windows VM or Visual Studio installation required — works both from the CLI and directly inside the **Linux Unreal Editor UI** (`Edit -> Project Settings -> Platforms -> Windows` and `Platforms -> Windows -> Package Project`).

---

## Why is this needed?

Out of the box, Unreal Engine on Linux disables the `Win64` target platform because:
1. `Engine/Config/Windows/DataDrivenPlatformInfo.ini` sets `Linux:bIsEnabled=false`, hiding Windows from the **Platforms** menu in the Linux Editor.
2. `UnrealEd` only loads `WindowsPlatformEditor` on Windows hosts, hiding **Project Settings -> Platforms -> Windows** on Linux.
3. `UnrealBuildTool` (`MicrosoftPlatformSDK.cs`, `UEBuildWindows.cs`, `VCEnvironment.cs`, `VCToolChain.cs`, `ISPCToolChain.cs`) assumes a Windows host (`OperatingSystem.IsWindows()`, Win32 Registry lookups, PE header checks on compiler binaries, backslashes in `.rc2` icon paths).
4. `Engine/Source/ThirdParty/Intel/ISPC/bin/Linux/ispc` is built by Epic without `--target-os=windows` support; we use a fast hybrid pipeline (`ispc.linux` for native header/dependency generation + `ispc.exe` via headless `wine64` outside UBA detours for Windows COFF `.obj` generation).
5. `WindowsTargetPlatformSettings` defaults to cooking `PCD3D_SM5`/`PCD3D_SM6` via `ShaderFormatD3D` (which relies on Windows-only DirectX proprietary blobs), whereas `VulkanShaderFormat` (`SF_VULKAN_SM5` / `SF_VULKAN_SM6`) compiles natively on Linux.
6. `BootstrapPackagedGame` (`<Project>.exe` root launcher) relies on Win32 `UpdateResourceW` during staging on Windows hosts; on Linux hosts we add a fallback that automatically discovers `<Project>\Binaries\Win64\<Project>*.exe`.

This repository provides:
- [`patches/ue5.8-linux-win64.patch`](patches/ue5.8-linux-win64.patch): A clean unified patch (`patch -p1`) for Unreal Engine 5.8.x source builds.
- [`bin/ue-linux-win64`](bin/ue-linux-win64): A standalone CLI tool to download/configure the `xwin` sysroot, configure the hybrid ISPC wrapper, patch & compile the engine modules, configure projects, and package `Win64` builds from Linux.
- [`flake.nix`](flake.nix): Reproducible Nix package & devShell with `xwin`, `clang-20`, `lld-20` (with `libxml2` manifest embedding support), `llvm-rc`, and `wine64`.

---

## Quick Start

### 1. Prepare your Unreal Engine 5.8 source build (one-time per engine version)

```bash
ue-linux-win64 setup-engine /path/to/UnrealEngine
```

This command will:
1. Download and splat the MSVC 14.44 + Windows 11 SDK (`10.0.22621`) sysroot via `xwin` into `~/.local/share/ue-linux-win64/sysroot` with case-folding symlinks for Linux filesystems.
2. Install the hybrid ISPC wrapper (`Engine/Source/ThirdParty/Intel/ISPC/bin/Linux/ispc`) so `.ispc` SIMD modules compile for `Win64`.
3. Apply `patches/ue5.8-linux-win64.patch` to the engine.
4. Rebuild `UnrealBuildTool`, cross-compile `BootstrapPackagedGame` (`Win64 Shipping`), and compile `WindowsTargetPlatform*` + `WindowsPlatformEditor` modules for `UnrealEditor` (`Linux Development`).

### 2. Configure an Unreal Project for Linux -> Win64

```bash
ue-linux-win64 setup-project /path/to/MyProject
```

Adds `[/Script/WindowsTargetPlatform.WindowsTargetSettings]` to `Config/DefaultEngine.ini` with:
- `Compiler=Clang`
- `DefaultGraphicsRHI=DefaultGraphicsRHI_Vulkan`
- `TargetedRHIs=SF_VULKAN_SM6` & `SF_VULKAN_SM5`

### 3. Package a Windows (`Win64`) build from Linux

```bash
ue-linux-win64 package /path/to/MyProject --config Shipping
```

The packaged Windows build is written to `<MyProject>/Saved/StagedBuilds/Win64_Package/Windows`.

### 4. Check Status

```bash
ue-linux-win64 status /path/to/UnrealEngine
```

---

## Using with Nix Flakes

Run directly without installing:

```bash
nix run github:Ezyrath/ue-linux-win64 -- status
```

Or add to your `flake.nix` inputs:

```nix
inputs.ue-linux-win64.url = "github:Ezyrath/ue-linux-win64";
```

# Friday Night Funkin' - Android build

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Download APK](https://img.shields.io/github/v/release/watsbunny/funkin-android-build?label=download%20APK)](https://github.com/watsbunny/funkin-android-build/releases)

Friday Night Funkin' **0.2.7.1.5** (HaxeFlixel / Lime / OpenFL) for Android,
packaged together with a **one-command Windows toolchain**.

**English** &nbsp;&middot;&nbsp; [Русский](README.ru.md)

---

## Why this repository exists

Compiling an FNF build on Windows is a well-known pain: exact Haxe/Neko/haxelib
versions, Android SDK + NDK r21e, a JDK, flixel 4.8.1 that no longer compiles on
modern Haxe, Gradle dying on a 170 MB APK and refusing non-ASCII project paths.

This repository exists **to spare you that pain** - both for simply building the
game and for modding FNF: clone it, run `install-and-build.cmd` once, and you get
an APK plus a complete, reusable toolchain that stays on your machine for the
next build or mod.

---

## Download a ready APK

Grab `Funkin-<version>-android.apk` from
[**Releases**](https://github.com/watsbunny/funkin-android-build/releases), allow
installation from unknown sources on the phone and install it.
Android 5.0+ (minSdk 21), `arm64-v8a` and `armeabi-v7a`.

---

## Quick start (build it yourself)

Needs Windows 10/11 x64, internet and ~8 GB of free disk. **No administrator
rights required.**

```bat
git clone https://github.com/watsbunny/funkin-android-build.git
cd funkin-android-build
install-and-build.cmd
```

The script:

1. checks curl / PowerShell / internet;
2. finds JDK 17+ (or downloads Eclipse Temurin JDK 21);
3. installs Haxe 4.3.7 + haxelib + Neko 2.4.1;
4. installs the required haxelib libraries;
5. installs the Android SDK (cmdline-tools, platform-tools, build-tools 34/35,
   `platforms;android-35`) and NDK r21e;
6. configures Lime (`~/.lime/config.xml`) and raises the Gradle heap;
7. patches flixel 4.8.1;
8. works around non-ASCII characters in the project path;
9. builds the APK.

First run takes **30-40 minutes**, later builds **1-2 minutes**.

### Output

```
export\debug\android\bin\app\build\outputs\apk\debug\*.apk      (debug)
export\release\android\bin\app\build\outputs\apk\release\*.apk  (release)
```

Install on the phone (enable "USB debugging" first):

```bat
adb install -r "export\debug\android\bin\app\build\outputs\apk\debug\Funkin-debug.apk"
```

### Installer flags

| Flag | Meaning |
| --- | --- |
| *(none)* | debug APK, both architectures (armeabi-v7a + arm64-v8a) |
| `--release` | release build (needs your own signing key, see below) |
| `--arch=arm64` | arm64-v8a only - about twice as fast, smaller APK |
| `--arch=armv7` | armeabi-v7a only (older devices) |
| `--skip-build` | install / repair the toolchain only |
| `--force` | re-download and reinstall everything |
| `--nopause` | never wait for a key press (CI friendly) |

```bat
install-and-build.cmd --arch=arm64
install-and-build.cmd --release
install-and-build.cmd --skip-build
```

---

## What gets installed

Everything goes into `%LOCALAPPDATA%\FunkinAndroidToolchain`; nothing is written
outside your user profile and no administrator rights are needed.

| Component | Version |
| --- | --- |
| Haxe + haxelib | 4.3.7 |
| Neko (needed by haxelib and Lime run scripts) | 2.4.1 |
| JDK (installed only when no JDK 17+ is present) | Eclipse Temurin 21 |
| Android cmdline-tools / platform-tools | latest |
| Android build-tools | 34.0.0 and 35.0.0 |
| Android platform | android-35 |
| Android NDK | r21e (21.4.7075529) |
| hxcpp | 4.3.2 |
| lime | 8.3.2 |
| openfl | 9.5.2 |
| flixel | 4.8.1 |
| flixel-ui | 2.3.3 |
| flixel-addons | 2.9.0 |
| hscript | 2.5.0 |
| polymod | 1.4.3 |

APK parameters: `com.ninjamuffin99.funkin`, versionName `0.2.7.1`, minSdk 21
(Android 5.0), targetSdk 35, ABI `arm64-v8a` + `armeabi-v7a`, about 160-170 MB.

---

## flixel 4.8.1 patches (applied automatically)

Without them the project does not compile with modern Haxe. Every modified file
has a backup next to it (`.orig`, `.compatbak`).

**1. `flixel/ui/FlxVirtualPad.hx`** - taken from the `OPENME!` folder of this
repository: on-screen buttons are enlarged 3x for modern phones, plus the
`RIGHT_FULL` / `ALTER_FULL` layouts.

**2. `flixel/group/FlxGroup.hx` and `flixel/system/frontEnds/PluginFrontEnd.hx`** -
four `x is ObjectClass` / `x is ClassType` lines are rewritten to
`Std.isOfType(x, ...)`. Haxe 4.2+ forbids `is` with a variable, which is why
flixel 4.8.1 fails with "Type not found : ObjectClass".

**3. `flixel/math/FlxPoint.hx` and `flixel/math/FlxRect.hx`** - the pool fields
get an explicit type:

```haxe
static var _pool:FlxPool<FlxPoint> = new FlxPool<FlxPoint>(FlxPoint);
```

Without the annotation Haxe 4.3 mis-infers the type of `_pool` in **release**
builds and fails with "has no field putUnsafe". Debug builds are not affected.

Revert a patch:

```bat
copy /y "%LOCALAPPDATA%\FunkinAndroidToolchain\haxelib\flixel\4,8,1\flixel\math\FlxPoint.hx.compatbak" ^
        "%LOCALAPPDATA%\FunkinAndroidToolchain\haxelib\flixel\4,8,1\flixel\math\FlxPoint.hx"
```

### Signing a release build

```bat
"%JAVA_HOME%\bin\keytool" -genkeypair -v -keystore funkin.keystore ^
   -alias funkin -keyalg RSA -keysize 2048 -validity 10000
```

Create `export\release\android\bin\app\signing.properties` (note the `app`
sub-folder and the exact key names - Lime reads them with these names):

```properties
KEY_STORE=C:/path/funkin.keystore
KEY_STORE_PASSWORD=yourpassword
KEY_STORE_ALIAS=funkin
KEY_STORE_ALIAS_PASSWORD=yourpassword
```

Then run `install-and-build.cmd --release`. The signed file ends up in
`export\release\android\bin\app\build\outputs\apk\release\Funkin-release.apk`.

Lime 8.3.2 chooses the Gradle task from the presence of a keystore, not from the
build type, so a release build must also set
`set ANDROID_GRADLE_TASK=assembleRelease` before calling Lime (both helper
scripts do this for you).

---

## Manual build / reusing the toolchain

After installation a helper script appears:
`%LOCALAPPDATA%\FunkinAndroidToolchain\env.cmd`

```bat
call "%LOCALAPPDATA%\FunkinAndroidToolchain\env.cmd"
cd /d <project path>
haxelib run lime build android -debug
```

Useful Lime commands:

| Command | Purpose |
| --- | --- |
| `haxelib run lime build android -debug` | debug APK |
| `haxelib run lime build android` | release APK (`ANDROID_GRADLE_TASK=assembleRelease`) |
| `haxelib run lime build android -arm64` | arm64 only |
| `haxelib run lime build android -clean` | full rebuild |
| `haxelib run lime test android` | build, install and launch on the phone |

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Your project path contains non-ASCII characters` | Gradle rejects non-ASCII paths. The installer builds through a junction (`...\FunkinAndroidToolchain\build`); if you build manually, move the project to an ASCII path |
| `packageDebug FAILED` + `java_pid*.hprof` | the Gradle daemon ran out of memory. Needs `org.gradle.jvmargs=-Xmx4096m` in `%USERPROFILE%\.gradle\gradle.properties` (the installer writes it) and `gradlew --stop` |
| `Type not found : ObjectClass` | the flixel patch is missing - restore the files from `.compatbak` |
| `has no field putUnsafe` on release builds | the `_pool` type annotation patch is missing (see above) |
| release build still produces a debug APK | `ANDROID_GRADLE_TASK=assembleRelease` was not set (see above) |
| `SigningConfig "release" is missing required property "storeFile"` | `signing.properties` is not in `...\bin\app\` or uses `KEY_ALIAS` instead of `KEY_STORE_ALIAS` |
| `haxelib.exe` dies silently (`0xC0000135`) | `neko.dll` / `gcmt-dll.dll` / `*.ndll` are missing next to `haxelib.exe` - the installer copies them |
| `You must define ANDROID_SDK and ANDROID_NDK_ROOT` | run `haxelib run lime setup android` and point it at `%LOCALAPPDATA%\FunkinAndroidToolchain` |
| NDK / `ndk-build` errors | check `ANDROID_NDK_ROOT` - NDK r21e is required |
| Build is extremely slow | exclude the project folder, `%LOCALAPPDATA%\FunkinAndroidToolchain` and `%USERPROFILE%\haxelib` from antivirus scanning |

Installer logs: `%LOCALAPPDATA%\FunkinAndroidToolchain\logs\`.

---

## Repository structure

```
install-and-build.cmd   toolchain installer + APK builder (Windows)
Project.xml             Lime/OpenFL project configuration
source/                 Haxe sources of the game
assets/                 game assets (music, graphics, charts)
art/                    graphics sources (Flash .fla etc.)
OPENME!/                patched flixel 4.8.1 virtual pad assets
example_mods/           example mods (polymod)
docs/, .github/         misc
```

The `export/` folder (build results) is not tracked - it is in `.gitignore`.

---

## License and credits

Code is distributed under the **Apache License 2.0** - see [LICENSE](LICENSE).
Friday Night Funkin' assets and characters belong to their authors; this
repository grants no rights to them.

* **Friday Night Funkin'** - [ninjamuffin99](https://twitter.com/ninja_muffin99)
  (code), PhantomArcade3K and Evilsk8r (art), Kawaisprite (music).
  Original: [ninjamuffin99/Funkin](https://github.com/ninjamuffin99/Funkin)
* **Android port 0.2.7.1.5** - [luckydog7/Funkin-android](https://github.com/luckydog7/Funkin-android)
* **Automatic build script and toolchain setup** - this repository

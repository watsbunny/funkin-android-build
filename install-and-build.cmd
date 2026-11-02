@echo off
rem =====================================================================
rem  Funkin Android - automatic toolchain installer + builder (Windows 10/11 x64)
rem
rem  Installs everything into %LOCALAPPDATA%\FunkinAndroidToolchain
rem  (no administrator rights, nothing outside your user profile):
rem
rem    - Haxe 4.3.7 + haxelib + Neko 2.4.1
rem    - JDK 21 (only when no JDK 17+ is found on the machine)
rem    - Android SDK: cmdline-tools, platform-tools, build-tools 34/35,
rem      platforms;android-35, NDK r21e (21.4.7075529)
rem    - haxelib: hxcpp 4.3.2, lime 8.3.2, openfl 9.5.2, flixel 4.8.1,
rem      flixel-ui 2.3.3, flixel-addons 2.9.0, hscript 2.5.0, polymod 1.4.3
rem    - patches flixel 4.8.1 so it compiles on modern Haxe
rem    - raises the Gradle heap (the 512 MB default cannot package a ~170 MB APK)
rem    - builds the APK
rem
rem  Usage:
rem    install-and-build.cmd                 debug APK (armeabi-v7a + arm64-v8a)
rem    install-and-build.cmd --release       release APK (needs a signing key)
rem    install-and-build.cmd --arch=arm64    arm64 only - about twice as fast
rem    install-and-build.cmd --skip-build    install / repair the toolchain only
rem    install-and-build.cmd --force         re-download everything
rem    install-and-build.cmd --nopause       never wait for a key press
rem
rem  Requirements: Windows 10/11 x64, internet, ~8 GB free disk, curl (built-in).
rem  Portable/test mode: set FUNKIN_TOOLROOT=<path> - custom install root and no
rem  user environment changes.
rem =====================================================================

chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title Funkin Android - setup

rem ---------------------------- arguments ------------------------------
set "DO_RELEASE=0"
set "DO_BUILD=1"
set "DO_FORCE=0"
set "NOPAUSE=0"
set "LIME_EXTRA="
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--release"    set "DO_RELEASE=1"
if /i "%~1"=="--skip-build" set "DO_BUILD=0"
if /i "%~1"=="--force"      set "DO_FORCE=1"
if /i "%~1"=="--nopause"    set "NOPAUSE=1"
if /i "%~1"=="--arch=arm64" set "LIME_EXTRA=!LIME_EXTRA! -Dandroid-arch=arm64"
if /i "%~1"=="--arch=armv7" set "LIME_EXTRA=!LIME_EXTRA! -Dandroid-arch=armv7"
if /i "%~1"=="--help"       goto usage
if /i "%~1"=="-h"           goto usage
shift
goto parse_args
:args_done

rem ---------------------------- locations ------------------------------
for %%I in ("%~dp0.") do set "PROJ=%%~fI"
if defined FUNKIN_TOOLROOT (
  set "ROOT=%FUNKIN_TOOLROOT%"
  set "PERSIST=0"
) else (
  set "ROOT=%LOCALAPPDATA%\FunkinAndroidToolchain"
  set "PERSIST=1"
)
set "DL=%ROOT%\downloads"
set "HAXEDIR=%ROOT%\haxe"
set "NEKODIR=%ROOT%\neko"
set "LIBROOT=%ROOT%\haxelib"
set "SDK=%ROOT%\android-sdk"
set "NDKVER=21.4.7075529"
set "NDK=%SDK%\ndk\%NDKVER%"
set "JDKDIR=%ROOT%\jdk"
set "LOGDIR=%ROOT%\logs"
set "HAXEVER=4.3.7"
set "CURL=curl.exe"
set "F=%~f0"

if not exist "%ROOT%"   mkdir "%ROOT%"   2>nul
if not exist "%DL%"     mkdir "%DL%"     2>nul
if not exist "%LOGDIR%" mkdir "%LOGDIR%" 2>nul
echo Funkin Android - automatic toolchain setup> "%LOGDIR%\install.log"

rem ---------------------------- force mode -----------------------------
if "%DO_FORCE%"=="1" (
  echo [0/9] --force: removing cached downloads and installed tools...
  if exist "%DL%"      rmdir /s /q "%DL%"     2>nul
  if exist "%HAXEDIR%" rmdir /s /q "%HAXEDIR%" 2>nul
  if exist "%NEKODIR%" rmdir /s /q "%NEKODIR%" 2>nul
  if exist "%JDKDIR%"  rmdir /s /q "%JDKDIR%"  2>nul
  if exist "%SDK%\cmdline-tools" rmdir /s /q "%SDK%\cmdline-tools" 2>nul
  if exist "%NDK%"     rmdir /s /q "%NDK%"     2>nul
  for /d %%V in ("%LIBROOT%\*") do rmdir /s /q "%%V"
  mkdir "%DL%" 2>nul
  echo         done.
  echo.
)

echo =====================================================================
echo  Funkin Android - automatic toolchain setup
echo =====================================================================
echo  Project  : %PROJ%
echo  Toolchain: %ROOT%
echo  Logs     : %LOGDIR%
echo =====================================================================
echo.

rem ------------------------ 1. sanity checks ---------------------------
echo [1/9] Checking prerequisites...
where %CURL% >nul 2>&1
if errorlevel 1 (
  echo   [ERROR] curl.exe not found. Windows 10 1803+ ships it.
  goto fail
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ($PSVersionTable.PSVersion.Major -lt 5) { exit 1 }"
if errorlevel 1 (
  echo   [ERROR] PowerShell 5.1 or newer is required.
  goto fail
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { (New-Object Net.Sockets.TcpClient).Connect('dl.google.com',443); exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo   [ERROR] No internet connection - downloads need network access.
  goto fail
)
echo   OK - curl, PowerShell, internet.
echo.

rem ---------------------------- 2. Java --------------------------------
echo [2/9] Java JDK 17+ ...
set "JAVA_HOME_USED="
if exist "%JDKDIR%\bin\javac.exe" set "JAVA_HOME_USED=%JDKDIR%"
if not defined JAVA_HOME_USED if defined JAVA_HOME call :probe_jdk "%JAVA_HOME%"
if not defined JAVA_HOME_USED (
  for /f "delims=" %%J in ('where javac.exe 2^>nul') do (
    if not defined JAVA_HOME_USED for %%D in ("%%~dpJ..") do call :probe_jdk "%%~fD"
  )
)
if not defined JAVA_HOME_USED (
  echo   No JDK 17+ found - downloading Eclipse Temurin JDK 21 ^(~196 MB^)...
  call :download "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse" "%DL%\jdk21.zip"
  if errorlevel 1 goto fail
  set "ZIP=%DL%\jdk21.zip"
  set "DEST=%ROOT%\_jdk_tmp"
  if exist "!DEST!" rmdir /s /q "!DEST!"
  call :unzip
  if errorlevel 1 goto fail
  if exist "%JDKDIR%" rmdir /s /q "%JDKDIR%"
  for /d %%D in ("!DEST!\jdk-*") do move "%%D" "%JDKDIR%" >nul
  rmdir /s /q "!DEST!" 2>nul
  if not exist "%JDKDIR%\bin\javac.exe" (
    echo   [ERROR] JDK extraction failed.
    goto fail
  )
  set "JAVA_HOME_USED=%JDKDIR%"
)
set "JAVA_HOME=!JAVA_HOME_USED!"
set "PATH=!JAVA_HOME_USED!\bin;%PATH%"
echo   OK - !JAVA_HOME_USED!
echo.

rem --------------------- 3. Haxe + Neko (runtime) ----------------------
echo [3/9] Haxe %HAXEVER% + haxelib + Neko 2.4.1 ...
if not exist "%HAXEDIR%\haxe.exe" (
  echo   Downloading Haxe ^(~12 MB^)...
  call :download "https://github.com/HaxeFoundation/haxe/releases/download/%HAXEVER%/haxe-%HAXEVER%-win64.zip" "%DL%\haxe.zip"
  if errorlevel 1 goto fail
  set "ZIP=%DL%\haxe.zip"
  set "DEST=%ROOT%\_haxe_tmp"
  if exist "!DEST!" rmdir /s /q "!DEST!"
  call :unzip
  if errorlevel 1 goto fail
  for /d %%D in ("!DEST!\haxe_*") do move "%%D" "%HAXEDIR%" >nul
  rmdir /s /q "!DEST!" 2>nul
)
if not exist "%NEKODIR%\neko.exe" (
  echo   Downloading Neko ^(~4 MB^)...
  call :download "https://github.com/HaxeFoundation/neko/releases/download/v2-4-1/neko-2.4.1-win64.zip" "%DL%\neko.zip"
  if errorlevel 1 goto fail
  set "ZIP=%DL%\neko.zip"
  set "DEST=%ROOT%\_neko_tmp"
  if exist "!DEST!" rmdir /s /q "!DEST!"
  call :unzip
  if errorlevel 1 goto fail
  for /d %%D in ("!DEST!\neko-*") do move "%%D" "%NEKODIR%" >nul
  rmdir /s /q "!DEST!" 2>nul
)
if not exist "%HAXEDIR%\haxe.exe" (
  echo   [ERROR] Haxe extraction failed.
  goto fail
)
if not exist "%NEKODIR%\neko.exe" (
  echo   [ERROR] Neko extraction failed.
  goto fail
)
rem haxelib.exe is a Neko program: neko.dll + CRT + ndll files must sit next to it.
for %%F in (neko.dll gcmt-dll.dll msvcp140.dll msvcp140_1.dll msvcp140_2.dll msvcp140_atomic_wait.dll msvcp140_codecvt_ids.dll vcruntime140.dll vcruntime140_1.dll concrt140.dll) do (
  if exist "%NEKODIR%\%%F" if not exist "%HAXEDIR%\%%F" copy /y "%NEKODIR%\%%F" "%HAXEDIR%\" >nul
)
for %%F in ("%NEKODIR%\*.ndll") do if not exist "%HAXEDIR%\%%~nxF" copy /y "%%F" "%HAXEDIR%\" >nul
set "HAXE_STD_PATH=%HAXEDIR%\std"
set "NEKOPATH=%NEKODIR%"
set "HAXELIB_PATH=%LIBROOT%"
set "PATH=%HAXEDIR%;%NEKODIR%;%PATH%"
call "%HAXEDIR%\haxe.exe" --version >nul 2>&1
if errorlevel 1 (
  echo   [ERROR] haxe.exe does not run.
  goto fail
)
echo   OK - haxe %HAXEVER%, neko 2.4.1.
echo.

rem ------------------------- 4. haxelib libs ---------------------------
echo [4/9] haxelib libraries...
if not exist "%LIBROOT%" mkdir "%LIBROOT%" 2>nul
call :haxelib_install hxcpp         4.3.2  || goto fail
call :haxelib_install lime          8.3.2  || goto fail
call :haxelib_install openfl        9.5.2  || goto fail
call :haxelib_install flixel        4.8.1  || goto fail
call :haxelib_install flixel-ui     2.3.3  || goto fail
call :haxelib_install flixel-addons 2.9.0  || goto fail
call :haxelib_install hscript       2.5.0  || goto fail
call :haxelib_install polymod       1.4.3  || goto fail
rem make sure these exact versions are the active ones
call "%HAXEDIR%\haxelib.exe" set lime 8.3.2        >nul 2>&1
call "%HAXEDIR%\haxelib.exe" set openfl 9.5.2      >nul 2>&1
call "%HAXEDIR%\haxelib.exe" set flixel 4.8.1      >nul 2>&1
call "%HAXEDIR%\haxelib.exe" set flixel-ui 2.3.3   >nul 2>&1
call "%HAXEDIR%\haxelib.exe" set flixel-addons 2.9.0 >nul 2>&1
call "%HAXEDIR%\haxelib.exe" set hxcpp 4.3.2       >nul 2>&1
echo   OK - libraries installed.
echo.

rem ------------------------- 5. Android SDK ---------------------------
echo [5/9] Android SDK + NDK r21e ...
if not exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" (
  echo   Downloading Android command line tools ^(~136 MB^)...
  call :download "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip" "%DL%\cmdline-tools.zip"
  if errorlevel 1 goto fail
  set "ZIP=%DL%\cmdline-tools.zip"
  set "DEST=%ROOT%\_sdk_tmp"
  if exist "!DEST!" rmdir /s /q "!DEST!"
  call :unzip
  if errorlevel 1 goto fail
  if not exist "%SDK%\cmdline-tools" mkdir "%SDK%\cmdline-tools" 2>nul
  if exist "%SDK%\cmdline-tools\latest" rmdir /s /q "%SDK%\cmdline-tools\latest"
  move "!DEST!\cmdline-tools" "%SDK%\cmdline-tools\latest" >nul
  rmdir /s /q "!DEST!" 2>nul
)
if not exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" (
  echo   [ERROR] sdkmanager not found after extraction.
  goto fail
)
set "SDKMGR=%SDK%\cmdline-tools\latest\bin\sdkmanager.bat"
echo   Accepting SDK licenses...
( for /l %%i in (1,1,80) do @echo y ) | call "%SDKMGR%" --sdk_root="%SDK%" --licenses >nul 2>&1
echo   Installing platform-tools, build-tools 34/35, platform android-35 ...
call "%SDKMGR%" --sdk_root="%SDK%" "platform-tools" "platforms;android-35" "build-tools;34.0.0" "build-tools;35.0.0" >"%LOGDIR%\sdkmanager.log" 2>&1
if errorlevel 1 (
  echo   [ERROR] sdkmanager failed - see "%LOGDIR%\sdkmanager.log"
  goto fail
)
if not exist "%NDK%\source.properties" (
  echo   Downloading Android NDK r21e ^(~1 GB, this takes a while^)...
  call :download "https://dl.google.com/android/repository/android-ndk-r21e-windows-x86_64.zip" "%DL%\ndk.zip"
  if errorlevel 1 goto fail
  set "ZIP=%DL%\ndk.zip"
  set "DEST=%ROOT%\_ndk_tmp"
  if exist "!DEST!" rmdir /s /q "!DEST!"
  call :unzip
  if errorlevel 1 goto fail
  if not exist "%SDK%\ndk" mkdir "%SDK%\ndk" 2>nul
  for /d %%D in ("!DEST!\android-ndk-*") do move "%%D" "%NDK%" >nul
  rmdir /s /q "!DEST!" 2>nul
)
if not exist "%NDK%\source.properties" (
  echo   [ERROR] NDK not found at "%NDK%".
  goto fail
)
set "ANDROID_SDK=%SDK%"
set "ANDROID_HOME=%SDK%"
set "ANDROID_SDK_ROOT=%SDK%"
set "ANDROID_NDK_ROOT=%NDK%"
set "NDK_ROOT=%NDK%"
set "PATH=%SDK%\platform-tools;%SDK%\cmdline-tools\latest\bin;%PATH%"
echo   OK - %SDK%
echo.

rem ------------------------ 6. lime + gradle config -------------------
echo [6/9] Configuring Lime and Gradle ...
set "LIME_CFG=%USERPROFILE%\.lime\config.xml"
set "LIME_XML=<?xml version='1.0' encoding='utf-8'?><config><section id='defines'><define name='ANDROID_SDK' value='%SDK%'/><define name='ANDROID_NDK_ROOT' value='%NDK%'/><define name='JAVA_HOME' value='%JAVA_HOME_USED%'/></section><define name='ANDROID_SETUP' value='true'/></config>"
set "LIME_NEEDS=1"
if exist "%LIME_CFG%" findstr /c:"ANDROID_SDK" "%LIME_CFG%" >nul 2>&1
if not errorlevel 1 set "LIME_NEEDS=0"
if "%LIME_NEEDS%"=="1" (
  if not exist "%USERPROFILE%\.lime" mkdir "%USERPROFILE%\.lime" 2>nul
  if exist "%LIME_CFG%" copy /y "%LIME_CFG%" "%LIME_CFG%.bak" >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[IO.File]::WriteAllText($env:LIME_CFG, $env:LIME_XML)"
  echo   wrote %LIME_CFG%
) else (
  echo   %LIME_CFG% already configured - kept.
)
rem Gradle daemon heap: the 512 MB default cannot package a ~170 MB APK.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Join-Path $env:USERPROFILE '.gradle'; $p=Join-Path $d 'gradle.properties'; $l='org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m -Dfile.encoding=UTF-8'; if(!(Test-Path $d)){New-Item -ItemType Directory -Force -Path $d | Out-Null}; if(!(Test-Path $p)){Set-Content -Path $p -Value $l -Encoding ASCII} elseif(-not (Select-String -Path $p -Pattern 'org.gradle.jvmargs' -Quiet)){Add-Content -Path $p -Value $l -Encoding ASCII}"
echo   Gradle heap: 4 GB.
echo.

rem --------------------------- 7. patches -----------------------------
echo [7/9] Patching flixel 4.8.1 for modern Haxe ...
set "FLX=%LIBROOT%\flixel\4,8,1"
if not exist "%FLX%\flixel\ui\FlxVirtualPad.hx" (
  echo   [ERROR] flixel 4.8.1 not found at "%FLX%".
  goto fail
)
if exist "%PROJ%\OPENME!\lib\flixel\4,8,1\flixel\ui\FlxVirtualPad.hx" (
  if not exist "%FLX%\flixel\ui\FlxVirtualPad.hx.orig" copy /y "%FLX%\flixel\ui\FlxVirtualPad.hx" "%FLX%\flixel\ui\FlxVirtualPad.hx.orig" >nul
  copy /y "%PROJ%\OPENME!\lib\flixel\4,8,1\flixel\ui\FlxVirtualPad.hx" "%FLX%\flixel\ui\FlxVirtualPad.hx" >nul
  if not exist "%FLX%\assets\images\ui" mkdir "%FLX%\assets\images\ui" 2>nul
  copy /y "%PROJ%\OPENME!\lib\flixel\4,8,1\assets\images\ui\virtual-input.png" "%FLX%\assets\images\ui\" >nul
  copy /y "%PROJ%\OPENME!\lib\flixel\4,8,1\assets\images\ui\virtual-input.txt" "%FLX%\assets\images\ui\" >nul
  echo   virtual pad enlarged for phones ^(from OPENME!^).
)
rem "x is ObjectClass" / "x is ClassType" was removed in Haxe 4.2+
set "FLXG=%FLX%\flixel\group\FlxGroup.hx"
set "FLXP=%FLX%\flixel\system\frontEnds\PluginFrontEnd.hx"
if exist "%FLXG%" if not exist "%FLXG%.compatbak" copy /y "%FLXG%" "%FLXG%.compatbak" >nul
if exist "%FLXP%" if not exist "%FLXP%.compatbak" copy /y "%FLXP%" "%FLXP%.compatbak" >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:FLXG; if(Test-Path $f){$c=[IO.File]::ReadAllText($f); if($c.Contains('is ObjectClass')){$c=$c.Replace('(basic is ObjectClass)','Std.isOfType(basic, ObjectClass)'); [IO.File]::WriteAllText($f,$c); '  patched FlxGroup.hx'} else {'  FlxGroup.hx already patched'}}"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:FLXP; if(Test-Path $f){$c=[IO.File]::ReadAllText($f); if($c.Contains('is ClassType')){$c=$c.Replace('(plugin is ClassType)','Std.isOfType(plugin, ClassType)').Replace('(list[i] is ClassType)','Std.isOfType(list[i], ClassType)'); [IO.File]::WriteAllText($f,$c); '  patched PluginFrontEnd.hx'} else {'  PluginFrontEnd.hx already patched'}}"
echo.

rem ------------------------- 8. build path ----------------------------
rem The Android Gradle Plugin refuses non-ASCII project paths, so when the
rem project lives under a path like "C:\Users\Me\Desktop\Workflow\..." we build
rem through an ASCII junction that points at the real folder.
set "BUILDDIR=%PROJ%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ($env:PROJ -match '[^\x00-\x7F]') { exit 1 } else { exit 0 }"
if errorlevel 1 (
  set "JUNC=%ROOT%\build"
  echo [8/9] Non-ASCII project path detected - using junction:
  echo         !JUNC!  --^>  %PROJ%
  if exist "!JUNC!" rmdir "!JUNC!" 2>nul
  cmd /c mklink /J "!JUNC!" "%PROJ%" >nul
  if exist "!JUNC!" (
    set "BUILDDIR=!JUNC!"
  ) else (
    echo   [ERROR] Could not create the junction. Move the project to a path
    echo           without non-ASCII characters and run again.
    goto fail
  )
) else (
  echo [8/9] Project path is ASCII - building in place.
)
echo.

rem ---------------------------- 9. build ------------------------------
if "%DO_BUILD%"=="0" (
  echo [9/9] Skipped ^(--skip-build^).
  goto done
)
echo [9/9] Building the APK - the first build takes 30-40 minutes ...
echo.
cd /d "%BUILDDIR%"
if "%DO_RELEASE%"=="1" (
  call haxelib run lime build android !LIME_EXTRA!
) else (
  call haxelib run lime build android -debug !LIME_EXTRA!
)
set "RC=!ERRORLEVEL!"
echo.
if not "!RC!"=="0" (
  echo [ERROR] Build failed with exit code !RC!.
  goto fail
)

:done
if "%PERSIST%"=="1" call :write_env
echo =====================================================================
echo  DONE
echo =====================================================================
echo  APK:
dir /b /s "%BUILDDIR%\export\*.apk" 2>nul
echo.
if "%PERSIST%"=="1" (
  echo  Toolchain: %ROOT%
  echo  Helper   : %ROOT%\env.cmd   ^(call it to reuse the toolchain in a shell^)
) else (
  echo  Portable mode - user environment was not modified.
)
echo =====================================================================
if "%NOPAUSE%"=="0" pause
exit /b 0

rem --------------------------- helpers --------------------------------
:usage
echo Usage: install-and-build.cmd [--release] [--arch=arm64] [--skip-build] [--force] [--nopause]
exit /b 0

:fail
echo.
echo =====================================================================
echo  SETUP FAILED
echo =====================================================================
echo  Read the messages above and the logs in "%LOGDIR%".
if "%NOPAUSE%"=="0" pause
exit /b 1

:download
echo     %~nx2
%CURL% -L --fail --retry 3 --retry-delay 5 --silent --show-error -o "%~2" "%~1"
if errorlevel 1 (
  echo     [ERROR] download failed: %~1
  exit /b 1
)
exit /b 0

:unzip
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath $env:ZIP -DestinationPath $env:DEST -Force"
if errorlevel 1 (
  echo     [ERROR] cannot extract %ZIP%
  exit /b 1
)
exit /b 0

:probe_jdk
set "PJDK=%~1"
if not exist "%PJDK%\bin\java.exe" exit /b 1
"%PJDK%\bin\java.exe" -version 2>&1 | findstr /r /c:"version \"1[7-9]\." /c:"version \"[2-9][0-9]\." >nul
if errorlevel 1 exit /b 1
set "JAVA_HOME_USED=%PJDK%"
exit /b 0

:write_env
> "%ROOT%\env.cmd" echo @echo off
>> "%ROOT%\env.cmd" echo set "HAXE_STD_PATH=%HAXEDIR%\std"
>> "%ROOT%\env.cmd" echo set "NEKOPATH=%NEKODIR%"
>> "%ROOT%\env.cmd" echo set "HAXELIB_PATH=%LIBROOT%"
>> "%ROOT%\env.cmd" echo set "JAVA_HOME=%JAVA_HOME_USED%"
>> "%ROOT%\env.cmd" echo set "ANDROID_SDK=%SDK%"
>> "%ROOT%\env.cmd" echo set "ANDROID_HOME=%SDK%"
>> "%ROOT%\env.cmd" echo set "ANDROID_SDK_ROOT=%SDK%"
>> "%ROOT%\env.cmd" echo set "ANDROID_NDK_ROOT=%NDK%"
>> "%ROOT%\env.cmd" echo set "NDK_ROOT=%NDK%"
>> "%ROOT%\env.cmd" echo set "PATH=%HAXEDIR%;%NEKODIR%;%SDK%\platform-tools;%SDK%\cmdline-tools\latest\bin;%JAVA_HOME_USED%\bin;%%PATH%%"
exit /b 0

:haxelib_install
call "%HAXEDIR%\haxelib.exe" list %1 2>nul | findstr /b /c:"%1:" | findstr /c:"[%2]" >nul
if not errorlevel 1 (
  echo   %1 %2 - already installed
  exit /b 0
)
echo   installing %1 %2
( for /l %%i in (1,1,30) do @echo y ) | call "%HAXEDIR%\haxelib.exe" install %1 %2 >"%LOGDIR%\haxelib-%1.log" 2>&1
if errorlevel 1 (
  echo   [ERROR] haxelib install %1 %2 failed - see "%LOGDIR%\haxelib-%1.log"
  exit /b 1
)
exit /b 0

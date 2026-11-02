# Friday Night Funkin' — Android build

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Friday Night Funkin' **0.2.7.1.5** (HaxeFlixel / Lime / OpenFL) for Android,
packaged together with a **one-command Windows toolchain**.

> **EN — why this repo exists.** Compiling an FNF build on Windows is a known
> pain: exact Haxe/Neko/haxelib versions, Android SDK + NDK r21e, a JDK, a flixel
> 4.8.1 that no longer compiles on modern Haxe, Gradle dying on a 170 MB APK and
> refusing non-ASCII project paths. This repository exists **to spare you that
> pain** when building and modding FNF: clone it, run `install-and-build.cmd`
> once, get an APK and a reusable toolchain that stays on your machine.

> **RU — зачем этот репозиторий.** Собрать FNF-сборку на Windows — отдельная
> боль: точные версии Haxe/Neko/haxelib, Android SDK и NDK r21e, JDK, flixel
> 4.8.1, который не собирается новым Haxe, Gradle, падающий на APK в 170 МБ, и
> путь к проекту, который Gradle отказывается принимать. Этот репозиторий нужен,
> **чтобы избавить вас от этой боли** при сборке и моддинге FNF: скачали, один
> раз запустили `install-and-build.cmd` — получили APK и готовый инструментарий,
> который остаётся на компьютере для следующих сборок и модов.

---

## Быстрый старт

Нужен Windows 10/11 x64, интернет и ~8 ГБ свободного места.
Права администратора **не** требуются.

```bat
git clone https://github.com/watsbunny/funkin-android-build.git
cd funkin-android-build
install-and-build.cmd
```

Скрипт сам:

1. проверит curl / PowerShell / интернет;
2. найдёт JDK 17+ (или скачает Eclipse Temurin JDK 21);
3. поставит Haxe 4.3.7 + haxelib + Neko 2.4.1;
4. поставит нужные haxelib-библиотеки;
5. поставит Android SDK (cmdline-tools, platform-tools, build-tools 34/35,
   `platforms;android-35`) и NDK r21e;
6. настроит Lime (`~/.lime/config.xml`) и поднимет память Gradle;
7. пропатчит flixel 4.8.1;
8. обойдёт проблему с русскими буквами в пути;
9. соберёт APK.

Первый раз — **30–40 минут**, повторные сборки — 1–2 минуты.

### Готовый APK

```
export\debug\android\bin\app\build\outputs\apk\debug\*.apk
```

Установка на телефон (включите «Отладка по USB»):

```bat
adb install -r "export\debug\android\bin\app\build\outputs\apk\debug\Funkin-debug.apk"
```

### Флаги установщика

| Флаг | Что делает |
| --- | --- |
| *(без флагов)* | debug-APK, обе архитектуры (armeabi-v7a + arm64-v8a) |
| `--release` | release-сборка (для установки нужен свой ключ подписи) |
| `--arch=arm64` | только arm64-v8a — примерно в 2 раза быстрее и меньше APK |
| `--arch=armv7` | только armeabi-v7a (старые устройства) |
| `--skip-build` | только установить/починить инструментарий |
| `--force` | перекачать и переустановить всё заново |
| `--nopause` | не ждать нажатия клавиши в конце (для CI) |

Примеры:

```bat
install-and-build.cmd --arch=arm64
install-and-build.cmd --release
install-and-build.cmd --skip-build
```

---

## Что устанавливается и куда

Всё ставится в `%LOCALAPPDATA%\FunkinAndroidToolchain`, ничего не пишется за
пределы профиля пользователя, админ не нужен.

| Компонент | Версия |
| --- | --- |
| Haxe + haxelib | 4.3.7 |
| Neko (нужен haxelib и run-скриптам Lime) | 2.4.1 |
| JDK (ставится только если нет JDK 17+) | Eclipse Temurin 21 |
| Android cmdline-tools / platform-tools | latest |
| Android build-tools | 34.0.0 и 35.0.0 |
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

Параметры APK: `com.ninjamuffin99.funkin`, versionName `0.2.7.1`, minSdk 21
(Android 5.0), targetSdk 35, ABI `arm64-v8a` + `armeabi-v7a`, размер ~174 МБ.

---

## Патчи flixel 4.8.1 (делаются автоматически)

Без них проект не собирается современным Haxe. Все изменённые файлы имеют
резервные копии рядом (`.orig`, `.compatbak`).

**1. `flixel/ui/FlxVirtualPad.hx`** — взят из папки `OPENME!` этого репозитория:
экранные кнопки увеличены в 3 раза под современные телефоны, добавлены режимы
`RIGHT_FULL` / `ALTER_FULL`.

**2. `flixel/group/FlxGroup.hx` и `flixel/system/frontEnds/PluginFrontEnd.hx`** —
четыре строки вида `x is ObjectClass` / `x is ClassType` заменены на
`Std.isOfType(x, ...)`. В Haxe 4.2+ оператор `is` с переменной запрещён, из-за
чего flixel 4.8.1 не компилируется («Type not found : ObjectClass»).

Откатить второй патч:

```bat
copy /y "%LOCALAPPDATA%\FunkinAndroidToolchain\haxelib\flixel\4,8,1\flixel\group\FlxGroup.hx.compatbak" ^
        "%LOCALAPPDATA%\FunkinAndroidToolchain\haxelib\flixel\4,8,1\flixel\group\FlxGroup.hx"
```

---

## Ручная сборка / переиспользование инструментария

После установки появляется `%LOCALAPPDATA%\FunkinAndroidToolchain\env.cmd`:

```bat
call "%LOCALAPPDATA%\FunkinAndroidToolchain\env.cmd"
cd /d <путь к проекту>
haxelib run lime build android -debug
```

Полезные команды Lime:

| Команда | Что делает |
| --- | --- |
| `haxelib run lime build android -debug` | debug APK |
| `haxelib run lime build android` | release APK |
| `haxelib run lime build android -arm64` | только arm64 |
| `haxelib run lime build android -clean` | полная пересборка |
| `haxelib run lime test android` | собрать, установить и запустить на телефоне |

---

## Если что-то пошло не так

| Симптом | Решение |
| --- | --- |
| `Your project path contains non-ASCII characters` | Gradle не умеет русские буквы в пути. Установщик сам собирает через junction `...\FunkinAndroidToolchain\build`; если делаете вручную — перенесите проект в путь без кириллицы |
| `packageDebug FAILED` + `java_pid*.hprof` | не хватило памяти Gradle. Нужно `org.gradle.jvmargs=-Xmx4096m` в `%USERPROFILE%\.gradle\gradle.properties` (установщик это пишет) и `gradlew --stop` |
| `Type not found : ObjectClass` | пропал патч flixel (см. выше) — верните файлы из `.compatbak` |
| `haxelib.exe` молча падает (`0xC0000135`) | рядом с `haxelib.exe` нет `neko.dll` / `gcmt-dll.dll` / `*.ndll` — установщик копирует их сам |
| `You must define ANDROID_SDK and ANDROID_NDK_ROOT` | выполните `haxelib run lime setup android` и укажите пути из `%LOCALAPPDATA%\FunkinAndroidToolchain` |
| Ошибки NDK / `ndk-build` | проверьте `ANDROID_NDK_ROOT` — нужен именно NDK r21e |
| Сборка идёт очень медленно | добавьте в исключения антивируса папку проекта, `%LOCALAPPDATA%\FunkinAndroidToolchain` и `%USERPROFILE%\haxelib` |

Логи установщика: `%LOCALAPPDATA%\FunkinAndroidToolchain\logs\`.

---

## Структура репозитория

```
install-and-build.cmd   установщик инструментария и сборщик APK (Windows)
Project.xml             конфигурация Lime/OpenFL проекта
source/                 исходники игры на Haxe
assets/                 ассеты игры (музыка, графика, чарты)
art/                    исходники графики (Flash .fla и т.п.)
OPENME!/                патч flixel 4.8.1 с увеличенным виртуальным геймпадом
example_mods/           примеры модов (polymod)
docs/, .github/         прочее
```

Папка `export/` (результаты сборки) в репозиторий не попадает — она в
`.gitignore`.

---

## Лицензия и кредиты

Код распространяется по **Apache License 2.0** — см. [LICENSE](LICENSE).
Ассеты и персонажи Friday Night Funkin' принадлежат их авторам; репозиторий не
даёт на них никаких прав.

* **Friday Night Funkin'** — [ninjamuffin99](https://twitter.com/ninja_muffin99)
  (код), PhantomArcade3K и Evilsk8r (арт), Kawaisprite (музыка). Оригинал:
  [ninjamuffin99/Funkin](https://github.com/ninjamuffin99/Funkin)
* **Android-порт 0.2.7.1.5** — [luckydog7/Funkin-android](https://github.com/luckydog7/Funkin-android)
* **Скрипт автоматической сборки и настройка тулчейна** — этот репозиторий

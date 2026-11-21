# Chromatic Tide / Android APK build project

The `source/` directory is the *same LÖVE 11.5 game engine* provided in the PortMaster package. The included GitHub Actions workflow packages this into an installable Android **debug APK** using [love-actions-android](https://github.com/love-actions/love-actions-android).

## Build without installing Android Studio

1. Create an empty GitHub repository (private or public).
2. Upload the **contents of this build-kit folder**, preserving `.github/workflows/android-apk.yml` and `source/*.lua`.
3. Open the repository's **Actions** tab, select **Build Chromatic Tide Android APK**, then **Run workflow**.
4. After a successful run, open the build run and download its `ChromaticTide-Android-APK` artifact, extract it, then install the debug `.apk` on your Android device.

This workflow calls a third-party GitHub Action which fetches the official `love-android` 11.5a engine and uses an Android SDK in GitHub's build environment. No external keystore is required for the debug APK. For a signed production release, create a keystore and configure release signing. Review the action's source and permissions before running it.

## Requirements and status

- LÖVE 11.5 Android engine, a device with working OpenGL ES and audio.
- Designed for landscape touch screens. Supports virtual action buttons and tap-to-rotate.
- The APK has **not been built or tested** in this sandbox because the Android SDK and build network are not installed.
- The `.love` file can also be opened directly in a compatible Android LÖVE app for initial gameplay testing.
- This is a portable rules-and-graphics implementation, not the original Processing/Java JVM runtime.

The project contains the entire playable Lua source and icon resources. `TEST_GAMEPLAY.lua` and `TEST_RUNTIME.lua` are source tests, not packaged with the game.

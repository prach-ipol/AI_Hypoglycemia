# Flutter mobile app

The Flutter app uses the Flask API and MongoDB through the backend. It provides a public home page, food search and intake nutrition analysis, contact-number login/registration, and feedback submission. An account is required to analyze an intake; food search is available without logging in.

## Requirements

- Flutter SDK (stable channel) with Dart, Git for Windows, and Android support enabled.
- Android SDK Platform, Android SDK Build Tools, and Android SDK Command-line Tools. Install/manage them with Google's `sdkmanager` command-line tool; an IDE is not needed.
- Java 17 (JDK).
- A running Flask backend and MongoDB database. Install the Python backend requirements from `../backend/requirements.txt` and start `backend/run.py`.

## Command-line setup (no Android Studio required)

Install Flutter from the Flutter SDK archive and add its `bin` directory to `PATH`. Install JDK 17 and Android SDK Command-line Tools, then use `sdkmanager` to install the platform and build tools required by the Flutter project. Set `JAVA_HOME` and `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) to those installations. For example, after installing the Android command-line tools:

```powershell
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "cmdline-tools;latest"
flutter config --android-sdk $env:ANDROID_HOME
flutter doctor --android-licenses
```

Accept the Android SDK licenses when prompted. From this directory, fetch Flutter packages and build:

```powershell
flutter pub get
flutter build apk --release
```

The Android project files are already included in this repository; `flutter create` is only needed if those files are intentionally regenerated.

### PowerShell: `flutter` is not recognized

If Flutter is installed at `C:\dev\flutter`, add its `bin` folder to your user PATH and open a new PowerShell window:

```powershell
$flutterBin = 'C:\dev\flutter\bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $flutterBin) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$flutterBin", 'User')
}
```

For the current PowerShell window only, run `$env:Path = "C:\dev\flutter\bin;$env:Path"`. Confirm with `flutter --version`. If Flutter was installed elsewhere, replace `C:\dev\flutter` with the folder containing the Flutter SDK.

The app manifest permits local HTTP for this development project. Use an HTTPS backend and disable cleartext traffic before distributing a production app.

## Backend address

The default API address `http://10.0.2.2:5000` is for the Android emulator. For a physical phone and computer on the same Wi-Fi network, build with your computer's LAN IP, for example:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.20:5000
```

The Flask backend must be reachable on port 5000 from the device; allow it through the computer firewall on a trusted private network. Do not expose the development HTTP server to the public internet.

## Build and install APK

```powershell
flutter build apk --release
```

The installable universal APK is written to `build/app/outputs/flutter-apk/app-release.apk`. To install on a connected USB-debugging device, run `flutter install`. For a physical phone, set `API_BASE_URL` to the computer's LAN address as above.

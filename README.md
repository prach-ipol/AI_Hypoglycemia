# Hypoglycemia Support and Indian Meal Carbohydrate Calculator

Educational/supportive project. It does not diagnose, recommend insulin or medication doses, or replace medical care. Hypoglycemia prediction remains disabled until a suitable, ethically sourced, labeled dataset has been configured and evaluated.

## Current workspace findings

- `Indian_Food_Nutrition_Processed.csv` has 1,014 foods and nutrition columns, including carbohydrates. It is suitable as a starting point for food search, not for hypoglycemia prediction (no glucose/event labels).
- Python 3.15 is present. Flask/scikit-learn dependencies are listed below; use a supported Python 3.11 or 3.12 installation if dependency wheels are unavailable for 3.15.
- The Flutter mobile source is in `mobile_app`; use its setup guide to install the Flutter/Android toolchain and build an APK. MongoDB Community Server or Atlas is required by the Flask backend.
- No trained model artifact is included. The prediction API reports model unavailable until one is trained from suitable labeled data.

## Backend setup (Windows PowerShell)

1. Install Python 3.11/3.12, Flutter SDK, and MongoDB Community Server or create an Atlas cluster. Confirm with `py -0p`, `flutter --version`, and `mongosh --version`.
2. In PowerShell, create the virtual environment and use its Python executable directly. This does not run an activation script, so PowerShell's script execution policy will not block it:

   ```powershell
   cd backend
   py -3.12 -m venv .venv
   .\.venv\Scripts\python.exe -m pip install --upgrade pip
   .\.venv\Scripts\python.exe -m pip install -r requirements.txt
   ```
   Activation is optional. If you want to use `Activate.ps1`, first run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` in that same PowerShell window, then activate; the setting resets when the window closes.
3. `Copy-Item .env.example .env`; edit `MONGODB_URI`, `JWT_SECRET`, and allowed origins. Keep `.env` private. The `AI_Hypoglycemia` MongoDB database and collections/indexes are initialized by the app at startup.
4. Copy the provided CSV to `data/raw/Indian_Food_Nutrition_Processed.csv` (already present at project root); or set `FOOD_CSV_PATH` to its location.
5. Start backend with `.\.venv\Scripts\python.exe run.py`. Open `http://127.0.0.1:5000/` for the backend landing page, `/health` for MongoDB status, and use the endpoint guide in `docs/API.md` (Flask does not provide generated Swagger UI).

The backend also serves browser pages at `/` (home), `/intake` (nutrition analysis), `/register`, and `/login`. Intake time uses 24-hour `HH:MM`; nutrition estimates are scaled from the CSV reference values. Register with name, email, contact number, and password; log in using contact number and password. Each page includes a feedback form. MongoDB must be running for registration, login, and feedback submissions. Login is available directly; an unregistered contact receives a register-first prompt. Successful logins and analyzed intakes are recorded in MongoDB. For Flutter web, the default API URL is `http://127.0.0.1:5000`; for the Android emulator it is `http://10.0.2.2:5000`. Set `CORS_ORIGINS` to a comma-separated allow-list for deployed clients.

## ML data and training

Put a suitable CSV in `data/raw/` and set `ML_DATASET_PATH`, `ML_TARGET_COLUMN`, and `ML_FEATURE_COLUMNS` in `.env`. The target must be a documented, meaningful hypoglycemia event/risk label; feature values must be available at prediction time. Include `ML_GROUP_COLUMN` for participant IDs when applicable to prevent participant leakage. Then run `python -m ml.train`. The pipeline compares logistic regression, decision tree, random forest, histogram gradient boosting, and KNN, using a stratified 70/30 split (or participant-group split when IDs are configured), and saves the selected pipeline only when the target and data are usable. Read `docs/ML.md`; accuracy alone does not establish clinical performance. The supplied food CSV intentionally fails these checks and must not be used as prediction training data.

## Flutter

Install Flutter, JDK 17, and Android SDK command-line tools (no Android Studio required) using `mobile_app/README.md`. From `mobile_app`, run `flutter pub get` then `flutter build apk --release`. The APK is written to `mobile_app/build/app/outputs/flutter-apk/app-release.apk`. The default `http://10.0.2.2:5000` targets only the Android emulator. For a physical phone, rebuild with `flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_PC_IP:5000`, where `YOUR_PC_IP` is the computer's Wi-Fi address from `ipconfig`. Local HTTP is for development; use HTTPS for deployed apps.

## Privacy and security

Passwords are hashed, personal endpoints require bearer tokens, and records are scoped to the authenticated user. Configure a high-entropy JWT secret and MongoDB access controls, backups, TLS, and retention policy. Delete account data through the authenticated account deletion endpoint. Avoid logging personal health information. Do not commit real patient data, `.env`, or model files from untrusted sources.

## Checks

Install dependencies, then run `pytest` in `backend`. Tests use an in-memory database adapter where practical. MongoDB integration requires a configured MongoDB instance. This project has not been clinically validated.




cd backend
   py -3.12 -m venv .venv
   .\.venv\Scripts\python.exe -m pip install --upgrade pip
   .\.venv\Scripts\python.exe -m pip install -r requirements.txt
   .\.venv\Scripts\python.exe run.py


   In 2nd terminal 
   cd mobile_app
   python -m ml.train
   flutter doctor
   flutter pub get
   flutter run

To build and generate APK for mobile use 
flutter build apk --release






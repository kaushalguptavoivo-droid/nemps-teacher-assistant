# NEMPS Teacher Assistant — Local Setup Status

## Installed and configured

- Node.js LTS is installed.
- Flutter SDK location: `C:\Users\school\development\flutter`
- Flutter SDK `bin` folder was added to the Windows user PATH. Open a new terminal after this change.
- VS Code Flutter extension is installed.
- VS Code workspace settings and Flutter SDK path are configured in `.vscode/settings.json`.
- The project is configured for the supplied Supabase project and Vercel web deployment.

## Next check

Open a fresh VS Code terminal in this project and run:

```powershell
flutter doctor
```

Flutter's first command downloads required web tooling. Keep the internet connected until it completes. Then run:

```powershell
flutter pub get
flutter run -d chrome
```

For deployment, upload this project to GitHub and import it in Vercel.

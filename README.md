# StandoffCheat

Runtime-resolved IL2CPP cheat for **Standoff 2 (iOS)** — ESP, aimbot, recoil control, overlay menu. No hardcoded offsets; every class/field is resolved at runtime through the IL2CPP reflection API.

## What's inside

| Path | Purpose |
|---|---|
| `src/main.mm` | Constructor bootstrap + background update loop |
| `src/il2cpp_resolver.mm` | IL2CPP symbol binding + lazy class resolution |
| `src/esp.mm` | Boxes / health bars / names / distance / snaplines |
| `src/aimbot.mm` | FOV pick, smoothing, assist radius |
| `src/recoil.mm` | No-recoil |
| `src/menu.mm` | Floating button + toggle/slider panel |
| `src/overlay.mm` | Touch-pass overlay window |
| `build.sh` | Compiles `build/StandoffCheat.dylib` (arm64) on macOS |
| `inject.sh` | Injects dylib into IPA + re-signs + repackages |
| `.github/workflows/build.yml` | CI build on GitHub Actions |

## Build & inject locally (macOS)

```bash
./build.sh                     # → build/StandoffCheat.dylib
./inject.sh game.ipa game-cheat.ipa
```

Requires: Xcode + iOS SDK, [insert_dylib](https://github.com/Tyilo/insert_dylib).

## Build via GitHub Actions (no Mac needed)

1. **Upload the IPA** where Actions can reach it:
   - Create a Release and attach the `.ipa` file (up to 2 GB), or
   - Host it at any direct-download HTTPS URL.
2. Go to **Actions → Build StandoffCheat IPA → Run workflow**.
   - Input `ipa`: `release` (pulls latest `.ipa` release asset) or paste a direct URL.
3. Download the patched **Standoff2-cheat.ipa** artifact and sideload with Sideloadly / AltStore / TrollStore.

> The IPA is treated as a build input — it is downloaded at run time, never stored in this repo (1.6 GB does not belong in git).

## Notes

- Aimbot and ESP only touch camera rotation and rendering — nothing a server-side validator checks (collider/ammo/damage are server-validated).
- Recoil nullification is client-side visual only.
- The dylib binds IL2CPP exports via `dlsym` and resolves classes lazily, so it keeps working across game updates while class names hold.
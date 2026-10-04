# Album decision interaction

An isolated Rive CLI prototype for the second interaction in the Album design pass: choosing **Offen**, **Dagegen** or **Dafür** for a travel idea. Each option is clickable, updates the selected tint and moves the selection indicator. The card also communicates the right/left swipe mapping used by the Expo implementation.

## Preview and verify

From this folder:

```sh
rive . --verify
rive inspect . --summary
rive .
```

Headless interaction checks:

```sh
rive . --screenshot=build/open.png --pointer=click@85,192 --advance=1 --data-dump=build/open.json
rive . --screenshot=build/opposed.png --pointer=click@210,192 --advance=1 --data-dump=build/opposed.json
rive . --screenshot=build/approved.png --pointer=click@335,192 --advance=1 --data-dump=build/approved.json
```

The dump should report `selectedIndex` as `0`, `1` and `2`, respectively, and the screenshot should show the matching soft tint. Generated files live in `build/`.

## Runtime boundary

The real card gesture is implemented in `expo/prague-album` with React Native Gesture Handler and Reanimated so it remains compatible with Expo Go. This `.riv` is a standalone, inspectable interaction prototype. Rive's React Native runtime is a separate native dependency and is not included in Expo Go, so this project does not add it to the app.

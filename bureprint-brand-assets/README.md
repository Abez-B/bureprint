# BurePrint Brand Assets

Monochrome brand asset pack based on the supplied B mark image.

## Files
- `original_exact.png` — exact uploaded image, unchanged (181 × 162 RGBA).
- `png/icon-1024.png`, `icon-512.png`, `icon-192.png`, `icon-96.png`, `icon-48.png` — square black-background exports with the complete original composition centered.
- `png/logo-transparent.png` — white mark extracted from the supplied image on transparency; background removed.
- `png/adaptive-foreground.png` and `png/adaptive-background.png` — Android adaptive icon layers.
- `android/res/` — launcher PNGs for common Android densities plus adaptive icon XML and layers.

## Flutter / Android notes
For a Flutter project, `png/icon-1024.png` is a good source for an icon-generation tool such as `flutter_launcher_icons`. Review the output on actual Android launcher shapes before release.
The `android/res` files are Android resource assets, not a replacement for your existing `AndroidManifest.xml` or Flutter project configuration. Merge them into the corresponding `android/app/src/main/res/` resource folders and ensure the manifest points to `@mipmap/ic_launcher`. If your project uses a different Android resource structure, adapt accordingly.

## Important
The source image is preserved exactly. The resized files are raster exports, not reconstructed vector artwork. A true SVG master would require redrawing/tracing the B as vector paths.

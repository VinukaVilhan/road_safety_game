# Font Assets Setup

This directory contains bundled font files for optimal app performance.

## Required Fonts

Download the following fonts from Google Fonts and place them in this directory:

### Inter Font Family
1. **Inter-Regular.ttf** (weight: 400)
   - Download from: https://fonts.google.com/specimen/Inter
   - Select "Regular" variant

2. **Inter-SemiBold.ttf** (weight: 600)
   - Download from: https://fonts.google.com/specimen/Inter
   - Select "SemiBold" variant

3. **Inter-Bold.ttf** (weight: 700)
   - Download from: https://fonts.google.com/specimen/Inter
   - Select "Bold" variant

4. **Inter-Black.ttf** (weight: 900)
   - Download from: https://fonts.google.com/specimen/Inter
   - Select "Black" variant

### Roboto Mono Font Family
1. **RobotoMono-Regular.ttf** (weight: 400)
   - Download from: https://fonts.google.com/specimen/Roboto+Mono
   - Select "Regular" variant

## Quick Setup

1. Visit https://fonts.google.com/
2. Search for "Inter" and download the font family
3. Search for "Roboto Mono" and download the font family
4. Extract the `.ttf` files
5. Rename and place them in this directory as specified above

## Fallback Behavior

If fonts are not bundled, the app will automatically fall back to using Google Fonts package (loaded from network). This ensures the app works during development even without bundled fonts.

## Benefits of Bundled Fonts

- ✅ **Zero network latency** - Fonts load instantly
- ✅ **Works offline** - No internet connection required
- ✅ **Consistent performance** - Same load time every time
- ✅ **Smaller app size** - Only includes needed font variants
- ✅ **Better user experience** - No font loading delays


# 🎨 Sprite & Asset Setup Guide

## How to Create/Add Sprites

### Option 1: **Using Online Tools (EASIEST)**

1. **Create Player Sprite:**
   - Go to: https://www.piskelapp.com/ (Free pixel art editor)
   - Create a 64x64 pixel character
   - Export as PNG
   - Save to: `assets/images/player.png`

2. **Create Background (Optional):**
   - Can use solid color (already set up in code)
   - Or download free textures from: https://kenney.nl/assets (FREE game assets!)

### Option 2: **Using AI/Generator**
- Bing Image Creator / ChatGPT can generate simple sprites
- Search "simple pixel art player character PNG"

### Option 3: **Using Existing Free Assets**

**Best Free Game Asset Sites:**
- ✅ https://kenney.nl/assets - FREE game sprites
- ✅ https://opengameart.org - Community assets
- ✅ https://itch.io - Search "free game assets"

---

## Required Sprite Dimensions

```
player.png
  - Recommended: 64x64 pixels (or 32x32, 48x48 - any size works)
  - Format: PNG with transparent background

background.png (optional)
  - Recommended: 512x512 or higher
  - Format: PNG or JPG
```

---

## File Structure

```
flutter_mathquest/
  assets/
    images/
      player.png          ← CHARACTER SPRITE
      background.png      ← OPTIONAL: Map background
      numbers/            ← NUMBER GRAPHICS (optional)
        number_0.png
        number_1.png
        ...
```

---

## How to Add to Your Project

### Step 1: Place Files
- Put sprite PNG files in `assets/images/`

### Step 2: Update pubspec.yaml
✅ **Already done!** Assets are configured to load from `assets/images/`

### Step 3: Use in Code

**Load Player Sprite:**
```dart
// Automatically loads from assets/images/player.png
try {
  sprite = await Sprite.load('player.png');
} catch (e) {
  print('Sprite not found: $e');
}
```

**Load Background Sprite:**
```dart
// In math_world_game.dart, you can add:
try {
  final background = await Sprite.load('background.png');
  add(SpriteComponent(
    sprite: background,
    size: Vector2(mapWidth, mapHeight),
  ));
} catch (e) {
  print('Background not found: $e');
}
```

---

## Fallback System (Already Implemented!)

If sprites are NOT found:
- ✅ Player renders as a **green circle**
- ✅ Numbers render as **gold circles with numbers**
- ✅ Background renders as **colored checkerboard**

**The game WORKS without sprites!** Add them when you're ready.

---

## Quick PNG Sprite Creation (Using Python)

If you want to create simple sprites programmatically:

```python
from PIL import Image

# Create 64x64 green square (player)
img = Image.new('RGBA', (64, 64), (76, 175, 80, 255))
img.save('player.png')

# Create 50x50 gold circle (number)
img = Image.new('RGBA', (50, 50), (0, 0, 0, 0))  # transparent
pixels = img.load()
for x in range(50):
    for y in range(50):
        dx, dy = x - 25, y - 25
        if dx*dx + dy*dy <= 625:  # circle radius 25
            pixels[x, y] = (255, 215, 0, 255)  # gold
img.save('number_bg.png')
```

---

## Current State

Your game is already set up with **fallback renders**:
- ✅ Green circle for player
- ✅ Gold circles for numbers
- ✅ Grass checkerboard background

**To add custom sprites:**
1. Get PNG files from sources above
2. Put in `assets/images/`
3. Game auto-loads them!

No code changes needed! 🎉

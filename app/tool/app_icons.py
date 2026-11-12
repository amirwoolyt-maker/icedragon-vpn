"""Generates all IceDragon VPN icons from the official master icon.

Master icon reference:
- app/assets/master_icon.png (1024x1024 official IceDragon icon)

Generates:
1. Windows desktop app icon:
   app/windows/runner/resources/app_icon.ico (sizes: 16, 20, 24, 32, 40, 48, 64, 128, 256 px)
2. Core Windows binary icon:
   core/internal/desktop/appicon.ico (sizes: 16, 20, 24, 32, 40, 48, 64, 128, 256 px)
3. In-app logo:
   app/assets/logo.png (256x256 px)
4. Android launcher icons:
   app/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png (48, 72, 96, 144, 192 px)
   and adaptive icons foreground/background
5. Browser extension icons:
   extension/assets/icons/icon{16,32,48,128}.png
   extension/assets/icons/icon-off{16,32,48,128}.png (grayscale/muted)
6. System tray icons:
   app/assets/tray/ (off, on, idle, error, busy1..4) in .ico and .png
   core/internal/desktop/tray/ (running, set, running-asleep, set-asleep, waiting, error, off) in .ico and .png
7. macOS AppIcon set:
   app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{16,32,64,128,256,512,1024}.png
8. Linux desktop app icon:
   app/linux/runner/resources/app_icon.png (256x256 px)
9. Web dashboard icon:
   core/internal/service/web/icon.png (192x192 px)
10. Documentation logo:
    docs/images/logo.png (256x256 px)
"""

import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(HERE, '..'))
CORE = os.path.abspath(os.path.join(APP, '..', 'core'))
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
EXTENSION = os.path.abspath(os.path.join(APP, '..', 'extension', 'assets', 'icons'))
MASTER_ICON = os.path.join(APP, 'assets', 'master_icon.png')

WINDOWS_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
TRAY_SIZES = [16, 20, 24, 32, 48, 64]
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]
DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

# Status dot colors
DOT_GOOD = (63, 225, 176)   # emerald green
DOT_BAD = (226, 40, 80)     # red
DOT_SET = (96, 165, 250)    # blue
DARK_BG = (1, 8, 26)        # master icon background


def load_master():
    if not os.path.exists(MASTER_ICON):
        raise FileNotFoundError(f"Master icon not found at {MASTER_ICON}")
    img = Image.open(MASTER_ICON)
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    return img


def resize_image(img, size, sharpen=False):
    """Resize image maintaining 1:1 aspect ratio with high quality Lanczos filtering."""
    out = img.resize((size, size), Image.LANCZOS)
    if sharpen and size <= 48:
        radius = 0.5 if size <= 24 else 0.7
        out = out.filter(ImageFilter.UnsharpMask(radius=radius, percent=130, threshold=0))
    return out


def write_ico(path, master, sizes=WINDOWS_SIZES):
    """Write multi-resolution ICO file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    images = [resize_image(master, s, sharpen=True) for s in sizes]
    images[-1].save(path, format='ICO', sizes=[(s, s) for s in sizes], append_images=images[:-1])


def make_grayscale(img, brightness=0.72):
    """Convert RGBA image to high-contrast grayscale while preserving alpha."""
    r, g, b, a = img.split()
    gray = ImageOps.grayscale(Image.merge('RGB', (r, g, b)))
    if brightness != 1.0:
        gray = ImageEnhance.Brightness(gray).enhance(brightness)
    return Image.merge('RGBA', (gray, gray, gray, a))


def make_faded(img, factor=0.65):
    """Fade brightness and contrast for asleep state."""
    r, g, b, a = img.split()
    rgb = Image.merge('RGB', (r, g, b))
    rgb = ImageEnhance.Brightness(rgb).enhance(factor)
    rgb = ImageEnhance.Contrast(rgb).enhance(factor * 1.1)
    return Image.merge('RGBA', (*rgb.split(), a))


def asleep_color(color):
    """Mute color towards gray for sleeping state."""
    return tuple(round(c * 0.45 + g * 0.55) for c, g in zip(color, (150, 160, 158)))


def add_status_dot(img, dot_color, dot_ratio=0.28):
    """Adds a status indicator dot with dark outline at bottom-right corner."""
    out = img.copy()
    draw = ImageDraw.Draw(out)
    w, h = out.size
    r = int(w * dot_ratio / 2)
    cx = int(w - r - w * 0.05)
    cy = int(h - r - h * 0.05)
    border = max(1, int(r * 0.28))
    # Outer dark shadow/border
    draw.ellipse([cx - r - border, cy - r - border, cx + r + border, cy + r + border], fill=(0, 0, 0, 240))
    # Inner colored dot
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dot_color + (255,))
    return out


def make_busy_frame(master, frame, total_frames=4):
    """Creates a connecting frame with animated white dot."""
    out = master.copy()
    draw = ImageDraw.Draw(out)
    w, h = out.size
    r = int(w * 0.12)
    margin = int(w * 0.08)
    positions = [
        (w - r - margin, margin + r),              # top-right
        (w - r - margin, h - r - margin),          # bottom-right
        (margin + r, h - r - margin),              # bottom-left
        (margin + r, margin + r),                  # top-left
    ]
    cx, cy = positions[(frame - 1) % len(positions)]
    border = max(1, int(r * 0.25))
    draw.ellipse([cx - r - border, cy - r - border, cx + r + border, cy + r + border], fill=(0, 0, 0, 240))
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))
    return out


def generate_windows_and_core(master):
    # 1. Windows app icon
    win_ico = os.path.join(APP, 'windows', 'runner', 'resources', 'app_icon.ico')
    write_ico(win_ico, master, WINDOWS_SIZES)

    # 2. Core Windows binary icon
    core_ico = os.path.join(CORE, 'internal', 'desktop', 'appicon.ico')
    write_ico(core_ico, master, WINDOWS_SIZES)

    # Web dashboard icon
    web_icon = os.path.join(CORE, 'internal', 'service', 'web', 'icon.png')
    resize_image(master, 192).save(web_icon, optimize=True)


def generate_app_logo(master):
    # 3. In-app logo (256x256)
    logo_path = os.path.join(APP, 'assets', 'logo.png')
    resize_image(master, 256).save(logo_path, optimize=True)


def generate_android(master):
    # 4. Android launcher icons
    for dpi, k in DENSITY.items():
        folder = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(folder, exist_ok=True)
        # Legacy ic_launcher.png
        size = round(48 * k)
        resize_image(master, size).save(os.path.join(folder, 'ic_launcher.png'), optimize=True)

        # Adaptive icon foreground and background
        px = round(108 * k)
        # Background: dark navy
        bg = Image.new('RGBA', (px, px), DARK_BG + (255,))
        bg.save(os.path.join(folder, 'ic_launcher_background.png'), optimize=True)
        # Foreground: dragon art centered inside safe zone (72dp of 108dp)
        fg_size = round(72 * k)
        scaled_art = resize_image(master, fg_size)
        fg = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        fg.alpha_composite(scaled_art, ((px - fg_size) // 2, (px - fg_size) // 2))
        fg.save(os.path.join(folder, 'ic_launcher_foreground.png'), optimize=True)

    # Android launch splash screen logo (240x240)
    splash_dir = os.path.join(RES, 'drawable-xxhdpi')
    os.makedirs(splash_dir, exist_ok=True)
    resize_image(master, 240).save(os.path.join(splash_dir, 'splash_logo.png'), optimize=True)

    # Android TV banner (320x180)
    banner_dir = os.path.join(RES, 'drawable-xhdpi')
    os.makedirs(banner_dir, exist_ok=True)
    banner = Image.new('RGBA', (320, 180), DARK_BG + (255,))
    dragon_banner = resize_image(master, 140)
    banner.alpha_composite(dragon_banner, ((320 - 140) // 2, (180 - 140) // 2))
    banner.save(os.path.join(banner_dir, 'banner.png'), optimize=True)


def generate_extension(master):
    # 5. Extension icons (16, 32, 48, 128) and off-state variants
    os.makedirs(EXTENSION, exist_ok=True)
    ext_sizes = [16, 32, 48, 128]
    for s in ext_sizes:
        # Normal
        icon = resize_image(master, s, sharpen=True)
        icon.save(os.path.join(EXTENSION, f'icon{s}.png'), optimize=True)

        # Off-state (grayscale/muted)
        icon_off = make_grayscale(icon)
        icon_off.save(os.path.join(EXTENSION, f'icon-off{s}.png'), optimize=True)


def make_rounded_tray(img, radius_ratio=0.22):
    """Apply rounded corners with transparent background to tray icon."""
    w, h = img.size
    mask = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=round(w * radius_ratio), fill=255)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def generate_tray(master):
    # 6. Tray icons
    # Base 256px with rounded transparent corners for clean tray badges
    base = make_rounded_tray(resize_image(master, 256))
    base_gray = make_grayscale(base)
    base_faded = make_faded(base)

    app_tray_dir = os.path.join(APP, 'assets', 'tray')
    core_tray_dir = os.path.join(CORE, 'internal', 'desktop', 'tray')
    os.makedirs(app_tray_dir, exist_ok=True)
    os.makedirs(core_tray_dir, exist_ok=True)

    # App tray icons
    app_icons = {
        'off': base_gray,
        'on': add_status_dot(base, DOT_GOOD),
        'idle': add_status_dot(base, DOT_GOOD),
        'error': add_status_dot(base, DOT_BAD),
    }
    for i in range(1, 5):
        app_icons[f'busy{i}'] = make_busy_frame(base, i)

    for name, img in app_icons.items():
        write_ico(os.path.join(app_tray_dir, f'{name}.ico'), img, TRAY_SIZES)
        resize_image(img, 64).save(os.path.join(app_tray_dir, f'{name}.png'), optimize=True)

    # Core tray icons
    core_icons = {
        'running': add_status_dot(base, DOT_GOOD),
        'set': add_status_dot(base, DOT_SET),
        'running-asleep': add_status_dot(base_faded, asleep_color(DOT_GOOD)),
        'set-asleep': add_status_dot(base_faded, asleep_color(DOT_SET)),
        'waiting': add_status_dot(base, (255, 255, 255)),
        'error': add_status_dot(base, DOT_BAD),
        'off': base_gray,
    }

    for name, img in core_icons.items():
        write_ico(os.path.join(core_tray_dir, f'{name}.ico'), img, TRAY_SIZES)
        resize_image(img, 32).save(os.path.join(core_tray_dir, f'{name}.png'), optimize=True)


def generate_macos(master):
    folder = os.path.join(APP, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(folder, exist_ok=True)
    for s in MACOS_SIZES:
        resize_image(master, s).save(os.path.join(folder, f'app_icon_{s}.png'), optimize=True)


def generate_linux(master):
    linux_icon = os.path.join(APP, 'linux', 'runner', 'resources', 'app_icon.png')
    os.makedirs(os.path.dirname(linux_icon), exist_ok=True)
    resize_image(master, 256).save(linux_icon, optimize=True)


def generate_docs_logo(master):
    docs_dir = os.path.abspath(os.path.join(APP, '..', 'docs', 'images'))
    if os.path.exists(docs_dir):
        resize_image(master, 256).save(os.path.join(docs_dir, 'logo.png'), optimize=True)


def main():
    print("Loading master icon from:", MASTER_ICON)
    master = load_master()
    print("Master icon size:", master.size)

    print("Generating Windows and Core icons...")
    generate_windows_and_core(master)

    print("Generating App Logo...")
    generate_app_logo(master)

    print("Generating Android Launcher & Adaptive icons...")
    generate_android(master)

    print("Generating Browser Extension icons...")
    generate_extension(master)

    print("Generating Tray icons...")
    generate_tray(master)

    print("Generating macOS icons...")
    generate_macos(master)

    print("Generating Linux desktop icon...")
    generate_linux(master)

    print("Generating Documentation logo...")
    generate_docs_logo(master)

    print("All IceDragon visual assets successfully generated!")


if __name__ == '__main__':
    main()

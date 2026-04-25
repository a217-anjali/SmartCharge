#!/usr/bin/env python3
"""
Generate a professional 1024x1024 app icon for SmartCharge.

Design:
  - Deep blue-to-purple gradient background with rounded corners
  - White battery shape (rounded rectangle) with a green partial fill
  - White lightning bolt symbol inside the battery
  - Modern, flat design style

Requires: Pillow (pip install Pillow)
Output:   SmartCharge/SmartCharge/Resources/AppIcon.png
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Error: Pillow is not installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SIZE = 1024
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "SmartCharge" / "Resources"
OUTPUT_PATH = OUTPUT_DIR / "AppIcon.png"

# Colors
BG_TOP = (20, 30, 120)       # Deep blue
BG_BOTTOM = (100, 40, 160)   # Purple
BATTERY_OUTLINE = (255, 255, 255)
BATTERY_FILL_GREEN = (60, 200, 100)
LIGHTNING_COLOR = (255, 255, 255)
SHADOW_COLOR = (0, 0, 0, 40)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB tuples."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle on an ImageDraw context."""
    x0, y0, x1, y1 = bbox
    # Use pieslice for corners and rectangles for the body
    d = radius * 2
    # Four corner circles
    draw.pieslice([x0, y0, x0 + d, y0 + d], 180, 270, fill=fill, outline=outline, width=width)
    draw.pieslice([x1 - d, y0, x1, y0 + d], 270, 360, fill=fill, outline=outline, width=width)
    draw.pieslice([x0, y1 - d, x0 + d, y1], 90, 180, fill=fill, outline=outline, width=width)
    draw.pieslice([x1 - d, y1 - d, x1, y1], 0, 90, fill=fill, outline=outline, width=width)
    # Rectangles to fill the body
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill, outline=None)
    draw.rectangle([x0, y0 + radius, x0 + radius, y1 - radius], fill=fill, outline=None)
    draw.rectangle([x1 - radius, y0 + radius, x1, y1 - radius], fill=fill, outline=None)
    # Draw the outline by drawing four arcs and four lines
    if outline:
        draw.arc([x0, y0, x0 + d, y0 + d], 180, 270, fill=outline, width=width)
        draw.arc([x1 - d, y0, x1, y0 + d], 270, 360, fill=outline, width=width)
        draw.arc([x0, y1 - d, x0 + d, y1], 90, 180, fill=outline, width=width)
        draw.arc([x1 - d, y1 - d, x1, y1], 0, 90, fill=outline, width=width)
        draw.line([x0 + radius, y0, x1 - radius, y0], fill=outline, width=width)
        draw.line([x0 + radius, y1, x1 - radius, y1], fill=outline, width=width)
        draw.line([x0, y0 + radius, x0, y1 - radius], fill=outline, width=width)
        draw.line([x1, y0 + radius, x1, y1 - radius], fill=outline, width=width)


def draw_gradient_background(img):
    """Fill the image with a vertical blue-to-purple gradient."""
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / SIZE
        color = lerp_color(BG_TOP, BG_BOTTOM, t)
        draw.line([(0, y), (SIZE - 1, y)], fill=color)


def draw_background_rounded_mask(img, radius=180):
    """Apply macOS-style rounded corners to the background."""
    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    draw_rounded_rect(mask_draw, [0, 0, SIZE - 1, SIZE - 1], radius, fill=255)
    # Apply the mask: make corners transparent
    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rgba = img.convert("RGBA")
    result.paste(rgba, mask=mask)
    return result


def generate_icon():
    """Generate the SmartCharge app icon."""
    # Create base image with gradient
    img = Image.new("RGB", (SIZE, SIZE), BG_TOP)
    draw_gradient_background(img)

    # Apply rounded corners
    img = draw_background_rounded_mask(img)
    draw = ImageDraw.Draw(img)

    # --- Battery body dimensions ---
    # Battery body is centered, slightly above center
    bat_w = 460
    bat_h = 280
    bat_x = (SIZE - bat_w) // 2
    bat_y = (SIZE - bat_h) // 2 - 10
    bat_radius = 40
    outline_width = 14

    # Battery terminal (the small bump on the right)
    term_w = 36
    term_h = 100
    term_x = bat_x + bat_w
    term_y = bat_y + (bat_h - term_h) // 2
    term_radius = 14

    # --- Draw battery outline (white) ---
    draw_rounded_rect(draw, [bat_x, bat_y, bat_x + bat_w, bat_y + bat_h],
                      bat_radius, outline=BATTERY_OUTLINE, width=outline_width)

    # Battery terminal
    draw_rounded_rect(draw, [term_x, term_y, term_x + term_w, term_y + term_h],
                      term_radius, fill=BATTERY_OUTLINE)

    # --- Draw green fill (partial -- about 65% to represent healthy charge) ---
    fill_pct = 0.65
    fill_margin = outline_width // 2 + 6
    fill_x0 = bat_x + fill_margin
    fill_y0 = bat_y + fill_margin
    fill_x1 = bat_x + fill_margin + int((bat_w - 2 * fill_margin) * fill_pct)
    fill_y1 = bat_y + bat_h - fill_margin
    fill_radius = bat_radius - fill_margin

    # Draw a green gradient fill (lighter green at top, darker at bottom)
    fill_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fill_draw = ImageDraw.Draw(fill_img)
    green_top = (80, 220, 120, 230)
    green_bottom = (40, 170, 80, 230)
    for y in range(fill_y0, fill_y1 + 1):
        t = (y - fill_y0) / max(1, fill_y1 - fill_y0)
        c = tuple(int(a + (b - a) * t) for a, b in zip(green_top, green_bottom))
        fill_draw.line([(fill_x0, y), (fill_x1, y)], fill=c)

    # Mask the fill to rounded rect shape
    fill_mask = Image.new("L", (SIZE, SIZE), 0)
    fill_mask_draw = ImageDraw.Draw(fill_mask)
    draw_rounded_rect(fill_mask_draw, [fill_x0, fill_y0, fill_x1, fill_y1],
                      fill_radius, fill=255)
    fill_final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fill_final.paste(fill_img, mask=fill_mask)
    img = Image.alpha_composite(img, fill_final)
    draw = ImageDraw.Draw(img)

    # --- Lightning bolt ---
    # A bold, geometric lightning bolt centered in the battery
    cx = bat_x + bat_w // 2
    cy = bat_y + bat_h // 2
    bolt_scale = 1.15

    bolt_points = [
        (cx - 10 * bolt_scale, cy - 95 * bolt_scale),   # top
        (cx + 50 * bolt_scale, cy - 95 * bolt_scale),   # top-right
        (cx + 8 * bolt_scale,  cy - 10 * bolt_scale),   # middle-right notch
        (cx + 55 * bolt_scale, cy - 10 * bolt_scale),   # mid-right point
        (cx + 10 * bolt_scale, cy + 95 * bolt_scale),   # bottom
        (cx - 45 * bolt_scale, cy + 10 * bolt_scale),   # middle-left notch
        (cx - 5 * bolt_scale,  cy + 10 * bolt_scale),   # mid-left point
    ]

    # Draw a subtle shadow
    shadow_offset = 4
    shadow_points = [(x + shadow_offset, y + shadow_offset) for x, y in bolt_points]
    draw.polygon(shadow_points, fill=SHADOW_COLOR)

    # Draw the bolt
    draw.polygon(bolt_points, fill=LIGHTNING_COLOR)

    # --- Save ---
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(str(OUTPUT_PATH), "PNG")
    print(f"Icon saved to {OUTPUT_PATH}")


if __name__ == "__main__":
    generate_icon()

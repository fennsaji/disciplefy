#!/usr/bin/env python3
"""
Regenerates every square icon variant from the vector master.

Run from the repo root:  python3 brand/build-icons.py

WHY THE INSETS DIFFER
---------------------
The symbol is taller than it is wide, so a square canvas is always
height-constrained: the mark's height equals (1 - 2*inset) of the canvas.
Each surface masks the canvas differently, so each needs its own inset:

  * Android adaptive  — the OS masks to a circle and `ic_launcher.xml` applies
    a further 16% inset of its own. Both compound, so this file's inset must be
    small or the mark ends up tiny. 0.07 lands on ~63dp of the 66dp safe circle.
  * Standard app icon — iOS, Android legacy, PWA and apple-touch. Rounded-square
    masks only clip the corners, so the mark can be much larger.
  * Maskable (PWA)    — spec reserves a 80% safe zone for aggressive masks, so
    this one is deliberately the smallest.
  * Favicon           — rendered as small as 16px, so it should nearly fill the
    canvas or it becomes an unreadable speck.
"""
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "brand")

GOLD, BLACK, WHITE = "#E3B154", "#0B0B0B", "#FFFFFF"
SW, SH = 863.0, 1119.0          # symbol master viewBox
CANVAS = 1024.0

# The traced master carries ~7% empty margin inside its viewBox (a by-product of
# the border added before tracing). Without compensating, every inset below
# would silently render ~7% smaller than asked for.
MASTER_CONTENT_RATIO = 0.929

# surface -> fraction of the canvas the VISIBLE mark should occupy
FILL = {
    "adaptive": 0.88,   # compounded with ic_launcher.xml's own 16% inset
    "app_icon": 0.78,   # iOS / Android legacy / PWA / apple-touch
    "maskable": 0.62,   # PWA maskable safe zone
    "favicon": 0.90,    # must survive being drawn at 16px
}


def master():
    src = open(os.path.join(BRAND, "disciplefy-symbol-master.svg")).read()
    transform = re.search(r'<g transform="([^"]+)"', src).group(1)
    paths = re.findall(r'<path d="([^"]+)"', src, re.S)
    inner = "\n".join('      <path d="%s"/>' % p.strip() for p in paths)
    return transform, inner


TRANSFORM, INNER = master()


def square(fill_colour, bg, fill_fraction):
    """Square icon with the mark scaled to `fill_fraction` of the canvas height."""
    # divide by MASTER_CONTENT_RATIO so `fill_fraction` describes the visible
    # mark, not the padded viewBox around it
    scale = (CANVAS * fill_fraction / MASTER_CONTENT_RATIO) / SH
    tx, ty = (CANVAS - SW * scale) / 2, (CANVAS - SH * scale) / 2
    rect = '  <rect width="1024" height="1024" fill="%s"/>\n' % bg if bg else ""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" '
        'aria-label="Disciplefy">\n  <title>Disciplefy</title>\n%s'
        '  <g transform="translate(%.2f,%.2f) scale(%.5f)">\n'
        '    <g transform="%s" fill="%s" stroke="none">\n%s\n    </g>\n  </g>\n</svg>\n'
        % (rect, tx, ty, scale, TRANSFORM, fill_colour, INNER)
    )


def write(rel, content):
    path = os.path.join(BRAND, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(content)
    return path


def render(svg_rel, out_rel, size, transparent=True):
    src, dst = os.path.join(BRAND, svg_rel), os.path.join(BRAND, out_rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cmd = ["rsvg-convert", "-w", str(size), "-h", str(size)]
    if transparent:
        cmd += ["-b", "none"]
    subprocess.run(cmd + [src, "-o", dst], check=True)
    return dst


def main():
    write("app-icon/gold-on-black.svg", square(GOLD, BLACK, FILL["app_icon"]))
    write("app-icon/black-on-white.svg", square(BLACK, WHITE, FILL["app_icon"]))
    write("app-icon/white-on-black.svg", square(WHITE, BLACK, FILL["app_icon"]))
    write("app-icon/adaptive-foreground.svg", square(GOLD, None, FILL["adaptive"]))
    write("app-icon/maskable.svg", square(GOLD, BLACK, FILL["maskable"]))
    write("web/favicon.svg", square(GOLD, None, FILL["favicon"]))

    render("app-icon/gold-on-black.svg", "app-icon/icon-1024.png", 1024, transparent=False)
    render("app-icon/adaptive-foreground.svg", "app-icon/adaptive-foreground-1024.png", 1024)
    for s in (16, 32, 48, 192, 512):
        render("web/favicon.svg", "web/favicon-%d.png" % s, s)
    # apple-touch-icon stays opaque: iOS composites transparency onto black and
    # expects a solid tile.
    render("app-icon/gold-on-black.svg", "web/apple-touch-icon.png", 180, transparent=False)

    print("brand icons rebuilt:")
    for k, v in FILL.items():
        print("  %-9s mark fills %.0f%% of canvas" % (k, v * 100))


if __name__ == "__main__":
    main()

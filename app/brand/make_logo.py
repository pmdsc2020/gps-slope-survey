"""GPS Slope Survey logo.

The mark: a ground slope (right triangle) with its angle arc, three survey points
along the slope line, and an amber GPS pin standing on the upper point. Behind it,
contour lines of the hill. Drawn on Android's 108 x 108 adaptive-icon canvas so the
same geometry serves the launcher icon, the in-app logo and the share files.
The Flutter painter in lib/ui/logo.dart uses these same coordinates.
"""
import math
import os
import sys

FOREST = '#0E3B2C'   # background, deep
FIELD = '#1E6A4D'    # background, light end of gradient
CONTOUR = '#3F8A69'
GROUND = '#EAF2EA'
AMBER = '#F2B31B'
INK = '#0E3B2C'

# Geometry (108 canvas, safe zone = circle r33 at 54,54)
A = (26.0, 77.0)      # foot of slope
B = (81.0, 77.0)      # right angle
C = (81.0, 45.0)      # top of slope
PIN_T = 0.80          # pin stands on the slope line at this fraction


def on_slope(t):
    return (A[0] + (C[0] - A[0]) * t, A[1] + (C[1] - A[1]) * t)


def pin_path(tip, h=25.0, r=8.6):
    """Teardrop pin with its point at `tip`, total height h, head radius r."""
    x, y = tip
    cy = y - h + r
    # tangent points from tip to circle
    d = h - r
    a = math.asin(r / d)
    tx = r * math.cos(a)
    ty = cy + r * math.sin(a)
    return (f'M{x:.2f} {y:.2f} L{x - tx:.2f} {ty:.2f} '
            f'A{r} {r} 0 1 1 {x + tx:.2f} {ty:.2f} Z'), (x, cy)


def contours(color, op):
    lines = [
        'M-4 40 C 18 30, 34 34, 52 26 S 88 14, 112 20',
        'M-4 58 C 16 50, 34 52, 50 44 S 86 30, 112 36',
        'M-4 92 C 20 86, 44 92, 64 84 S 96 76, 112 80',
        'M-4 104 C 24 100, 50 106, 72 99 S 100 94, 112 96',
    ]
    return ''.join(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="1.6" '
                   f'stroke-linecap="round" opacity="{op}"/>' for d in lines)


def art(mono=False):
    ground = '#000' if mono else GROUND
    amber = '#000' if mono else AMBER
    pin, head = pin_path(on_slope(PIN_T), h=26.0, r=9.2)
    tri = f'M{A[0]} {A[1]} L{B[0]} {B[1]} L{C[0]} {C[1]} Z'
    # angle arc at A, between AB and AC
    ang = math.atan2(A[1] - C[1], C[0] - A[0])
    R = 17.0
    ex, ey = A[0] + R * math.cos(ang), A[1] - R * math.sin(ang)
    arc = f'M{A[0]} {A[1]} L{A[0] + R} {A[1]} A{R} {R} 0 0 0 {ex:.2f} {ey:.2f} Z'
    pts = [on_slope(t) for t in (0.42, 0.61)]
    if mono:
        # one colour; holes cut with a mask
        holes = ''.join(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.6" fill="#000"/>' for x, y in pts)
        return f'''
        <defs><mask id="m"><rect width="108" height="108" fill="#fff"/>
          <path d="{arc}" fill="#000"/>
          {holes}
          <circle cx="{head[0]:.2f}" cy="{head[1]:.2f}" r="3.4" fill="#000"/>
          <path d="{pin}" fill="none" stroke="#000" stroke-width="3"/>
        </mask></defs>
        <g mask="url(#m)"><path d="{tri}" fill="#000"/><path d="{pin}" fill="#000"/></g>'''
    dots = ''.join(
        f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3.4" fill="{INK}"/>'
        f'<circle cx="{x:.2f}" cy="{y:.2f}" r="1.4" fill="{GROUND}"/>' for x, y in pts)
    return f'''
    <path d="{tri}" fill="{ground}"/>
    <path d="{arc}" fill="{AMBER}"/>
    {dots}
    <path d="{pin}" fill="{amber}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
    <circle cx="{head[0]:.2f}" cy="{head[1]:.2f}" r="3.4" fill="{INK}"/>'''


def background():
    return f'''<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{FIELD}"/><stop offset="1" stop-color="{FOREST}"/></linearGradient></defs>
      <rect width="108" height="108" fill="url(#g)"/>{contours(CONTOUR, 0.55)}'''


def svg(kind, size=432):
    if kind == 'foreground':
        inner = art()
    elif kind == 'background':
        inner = background()
    elif kind == 'mono':
        inner = art(mono=True)
    elif kind == 'legacy':      # rounded square, art enlarged a little
        inner = (f'<clipPath id="r"><rect width="108" height="108" rx="24"/></clipPath>'
                 f'<g clip-path="url(#r)">{background()}'
                 f'<g transform="translate(54 54) scale(1.18) translate(-54 -54)">{art()}</g></g>')
    elif kind == 'master':      # square, for store/share
        inner = f'{background()}<g transform="translate(54 54) scale(1.18) translate(-54 -54)">{art()}</g>'
    elif kind == 'safe':        # preview with the safe-zone circle
        inner = (f'{background()}{art()}<circle cx="54" cy="54" r="33" fill="none" '
                 f'stroke="#ff2d55" stroke-width="0.6"/>')
    else:
        raise ValueError(kind)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" '
            f'width="{size}" height="{size}">{inner}</svg>')


def render(page, svg_str, size, path, transparent=True):
    s = svg_str.replace('width="432" height="432"', f'width="{size}" height="{size}"')
    page.set_viewport_size({'width': size, 'height': size})
    page.set_content(f'<html><body style="margin:0;background:transparent">{s}</body></html>')
    page.screenshot(path=path, omit_background=transparent,
                    clip={'x': 0, 'y': 0, 'width': size, 'height': size})


if __name__ == '__main__':
    from playwright.sync_api import sync_playwright
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        p = b.new_page()
        for k in ('foreground', 'background', 'mono', 'legacy', 'master', 'safe'):
            open(f'{out}/{k}.svg', 'w').write(svg(k))
        render(p, svg('safe'), 432, f'{out}/preview_safe.png', False)
        render(p, svg('legacy'), 192, f'{out}/preview_legacy192.png')
        render(p, svg('legacy'), 48, f'{out}/preview_legacy48.png')
        render(p, svg('mono'), 192, f'{out}/preview_mono.png')
        b.close()

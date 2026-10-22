"""Renders the launcher icons, in-app logo and share files from make_logo.py.

Run from this folder:  python3 build_assets.py <share-output-folder>
Needs Playwright (Chromium) and the Barlow fonts in ../assets/fonts.
"""
import os
import sys

from playwright.sync_api import sync_playwright

import make_logo as L

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
RES = f'{APP}/android/app/src/main/res'
SHARE = sys.argv[1] if len(sys.argv) > 1 else f'{HERE}/out'
FONTS = f'{APP}/assets/fonts'
os.makedirs(SHARE, exist_ok=True)
os.makedirs(f'{APP}/assets/logo', exist_ok=True)

dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
with sync_playwright() as pw:
    b = pw.chromium.launch()
    p = b.new_page()
    for d, m in dens.items():
        out = f'{RES}/mipmap-{d}'
        os.makedirs(out, exist_ok=True)
        L.render(p, L.svg('legacy'), int(48 * m), f'{out}/ic_launcher.png')
        L.render(p, L.svg('foreground'), int(108 * m), f'{out}/ic_launcher_foreground.png')
        L.render(p, L.svg('background'), int(108 * m), f'{out}/ic_launcher_background.png', False)
        L.render(p, L.svg('mono'), int(108 * m), f'{out}/ic_launcher_monochrome.png')
    # in-app
    L.render(p, L.svg('legacy'), 512, f'{APP}/assets/logo/logo_mark.png')
    # for sharing
    L.render(p, L.svg('master'), 1024, f'{SHARE}/gps-slope-survey-logo-1024.png', False)
    L.render(p, L.svg('master'), 512, f'{SHARE}/gps-slope-survey-logo-512.png', False)
    L.render(p, L.svg('legacy'), 512, f'{SHARE}/gps-slope-survey-logo-rounded-512.png')
    open(f'{SHARE}/gps-slope-survey-logo.svg', 'w').write(L.svg('master', 1024).replace(
        'width="1024" height="1024"', 'width="1024" height="1024"'))
    mark = L.svg('legacy', 160).replace('width="160" height="160"', 'width="160" height="160"')
    html = f'''<html><head><style>
      @font-face{{font-family:B;font-weight:700;src:url(file://{FONTS}/BarlowSemiCondensed-Bold.ttf)}}
      @font-face{{font-family:B;font-weight:500;src:url(file://{FONTS}/BarlowSemiCondensed-Medium.ttf)}}
      body{{margin:0;background:#fff;font-family:B}}
      .row{{display:flex;align-items:center;gap:36px;padding:50px 64px}}
      .t1{{font-size:86px;font-weight:700;color:#0E3B2C;line-height:1;letter-spacing:.5px}}
      .t2{{font-size:36px;font-weight:500;color:#4D6158;margin-top:12px}}
      .t2 b{{color:#C98F00;font-weight:700}}
    </style></head><body><div class="row">{mark}<div>
      <div class="t1">GPS Slope Survey</div>
      <div class="t2">Land slope from phone GPS &middot; <b>जमिनीचा उतार</b></div>
    </div></div></body></html>'''
    open('/tmp/slope_lockup.html', 'w').write(html)
    p.set_viewport_size({'width': 1120, 'height': 260})
    p.goto('file:///tmp/slope_lockup.html')
    p.wait_for_timeout(600)
    p.screenshot(path=f'{SHARE}/gps-slope-survey-logo-lockup.png',
                 clip={'x': 0, 'y': 0, 'width': 1120, 'height': 260})
    b.close()
print('ok')

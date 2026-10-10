# GPS Slope Survey

Mobile field app for measuring land slope from GPS points taken on the phone. Built for watershed and soil and water conservation planning.

**Live app:** https://pmdsc2020.github.io/gps-slope-survey/

Open the link in Chrome on an Android phone, tap **Start GPS** and allow location access. After the first load the app works offline in the field.

## What it does

- Records a point by averaging GPS readings for 10, 30 or 60 seconds and dropping poor readings
- Stores latitude, longitude, GPS altitude, vertical and horizontal accuracy for each point
- Lets you type an RL from an auto level, Google Earth or a toposheet for any point; the RL is then used instead of GPS height
- Calculates slope three ways: end to end, best-fit line through all points, and along the walked route
- Shows slope in %, degrees and "1 in n", with a ± uncertainty and a Reliable / Fair / Unreliable flag
- Draws the ground profile (elevation vs chainage) and a plan view of the points
- Gives the land slope class (A to G, 0–1% up to above 50%) with typical watershed treatments
- Saves several surveys on the phone; exports CSV and KML (Google Earth) and copies a text summary for WhatsApp

## Accuracy note

Phone GPS height is usually only accurate to about ±3–15 m. On gentle land keep points 100 m or more apart. When the app shows **Unreliable**, enter RLs from an auto level for the points.

## If GPS does not start

- Open the https link above in Chrome, not a file opened from WhatsApp, Drive or a file manager
- Turn Location ON with Google Location Accuracy ON
- Phone Settings → Apps → Chrome → Permissions → Location → Allow (Precise)
- In Chrome, tap the icon left of the address → Permissions → Location → Allow, then reload

## Files

- `index.html` — the GPS Slope Survey field app
- `simple-calculator.html` — earlier calculator where points are typed in as `latitude, longitude, elevation`

---

Developed by Jitendra Sonawane, Agriculture Engineer · 7720045808

# GPS slope survey calculator

Browser tool for calculating slope and elevation change from GPS survey points (latitude, longitude, elevation).

Live page: https://pmdsc2020.github.io/gps-slope-survey/

## What it calculates

- Horizontal distance between consecutive points (haversine formula)
- Elevation rise or fall on each segment
- Slope in percent and degrees
- Cumulative distance along the survey line
- Overall net elevation change and average slope for the whole line

## How to use

Enter one point per line as `latitude, longitude, elevation` (decimal degrees and metres). Comma or space separated.

Example:
```
28.6139, 77.2090, 216.5
28.6145, 77.2102, 218.1
28.6151, 77.2115, 217.4
```

Click **Calculate slopes**. Load the sample data to try it immediately.

## Notes

- Distances are horizontal (planimetric). Elevation is used as provided; keep a consistent vertical datum.
- Consumer GPS vertical accuracy is typically several metres. For grading or irrigation layout, prefer RTK or differential GNSS.
- This is a field-planning estimate. It is not a substitute for a licensed survey.

## Run locally

Open `index.html` in a browser. No build step or dependencies.

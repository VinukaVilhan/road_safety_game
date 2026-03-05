# Road sign images for MCQ test

Standard road sign images used by the Road Signs MCQ test.  
Images are **not** included in the repo for size/licensing clarity. Run the download script to fetch public-domain signs.

## Quick setup

From the project root (`road_safety_game`), run:

```powershell
.\scripts\download_roadsigns.ps1
```

Or from the repo root:

```powershell
cd road_safety_game; .\scripts\download_roadsigns.ps1
```

This downloads standard road signs from Wikimedia Commons (public domain) into this folder.  
If you don't run the script, the app still works: missing images are shown as a placeholder icon.

## Sources

- [Wikimedia Commons – Category: SVG road signs](https://commons.wikimedia.org/wiki/Category:SVG_road_signs)  
- [UK traffic sign images (GOV.UK)](https://www.gov.uk/guidance/traffic-sign-images)  
- [Public Domain Vectors – road signs](https://publicdomainvectors.org/en/free-vector-direction-road-signs)

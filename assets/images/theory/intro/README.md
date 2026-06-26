# Theory intro images (carousel)

Configured paths match `assets/config/theory_curriculum.json`.

## Layout

```
intro/
  best_practices/       (4 slides)
  traffic_rules/        (4 slides)
  parking/              (4 slides)
  vehicle_control/      (4 slides)
  safety_procedures/    (4 slides)
```

## Source mapping (AI batch `image-N.png` → final path)

| Source | Destination |
|--------|-------------|
| image-1.png | best_practices/seatbelt.png |
| image-2.png | best_practices/mirrors.png |
| image-3.png | best_practices/following_distance.png |
| image-4.png | best_practices/stay_alert.png |
| image-5.png | traffic_rules/driving_licence.png |
| image-6.png | traffic_rules/vehicle_documents.png |
| image-7.png | traffic_rules/speed_limits.png |
| image-8.png | traffic_rules/right_of_way.png |
| image-9.png | parking/where_not_to_park.png |
| image-10.png | parking/parallel_angle_parking.png |
| image-11.png | parking/hill_parking.png |
| image-12.png | parking/clearance.png |
| image-13.png | vehicle_control/steering.png |
| image-14.png | vehicle_control/braking.png |
| image-15.png | vehicle_control/gears.png |
| image-16.png | vehicle_control/mirrors_manoeuvres.png |
| image-17.png | safety_procedures/hazard_lights.png |
| image-18.png | safety_procedures/warning_triangle.png |
| image-19.png | safety_procedures/breakdown.png |
| image-20.png | safety_procedures/accidents.png |

Hot restart Flutter after adding or replacing assets.

**Git:** PNG/JPEG/WebP files here are **gitignored** — add locally after clone; do not commit or push to GitHub. Only this README and `theory_curriculum.json` stay in the repo.

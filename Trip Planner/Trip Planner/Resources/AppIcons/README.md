# App Icons

Trip Planner uses Icon Composer `.icon` bundles for the primary app icon and three alternate icons. The Settings screen exposes these names through `AppIconOption`, and `UIApplication.setAlternateIconName(_:)` applies the selected alternate.

## Icon Sets

| Display Name | Icon Bundle | API Name | Preview PNG |
| --- | --- | --- | --- |
| Map Pins | `AppIcon.icon` | `nil` primary icon | `MapPins.png` |
| Compass Spark | `AppIcon-CompassSpark.icon` | `AppIcon-CompassSpark` | `CompassSpark.png` |
| Layered Itinerary | `AppIcon-LayeredItinerary.icon` | `AppIcon-LayeredItinerary` | `LayeredItinerary.png` |
| Route Case | `AppIcon-RouteCase.icon` | `AppIcon-RouteCase` | `RouteCase.png` |

## Configuration

- `Trip-Planner-Info.plist` declares `CFBundleIcons`, `CFBundlePrimaryIcon`, and `CFBundleAlternateIcons`.
- `SettingsView` calls the supported UIKit alternate icon API and handles unsupported devices or system errors with a non-destructive alert.
- The current icon is read from `UIApplication.alternateIconName` on Settings launch so selection remains correct after relaunch.

## Verification

Each uploaded icon source is a 1024 x 1024 PNG in an Icon Composer bundle. The icon set was checked for light, dark, tinted, and accessibility-relevant appearances before adding it to this resource folder.

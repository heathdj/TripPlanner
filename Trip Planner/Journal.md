# Trip Planner Journal

## The Big Picture

Trip Planner is the travel notebook that wants to grow up into a real planning assistant. Right now it is a clean SwiftUI starter app, but the issue list tells the bigger story: trips with flexible dates, itinerary stops, maps directions, reusable interests, generated plans, budgets, diary entries, weather, QR sharing, and eventually a backend for shared trips.

Think of the current app as an empty suitcase on the bed. The suitcase is open, the tags are attached, and the packing list is written. The next work is deciding what goes in first and making sure it fits without wrinkling everything else.

## Architecture Deep Dive

The app currently has three main stations:

- `Trip_PlannerApp` is the front door. iOS launches here, then hands the user to the root SwiftUI view.
- `ContentView` is the current lobby. It still says "Hello, world!", which is useful because it proves the wiring works, but it is not yet the travel-planning experience.
- The test targets are the quality desk. Unit tests use Swift Testing for focused checks, and UI tests use XCUIAutomation for end-to-end app behavior.

As the app grows, the clean shape will likely be:

- Views handle presentation and user interaction.
- Models describe trips, itinerary items, budgets, diary entries, and sharing state.
- Services handle boundaries such as persistence, Apple Maps, Foundation Models, QR import/export, networking, and authentication.

That separation matters because a trip planner can become a junk drawer quickly. If the view starts doing model decisions, networking, persistence, and formatting, every new feature becomes harder than the last. Good architecture keeps each piece doing its own job.

## The Codebase Map

- `Trip Planner/Trip_PlannerApp.swift`: App entry point and root scene.
- `Trip Planner/ContentView.swift`: Current root SwiftUI view.
- `Trip Planner/Assets.xcassets`: App assets and colors.
- `Trip PlannerTests/Trip_PlannerTests.swift`: Swift Testing unit test target.
- `Trip PlannerUITests/Trip_PlannerUITests.swift`: UI automation tests.
- `Trip PlannerUITests/Trip_PlannerUITestsLaunchTests.swift`: Launch/performance UI test coverage.
- `AGENTS.md`: Practical project memory for future Codex sessions.
- `Journal.md`: This learning journal, updated when the project teaches us something.

## Tech Stack & Why

SwiftUI is the right starting point because this app will be state-heavy and view-driven: trip lists, detail screens, editors, budgets, diary timelines, sharing flows, and generated plan review screens all benefit from declarative UI.

Swift Testing is in place for unit tests because it is the modern Apple testing framework and reads cleanly for model and service behavior. It should be especially useful once budget math, itinerary grouping, date-window logic, and import/export behavior arrive.

XCUIAutomation is present for UI tests because travel planning has workflows, not just screens. Creating a trip, editing stops, saving a generated plan, or revoking shared access should eventually be tested the way a user actually moves through the app.

GitHub issues are currently acting as the product roadmap. That is useful: each issue is a visible promise, and implementation can stay focused by closing one promise at a time.

## The Journey

### 2026-07-31: Repository Access Confirmed

We verified that the local checkout points to `https://github.com/heathdj/TripPlanner.git`, which resolves to `heathdj/TripPlanner`.

The connected GitHub app can read the repository and reports admin, maintain, pull, push, and triage permissions. The GitHub CLI can also read the issue backlog.

The issue board currently has `#1` through `#35`. Issue `#9` is closed, and the rest are open. The backlog sketches a clear roadmap from app foundation through sharing backend operations tests.

Lesson learned: before touching code, confirm the map. A local folder, an Xcode project, and a GitHub repo need to agree about what project we are actually working on.

### 2026-07-31: Documentation Baseline Created

This project did not yet have `AGENTS.md` or `Journal.md`, so we created both. That gives future work a memory: what the app is, what conventions matter, where the code lives, and what we have already learned.

The practical benefit is less repetition. The next engineer does not have to rediscover that the module name is `Trip_Planner`, the project path contains spaces, or the app is still at starter-template stage.

### 2026-07-31: The Issue-To-PR Conveyor Belt

We established the working rhythm for future feature work: start by getting the latest from GitHub, branch from `main`, code the issue, test it, then stage, commit, push, and open a pull request.

This is the engineering equivalent of mise en place in a kitchen. Ingredients first, clean station, one dish at a time. The payoff is that every issue gets a traceable branch, every branch gets tested before review, and GitHub stays the source of truth instead of becoming a scrapbook of half-finished ideas.

### 2026-07-31: Issue #1 Builds the Lobby

Issue `#1` turned the starter "Hello, world!" room into the app's first real lobby: a SwiftUI tab foundation with a Trips dashboard, Settings screen, sample trip summaries, and reusable Liquid Glass panels.

The architectural lesson is simple: even a foundation needs real shapes. We added `Models`, `Stores`, `Services`, `Views`, `Components`, and `Resources` before the app became large enough to demand them, but not so much structure that the project feels like a filing cabinet with no papers in it.

Validation had one environment-shaped pothole on the first pass: the test runner could not see a concrete simulator until Xcode's default device was set to iPhone 17 Pro. Once the simulator was available, the full test plan passed. That is a good reminder that test infrastructure is part of the app's plumbing, not just background noise.

### 2026-07-31: Issue #2 Gives Trips a Calendar Spine

Issue `#2` taught the app the difference between "how long am I away?" and "when could this happen?" A trip can now have a 15-day possible window while still being a 4-day trip, which is exactly how real travel planning works when flights, PTO, school calendars, and weather all argue at once.

SwiftData became the pantry for durable trip facts: trips, reviewed plans, and travel defaults now persist locally. The dashboard speaks in three separate ideas: travel window, trip duration, and possible start dates. Settings owns the default trip duration and default window length, so future trip creation has sensible starting points instead of magic numbers hiding in a view.

The main engineering lesson: date math should be boring on purpose. Normalize to start-of-day, clamp invalid values, count inclusively, and test the edge cases. Calendars are where off-by-one bugs like to rent apartments.

### 2026-07-31: Issue #36 Lets the App Change Clothes

Issue `#36` gave Trip Planner a small wardrobe of app icons. The default Map Pins icon now sits beside Compass Spark, Layered Itinerary, and Route Case, and Settings can ask iOS to switch between them using the supported alternate-icon API.

The important pattern is that Settings does not pretend icon changes are guaranteed. Some devices do not support alternate icons, and iOS can reject a change, so the UI reports failures without damaging the current selection. Personalization should feel optional and reversible, not like a trapdoor.

Bug follow-up: the first Settings preview tried to load the raw icon layer filenames directly. Those files live inside Icon Composer bundles, so they are not ordinary named images at runtime. The fix was to mirror the same artwork into dedicated preview image sets in `Assets.xcassets`, keeping the real `.icon` bundles for iOS and giving SwiftUI a dependable image catalog lookup.

### 2026-08-05: Issue #3 Sorts the Suitcases by Distance

Issue `#3` gave the dashboard a traveler's sense of "near me" without making location a toll booth. Trips now have optional coordinates, Settings owns the user's preferred unit and Near You radius, and the dashboard only asks for location after the user taps the button.

The important architectural trick is that location is seasoning, not the meal. Without permission, Open Trips and Closed Trips still render normally. With permission, nearby open trips are promoted into their own section and removed from Open Trips so the same trip does not show up wearing two name tags.

Core Location also reminded us to keep privacy workflows explicit. A denied or restricted status is not an error avalanche; it is a state the UI can explain, with a clear path to system Settings when the user wants to change their mind.

### 2026-08-05: Issue #4 Turns the Dashboard Into a Control Tower

Issue `#4` changed the dashboard from a list of pretty cards into a real scanning surface. Cards now carry the facts a traveler reaches for first: destination, travel window, trip duration, travelers, progress, and nearby distance when location has promoted the trip.

The detail sheet is the airport gate display for a single trip. It uses the same `Trip` model data, then adds a hero, facts, saved plan summary, and itinerary items. The saved plan section queries SwiftData directly, which matters because details should update when a reviewed plan is saved instead of showing yesterday's boarding pass.

The lesson here is that "polished" is not just color and blur. Polish is hierarchy: the list answers "what needs my attention?", and the sheet answers "what is inside this trip?" without making the user decode a pile of equal-weight labels.

### 2026-08-05: Issue #5 Gives Each Stop Its Own Compass

Issue `#5` turned itinerary lines from plain text into real trip stops. Each item now knows its name, notes or address, category, day number, and optional coordinates. That lets the detail sheet treat a hotel, taco stop, hike, and ferry ride differently without inventing four separate mini-models.

The Maps behavior follows a practical rule: if we have coordinates, route to the pin; if we only have generated text, build a destination search that includes the trip location. Missing coordinates are not a failure case. They are just a fuzzier kind of destination, so the UI still offers directions instead of making the user copy text by hand.

### 2026-08-05: Issue #6 Lets Preferences Have a Memory

Issue `#6` gave travelers a reusable activity palette. Suggested interests cover the common travel moods, and custom interests catch the personal details: pottery, gardens, jazz clubs, or whatever else makes a trip feel like theirs.

The design choice is privacy-first persistence. Interests live in `TravelSettings`, stay local across launches, and are only meant to leave the device when the traveler explicitly asks for plan generation. The model gets better context, but the app does not quietly turn preferences into background chatter.

### 2026-08-07: Issue #7 Brings in the On-Device Travel Brain

Issue `#7` added the app's first Foundation Models workflow. Trip details, flexible window, duration, traveler count, theme, and selected interests now feed an on-device `LanguageModelSession`, which returns a typed `@Generable` draft instead of loose text soup.

The important boundary is the sanitizer. The model can suggest, but the app still checks the passport: generated days are clamped to the trip duration, categories map into the app's supported itinerary types, blank text gets safe fallback copy, and the result stays a draft. Nothing is saved automatically, because AI output should go through customs before entering the real itinerary.

Small war story: Apple's docs show `GenerationID` inside a nested generated item example, but this SDK's macro expansion rejected it because `GenerationID` did not conform to the generated-content protocols. We removed it and let Trip Planner create UUID-backed `ItineraryItem` values after sanitization, which is cleaner for our model anyway.

Follow-up bug: the generated draft feature depended on an existing trip, but the dashboard `+` button was still an empty action. That meant the front door to the feature looked real but opened into a wall. The fix was to add a small New Trip sheet, save the seed trip first, then open Trip Details and start the on-device draft flow there. The generated itinerary still stays unsaved until a later review/save feature exists.

Second follow-up: Settings needed a sturdier memory. SwiftData persisted the settings row, but array-style interest updates are easy to make in a way that looks changed on screen while not giving the persistence layer a clean reassignment to save. We moved interest edits to explicit array replacement, added a tiny `TravelSettingsStore` for the one-settings-row rule, and made Dashboard load that row before New Trip uses defaults. Destination entry also learned to ask MapKit for location completions, so travelers can pick real cities, regions, and countries instead of typing everything from scratch.

Third follow-up: the settings row still made the UI too fragile. If SwiftData did not hand Settings a row at exactly the right moment, Trip Defaults and Activity Interests became blank restaurant menus: nice section titles, no food. The fix was to move user preferences to `@AppStorage`, storing simple values directly in `UserDefaults` and JSON-encoding the interest arrays. SwiftData remains the suitcase for real trip records and reviewed plans; AppStorage is the jacket pocket for small personal preferences the UI must always be able to read instantly.

### 2026-08-07: Issue #8 Puts AI Output at the Editing Desk

Issue `#8` added the guardrail that generated plans needed from the start: the model can draft, but the traveler gets the final say. Generation now opens a review sheet where the title, overview, item names, notes, categories, and day assignments can all be changed before anything touches the real trip.

The persistence rule is intentionally strict. Saving a reviewed plan replaces the previous reviewed plan for that trip, sorts named items by day, drops blank items, updates the trip itinerary, and keeps items compatible with Apple Maps. Cancel is just closing the notebook without tearing out any pages: the existing trip stays untouched.

The engineering lesson is that AI workflows need a customs checkpoint. Generated data is useful cargo, but it should be inspected, edited, and stamped by the user before it becomes app state.

Follow-up bug: editable rows inside `Form` need careful button behavior. The first review sheet put a trash button in a row that also had form controls, and taps could be stolen by the row's picker-style interaction. The fix was to make row actions explicit borderless icon buttons, add native swipe-to-delete, and make manual additions pass through a green checkmark before they become real plan items. We also taught generated and saved plans to keep only one departure event, because a trip only needs one "time to go home" moment.

Second follow-up: a newly generated trip needs a clear finish line. The detail sheet now treats the auto-generation path like a provisional workspace: Cancel can discard it before review is saved, and Save only lights up after the reviewed plan has been saved. That makes the lifecycle visible instead of hiding the important decision behind a generic Done button.

Third follow-up: presentation state should travel with the thing being presented. Dashboard originally carried the selected trip and "start generated flow" as separate state values, which let the detail sheet open in normal Done mode when SwiftUI evaluated the sheet at the wrong moment. We wrapped the trip and its presentation mode together so a new generated trip cannot forget that it is provisional.

Fourth follow-up: a button named Save should save, not merely close the curtain. The generated trip detail sheet now performs an explicit final context save and tells Dashboard the provisional trip is confirmed, which makes the new open trip visible after dismissal instead of relying on earlier intermediate saves.

Fifth follow-up: Dashboard needed to confirm the saved trip by identity, not by trusting the sheet's model reference. The save callback now fetches the trip by UUID, updates the persisted instance, and clears the presented sheet state. That gives the `@Query` driving Open Trips the best chance to see the exact saved row.

Sixth follow-up: the cleanest generated-trip lifecycle is "draft in memory, insert on final Save." Creating a trip before review made every later button responsible for preserving a provisional database row. Now the new trip stays in memory until the user presses the top-level Save, which inserts it once with the reviewed itinerary. Cancel cleans up any reviewed-plan draft rows so abandoned generated trips do not leave orphaned data behind.

Seventh follow-up: the simulator finally told the truth with a Core Data migration error. `TravelSettings` had gained mandatory array attributes after earlier builds already created stores without those columns. SwiftData could not invent values during lightweight migration, so the whole container failed to load and no trips could persist. The active settings UI already uses AppStorage, so the fix was to make those legacy SwiftData arrays optional and normalize nil to empty arrays in code.

Eighth follow-up: Swift 6's default main-actor isolation is a strict maître d'. It noticed two places where UI-bound work and pure value conversion were standing in the wrong line. Apple Maps launching now declares its main-actor boundary directly, and the editable itinerary conversion helpers are explicitly nonisolated because they only copy value data.

### 2026-08-08: Issue #45 Lets Travelers Add Real Places, Not Just Text

Issue `#45` moves manual itinerary editing from "type whatever you remember" toward "pick the real place, then tweak it." Each editable itinerary item now has a MapKit-powered place finder scoped by the trip destination and, when permission exists, the traveler's current location. Selecting a result fills the name, address, coordinates, phone number, and MapKit place identifier, but the fields stay editable because travel planning always has exceptions.

The architecture lesson is to save facts, not framework objects. `MKMapItem` is useful while searching, but the app stores small durable values on `ItineraryItem`: coordinates for directions, a formatted address for humans, and optional metadata for richer future features. That keeps SwiftData persistence boring, which is exactly what persistence should be.

Follow-up bug: MapKit's region can be a polite suggestion instead of a locked door. Activity search originally biased results near the traveler, but it could still offer places on another continent. The fix was to use the same Near You radius from Settings, make MapKit's region priority required, and filter resolved map items by actual distance from the current location when available.

### 2026-08-08: Issue #46 Teaches Activities to Remember Place Facts

Issue `#46` added a place-details notebook to each itinerary item. Apple Maps can provide trustworthy facts like phone numbers, websites, categories, time zones, and attribution; travelers can provide the squishier bits like hours notes and cost guidance when the provider has nothing useful to say.

The key rule is source tags. Provider values and manual values wear different badges, and refreshes are polite: they update provider-sourced data but do not stomp on a user's correction. That turns refresh into a helpful clerk, not a paper shredder.

Follow-up: generated plans now visit the place-details desk before the traveler reviews them. The model still drafts the ideas, but MapKit gets a chance to attach real provider facts first. If a generated stop cannot be resolved, it stays editable instead of blocking the sheet.

### 2026-08-08: Issue #49 Gives Trips a Real Lifecycle

Issue `#49` replaced the old open/closed light switch with a travel-sized state machine: open ideas, planned trips with exact dates, active trips that are happening now, and closed trips that remember whether they completed or were cancelled.

The trick was keeping flexibility and commitment separate. The flexible window is still the planning sandbox, while an exact start date is an optional stake in the ground. The lifecycle service is the gate agent: it checks that a trip fits inside the window, moves planned trips back to open when the exact date is cleared, and requires explicit actions before anything becomes active or closed.

Migration stayed boring on purpose. New SwiftData fields are optional so existing stores do not need Core Data to invent mandatory values. Old closed trips normalize to `completed`, and open trips with an exact date normalize to `planned`. It is not glamorous, but after the previous migration scar tissue, boring persistence is the victory lap.

Follow-up bug: saved itinerary cards had plenty of useful action buttons, but the card itself was a locked display case. Tapping an existing item now opens the same style of editable form used during plan review, then writes the edited item back into the trip by stable UUID. The lesson is simple: once users can save generated details, the saved version needs the same editing door.

Second follow-up bug: "plan progress" was too vague because it counted a stored number instead of what the traveler could actually see. Progress now treats itinerary items with exact map coordinates as planned, and unresolved search-style items as not yet planned. Four stops with three exact places reads as `3 of 4 planned`, which makes the progress bar a map-detail meter instead of a mystery gauge.

## Engineer's Wisdom

Start with the smallest honest architecture. The app does not need a maze of folders before it has real behavior, but it does need clear boundaries once features arrive.

Let tests follow risk. Budget calculations and date grouping deserve unit tests. QR sharing, save workflows, and collaboration permissions deserve UI or integration-style coverage.

Treat generated plans as drafts, not truth. If Foundation Models create itinerary suggestions later, the app should make review and editing first-class, because travel plans are personal and mistakes are expensive.

Respect framework freshness. Liquid Glass and FoundationModels are new enough that memory is a shaky source. Use current Apple documentation before implementing those APIs.

## If I Were Starting Over...

I would still start with SwiftUI, Swift Testing, and a clean issue backlog. The one thing I would add early is a thin domain model layer before the UI gets busy. Even a modest `Trip` model and a small persistence boundary can keep the first real screens from turning into a pile of temporary state.

I would also make the first feature boring on purpose: model and save a trip. Once that works, everything else has a place to attach: itinerary items, budgets, diary entries, generated plans, and sharing.

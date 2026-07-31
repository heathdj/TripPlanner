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

## Engineer's Wisdom

Start with the smallest honest architecture. The app does not need a maze of folders before it has real behavior, but it does need clear boundaries once features arrive.

Let tests follow risk. Budget calculations and date grouping deserve unit tests. QR sharing, save workflows, and collaboration permissions deserve UI or integration-style coverage.

Treat generated plans as drafts, not truth. If Foundation Models create itinerary suggestions later, the app should make review and editing first-class, because travel plans are personal and mistakes are expensive.

Respect framework freshness. Liquid Glass and FoundationModels are new enough that memory is a shaky source. Use current Apple documentation before implementing those APIs.

## If I Were Starting Over...

I would still start with SwiftUI, Swift Testing, and a clean issue backlog. The one thing I would add early is a thin domain model layer before the UI gets busy. Even a modest `Trip` model and a small persistence boundary can keep the first real screens from turning into a pile of temporary state.

I would also make the first feature boring on purpose: model and save a trip. Once that works, everything else has a place to attach: itinerary items, budgets, diary entries, generated plans, and sharing.

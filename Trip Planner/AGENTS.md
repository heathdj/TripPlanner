# Trip Planner Project Notes

## Project Overview

Trip Planner is an iOS SwiftUI app for planning, organizing, and eventually sharing travel plans. The current codebase is a fresh app foundation, and the GitHub issue backlog lays out the intended product direction: trip persistence, itinerary items, Apple Maps directions, activity interests, on-device trip generation, budgets, diary entries, QR-based sharing, and a server-backed collaboration layer.

## Architecture Decisions

- The app starts with a simple SwiftUI entry point in `Trip Planner/Trip_PlannerApp.swift`.
- `ContentView` is currently the root view and still contains the starter placeholder UI.
- Unit tests use the Swift Testing framework in `Trip PlannerTests`.
- UI tests use XCTest/XCUIAutomation in `Trip PlannerUITests`.
- Future model and persistence work should prefer SwiftData where appropriate, with clear dependency injection around services that touch persistence, network, maps, or Foundation Models.
- Prefer Swift Concurrency with `async` and `await` over callback-based APIs.

## Conventions

- Use PascalCase for Swift types and camelCase for properties and methods.
- Use `@State private var` for local SwiftUI state.
- Keep SwiftUI views small enough to read, and extract focused subviews when a body becomes hard to scan.
- Avoid force unwrapping. Model uncertain data explicitly with optionals or throwing/async APIs.
- Keep comments for non-obvious logic, not for restating Swift syntax.
- Limit changes to the requested task.

## Build And Run

- Open the project in Xcode from this folder.
- Build with the active Xcode scheme, or use the Xcode MCP `BuildProject` tool when working through Codex.
- Run unit tests from the `Trip PlannerTests` target.
- Run UI tests from the `Trip PlannerUITests` target.

## GitHub

- Remote: `https://github.com/heathdj/TripPlanner.git`
- Repository: `heathdj/TripPlanner`
- Default branch: `main`
- The connected GitHub app reports admin, maintain, pull, push, and triage permissions for this repository.
- Current issue backlog is available through GitHub. As of 2026-07-31, issues `#1` through `#35` exist, with `#9` closed and the rest open.

## Quirks And Gotchas

- The project path contains spaces: `Trip Planner/Trip Planner`. Quote paths in shell commands.
- The Swift module name uses an underscore: `Trip_Planner`.
- The app is still at starter-template stage, so most product behavior described in issues has not yet been implemented.
- Before implementing newer Apple APIs such as Liquid Glass or FoundationModels, search current Apple Developer Documentation from Xcode tools.

# Trip Planner V1.0: On-Device Testing and App Store Connect Submission

This document is the release plan for validating Trip Planner V1.0 on physical Apple devices, distributing prerelease builds through TestFlight, and submitting the app to Apple through App Store Connect.

It is a checklist, not a substitute for the current [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) or the agreements associated with the Apple Developer Program. Recheck the linked Apple documentation before every submission because requirements can change.

## Current application configuration

Verify these values in Xcode and App Store Connect before creating an archive:

| Setting | Expected V1.0 value |
| --- | --- |
| Product name | Trip Planner |
| App Store platform | iOS, including iPad support |
| Bundle identifier | `com.bald-traveler.Trip-Planner` |
| Marketing version | `1.0` |
| Build number | Start at `1`; increment for every uploaded replacement build |
| Minimum system version | iOS/iPadOS 26.0 |
| Development team | `C5HQ3DJJGW` |
| App category | Travel |
| Supported families | iPhone and iPad |
| Location authorization | When In Use |
| Primary app icon | `AppIcon` |
| Alternate app icons | Compass Spark, Layered Itinerary, and Route Case |

The App Store Connect record must use the same bundle identifier as the archive. Apple associates an uploaded build with an app record by its bundle identifier, marketing version, and build number.

## Release roles

Assign each release responsibility before testing begins. One person may fill several roles.

| Role | Responsibility |
| --- | --- |
| Release owner | Freezes the candidate commit, version, and build number |
| QA owner | Runs this test plan and records evidence |
| App Store Connect owner | Maintains metadata, privacy declarations, TestFlight groups, and the submission |
| App Review contact | Responds to Apple and has a working email address and phone number |

App Store Connect permissions vary by operation. Creating an app record and submitting for review generally requires the Account Holder, Admin, or App Manager role. Developers can upload builds, and several roles can manage TestFlight. See Apple's role requirements on the linked App Store Connect Help pages.

## Part 1: Prepare the release candidate

### 1. Freeze and identify the candidate

- [ ] Reconcile the local checkout with the latest GitHub `main` without discarding uncommitted work.
- [ ] Confirm there are no unintended modified or untracked files in the release checkout.
- [ ] Record the exact Git commit SHA.
- [ ] Confirm the V1.0 milestone has no unresolved release-blocking issues.
- [ ] Confirm there are no unreviewed pull requests intended for V1.0.
- [ ] Record the Xcode version, macOS version, and installed iOS simulator runtime.
- [ ] Confirm the marketing version is `1.0`.
- [ ] Assign a build number that has never been uploaded for version 1.0.

Release record:

| Field | Value |
| --- | --- |
| Commit SHA | |
| Marketing version | 1.0 |
| Build number | |
| Xcode version | |
| QA owner | |
| Test start date | |
| Final result | Not started / Passed / Failed |

### 2. Run automated preflight checks

Run from the repository root. Keep the `.xcresult` bundle when a test fails.

```sh
xcodebuild \
  -project "Trip Planner/Trip Planner.xcodeproj" \
  -scheme "Trip Planner" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -resultBundlePath /tmp/TripPlanner-V1-tests.xcresult \
  test
```

```sh
xcodebuild \
  -project "Trip Planner/Trip Planner.xcodeproj" \
  -scheme "Trip Planner" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```sh
xcodebuild \
  -project "Trip Planner/Trip Planner.xcodeproj" \
  -scheme "Trip Planner" \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  analyze
```

- [ ] Unit tests pass with no unexpected skips.
- [ ] UI tests pass on the current iPhone simulator runtime.
- [ ] Empty-database UI test passes on an iPad simulator.
- [ ] Release arm64 build passes.
- [ ] Xcode static analysis passes.
- [ ] Build output contains no new warnings that affect runtime behavior or App Store submission.

If the named simulator is unavailable, use `xcrun simctl list devices available` and substitute an available iOS 26 simulator or its device identifier.

### 3. Inspect the packaged application

- [ ] `CFBundleIdentifier` is `com.bald-traveler.Trip-Planner`.
- [ ] `CFBundleShortVersionString` and `CFBundleVersion` match the release record.
- [ ] `MinimumOSVersion` is the intended V1.0 minimum.
- [ ] `NSLocationWhenInUseUsageDescription` is present and accurately explains location use.
- [ ] No unrelated privacy usage-description keys are present.
- [ ] Primary and alternate icon definitions are present.
- [ ] The binary contains an arm64 device slice.
- [ ] Code signing uses the intended development or distribution team.
- [ ] The app bundle satisfies its designated code-signing requirement.
- [ ] Archive validation reports no missing icon, metadata, privacy-manifest, or entitlement errors.

Audit the app and every included SDK for required-reason API usage. If required-reason APIs are used, include a valid `PrivacyInfo.xcprivacy` with approved reasons. Apple rejects uploads that omit required reasons or contain invalid privacy-manifest values. See [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) and [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## Part 2: Physical-device test plan

### Required devices and states

At minimum, use:

- One Apple Intelligence-eligible iPhone running the minimum supported major system version or later.
- One iPhone on which Apple Intelligence is disabled or the model is not ready.
- One iPad because the app declares iPad support.
- A device with precise location enabled and a device with location denied.
- A device or test pass using poor or unavailable network connectivity.

Where hardware is limited, reuse a device by resetting app data and changing system permissions between passes. Record the exact device model and OS version for every run.

| Device | OS | Apple Intelligence state | Location state | Network state | Result |
| --- | --- | --- | --- | --- | --- |
| | | Enabled and ready | Precise allowed | Wi-Fi/cellular | |
| | | Disabled | Denied | Wi-Fi/cellular | |
| | | Model not ready, if reproducible | Allowed | Offline/poor | |
| iPad | | As available | Allowed or denied | Wi-Fi | |

### Installation and first launch

- [ ] Delete prior test builds for the clean-install pass.
- [ ] Install the signed candidate from Xcode or TestFlight.
- [ ] The app launches without a crash or persistent-store error.
- [ ] A clean installation creates no sample trips or sample reviewed plan.
- [ ] The dashboard displays the `No Trips Yet` content-unavailable view.
- [ ] The empty-state Add Trip button opens the new-trip flow.
- [ ] Settings are available on first launch.
- [ ] Force-quit and relaunch; the empty repository remains valid.

### Create and edit a trip

- [ ] Create a trip with a flexible date range and duration.
- [ ] Validation prevents an invalid or inverted date range.
- [ ] The trip appears under Open Trips.
- [ ] Edit the title, destination, dates, traveler count, duration, theme, and notes.
- [ ] Set an exact start date within the flexible window.
- [ ] The trip moves from Open Trips to Planned Trips and receives the correct calculated end date.
- [ ] Clear the exact start date and confirm it returns to Open Trips.
- [ ] Confirm data remains after force-quit, relaunch, and device restart.

### Location and activation behavior

Run each authorization path from a fresh permission state where practical.

- [ ] The permission prompt uses the expected location explanation.
- [ ] Allow While Using App produces a current location and Near You grouping.
- [ ] Denying location does not block non-location trip planning.
- [ ] The dashboard offers a useful route to Settings after denial.
- [ ] Reduced accuracy does not crash or misclassify all trips.
- [ ] A trip inside the configured radius is promoted to Near You.
- [ ] A trip outside the radius remains in its normal lifecycle group.
- [ ] Date-based activation prompts respect the default two-day lead time.
- [ ] Proximity-based activation prompts respect the configured Near You distance.
- [ ] Prompt dismissal, cooldown, and Don't Ask Again behavior persist after relaunch.
- [ ] Activating a trip moves it to Active Trips.
- [ ] One active trip opens automatically at launch with a path back to the dashboard.
- [ ] Multiple active trips show the chooser once and allow dashboard access.

### On-device Foundation Models

These checks must run on eligible physical hardware; simulator-only success is insufficient.

- [ ] With Apple Intelligence enabled and the model ready, the generation status is available.
- [ ] Generate a plan using several saved interests.
- [ ] Generation happens without sending private planning input to an app-owned backend.
- [ ] The generated draft covers the requested number of days.
- [ ] Generic placeholders such as `Visit a Museum` are excluded.
- [ ] Named places such as `Visit the Louvre Museum` are retained.
- [ ] A specific named restaurant is suggested when the model can provide a trustworthy candidate.
- [ ] Generic arrival and departure entries appear only at valid trip boundaries.
- [ ] Unsupported live claims such as invented hours, prices, reservations, or weather are not saved as facts.
- [ ] Unresolved place matches are clearly marked for review.
- [ ] The user can edit, reorder, add, and delete itinerary items before saving.
- [ ] The generated plan is not persisted until the user confirms the reviewed draft.
- [ ] Cancelling review leaves the prior saved plan unchanged.
- [ ] Saving the reviewed plan persists it after relaunch.

Repeat the generation entry point for these unavailable states:

- [ ] Device not eligible.
- [ ] Apple Intelligence disabled.
- [ ] Model assets not ready.
- [ ] Unsupported language or locale, if reproducible.
- [ ] Generation failure or cancellation.

Each unavailable state must show actionable copy and leave the rest of the app usable.

### Activities, MapKit, and directions

- [ ] Add a custom activity using nearby place suggestions.
- [ ] Selecting a suggestion fills the correct name and address.
- [ ] Search results remain relevant to the trip destination or current location as appropriate.
- [ ] Refresh place details and verify available hours, website, phone number, address, and other MapKit-supplied data.
- [ ] Manual overrides survive a later metadata refresh.
- [ ] Missing provider fields display gracefully rather than as fabricated values.
- [ ] Open a website and telephone link where available.
- [ ] Open directions for an item with coordinates.
- [ ] Verify the Maps destination and driving route are correct.
- [ ] Verify the fallback Maps search for an item without coordinates.
- [ ] Denied location and offline MapKit failures produce useful recovery behavior.

Do not treat MapKit availability, hours, prices, or contact information as guaranteed. Validate that the interface presents provider metadata as current external information and handles missing or stale values.

### Trip lifecycle and completion

- [ ] Mark an active itinerary item Done and confirm completion progress increases.
- [ ] Mark another item Skipped and verify it does not count as completed.
- [ ] Undo an item state and confirm progress recalculates.
- [ ] Complete an active trip and confirm it moves to Closed Trips with progress preserved.
- [ ] Cancel an open, planned, or active trip and confirm it moves to Closed Trips.
- [ ] Confirm completion and cancellation require explicit confirmation.
- [ ] Closed trips remain readable and persist after relaunch.

### Alternate app icons

- [ ] Switch from the primary icon to each alternate icon.
- [ ] Confirm the home-screen icon changes to the selected artwork.
- [ ] Relaunch and verify the selected state matches the system icon.
- [ ] Return to the primary icon.
- [ ] Repeat on iPad because iPad icon packaging can differ from iPhone.
- [ ] Verify light, dark, tinted, and accessibility appearance modes where supported.

### Accessibility and interface quality

- [ ] Test core flows with VoiceOver.
- [ ] Buttons and itinerary items have meaningful labels and hints.
- [ ] Progress exposes an understandable accessibility value.
- [ ] Test all Dynamic Type sizes, including accessibility sizes.
- [ ] Important controls do not clip or become unreachable.
- [ ] Test portrait and landscape on iPhone and iPad.
- [ ] Test light mode, dark mode, Increased Contrast, Reduce Transparency, and Reduce Motion.
- [ ] Liquid Glass surfaces preserve readable contrast over the map background.
- [ ] Empty and error states remain understandable without relying only on color.

### Upgrade and data safety

Use a previously distributed development or TestFlight build containing realistic trips.

- [ ] Install the candidate over the older build without deleting it.
- [ ] SwiftData opens without a migration crash.
- [ ] Existing trips, plans, interests, settings, lifecycle states, and completion states remain intact.
- [ ] Existing user data is not replaced by sample data.
- [ ] Create and edit data after upgrade, then relaunch and confirm persistence.
- [ ] If a migration fails, stop release and preserve the original store for diagnosis.

### Reliability passes

- [ ] Cold launch the app at least ten times.
- [ ] Background and foreground during generation, location lookup, and place refresh.
- [ ] Force-quit during an unsaved edit and verify the documented save behavior.
- [ ] Test low-power mode and limited network connectivity.
- [ ] Confirm there are no repeatable crashes, hangs, data loss, or unbounded loading indicators.
- [ ] Review Xcode Organizer and TestFlight crash and hang reports before submission.

## Part 3: TestFlight plan

TestFlight should be the final prerelease gate. Apple currently allows up to 100 internal App Store Connect testers and up to 10,000 external testers; builds are testable for 90 days. External testing can require TestFlight App Review. See [TestFlight Overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) and [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).

### Internal group

- [ ] Create a `Trip Planner V1 Internal` group.
- [ ] Provide a beta description, feedback email, and focused What to Test instructions.
- [ ] Add the processed candidate build.
- [ ] Add developers and trusted internal testers.
- [ ] Require at least one clean-install and one upgrade pass.
- [ ] Review sessions, crashes, screenshots, and written feedback.

Suggested What to Test text:

> Create a trip from the empty dashboard, set flexible and exact dates, generate and edit an on-device itinerary, add a MapKit activity, open directions, activate the trip, mark an item done, and switch app icons. Please report your device model, OS version, Apple Intelligence state, location permission, reproduction steps, and whether this was a clean install or upgrade.

### External group

- [ ] Resolve internal blockers before external distribution.
- [ ] Create a `Trip Planner V1 External` group.
- [ ] Provide complete Beta App Review information.
- [ ] Explain that itinerary generation requires eligible hardware with Apple Intelligence enabled and ready.
- [ ] Submit the first external build for Beta App Review.
- [ ] Invite a small cohort before enabling a broader public link.
- [ ] Monitor crash rate and qualitative feedback for an agreed soak period.
- [ ] Freeze the App Store candidate only after the external exit criteria pass.

### TestFlight exit criteria

- No known crash, data-loss, privacy, security, signing, or launch blocker.
- No unresolved high-severity accessibility failure in a core flow.
- Generation succeeds on eligible test hardware and fails gracefully elsewhere.
- Location denial and network failure do not make the app unusable.
- Clean install, upgrade, iPhone, and iPad passes are recorded.
- App Store metadata and screenshots match the tested build.

## Part 4: App Store Connect preparation

### 1. Account and agreements

- [ ] Apple Developer Program membership is active.
- [ ] The Account Holder has accepted the latest agreements in App Store Connect Business.
- [ ] Tax and banking information is complete if the app or future in-app content will be paid.
- [ ] App Store Connect users have the minimum necessary roles.
- [ ] Digital Services Act trader status and any required contact verification are complete for intended regions.

Apple will not allow a new app record until the Account Holder signs the latest agreement. See [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

### 2. Create or verify the app record

In App Store Connect, select **Apps**, choose **+**, and select **New App**.

- [ ] Platform: iOS.
- [ ] Name: final customer-facing name, no more than Apple's current limit.
- [ ] Primary language: chosen and reviewed.
- [ ] Bundle ID: `com.bald-traveler.Trip-Planner`.
- [ ] SKU: stable internal identifier, for example `trip-planner-ios`.
- [ ] User access: Full Access or deliberately restricted.
- [ ] Primary category: Travel.
- [ ] Secondary category: optional and accurate.
- [ ] Content rights declaration is accurate for MapKit and any other third-party content shown by the app.

The bundle ID and SKU cannot be casually changed after setup, and the bundle ID must match Xcode. See [App information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information).

### 3. Product-page metadata

Prepare and proofread:

- [ ] App name.
- [ ] Subtitle.
- [ ] Description that accurately describes current V1.0 behavior.
- [ ] Keywords without competitor names or misleading claims.
- [ ] Support URL with working contact information.
- [ ] Marketing URL, if used.
- [ ] Privacy policy URL.
- [ ] Copyright holder and year.
- [ ] Promotional text, if used.
- [ ] Version number `1.0`.
- [ ] App Store release option.

Avoid saying that live place details, hours, prices, or generated plans are guaranteed accurate. Explain that users review generated itineraries before saving and should verify live travel information.

Apple requires functional support and privacy-policy links. Placeholder text, empty sites, and temporary metadata should be removed before review. Review Apple's [required app properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/) and [App Review guidance](https://developer.apple.com/app-store/review/).

### 4. Screenshots and previews

Because Trip Planner supports iPhone and iPad, prepare accurate screenshots for both device families using the sizes App Store Connect requests for the selected platforms.

Recommended screenshot story:

1. Dashboard with Active, Near You, Planned, Open, and Closed organization.
2. Flexible date range and duration planning.
3. On-device itinerary generation with interests.
4. Review and edit generated itinerary before save.
5. MapKit place details and Apple Maps directions.
6. Active-trip completion progress.
7. Alternate app icon selection, if space permits.

- [ ] Screenshots come from the submitted build or faithfully represent it.
- [ ] No sample personal data, private addresses, or tester names are visible.
- [ ] Status bars and device framing are consistent.
- [ ] Text is readable at App Store thumbnail sizes.
- [ ] Localized screenshots match localized metadata, if localization is offered.
- [ ] Any app preview video follows Apple's duration, format, and content rules.

Use [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots) to confirm the current required sizes and limits.

### 5. App privacy and privacy policy

The privacy answers must describe the submitted binary, Apple frameworks, included SDKs, and app-owned services—not planned future features.

- [ ] Publish a working privacy policy URL even if no data is collected by the developer.
- [ ] Inventory every data type leaving the device.
- [ ] Determine whether any data is linked to identity or used for tracking.
- [ ] Include the practices of third-party SDKs and services.
- [ ] Confirm location use matches the system prompt and product behavior.
- [ ] Confirm on-device Foundation Models input is not sent to an app-owned server.
- [ ] Confirm SwiftData trip content remains local for this V1.0 build.
- [ ] Update the answers when CloudKit, trip sharing, analytics, authentication, or a Vapor backend is introduced.
- [ ] Confirm any `PrivacyInfo.xcprivacy` file matches the App Store Connect answers.

If the submitted V1.0 binary truly has no developer or third-party data collection under Apple's definitions, App Store Connect provides a **No, we do not collect data from this app** path. Do not choose it solely because storage is local; verify MapKit usage, linked frameworks, diagnostics, and the exact binary first. See [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).

### 6. Age rating and availability

- [ ] Complete the current age-rating questionnaire truthfully.
- [ ] Do not select Made for Kids unless the product and every future update will meet Kids category requirements.
- [ ] Review country-specific rating results.
- [ ] Select intended countries and regions.
- [ ] Set price to Free unless a different business model is approved.
- [ ] Complete any region-specific declarations App Store Connect presents.

An unrated app cannot be published on the App Store. See [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating).

### 7. Export compliance

App Store Connect asks whether the app uses or contains encryption. Do not guess or copy an answer from another app.

- [ ] Inventory app code and SDKs for encryption functionality.
- [ ] Answer App Store Connect's export-compliance questionnaire for the actual build.
- [ ] Determine whether only exempt operating-system encryption is used.
- [ ] Upload required documentation if App Store Connect determines it is necessary.
- [ ] Only add the corresponding Info.plist export-compliance key after the determination is documented.
- [ ] Revisit this decision when networking, authentication, CloudKit, or backend sharing is added.

Apple explains the decision process in [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance). This checklist is not legal advice.

### 8. App Review information

Provide a monitored contact name, email address, and phone number. No login should be required for the current local-only V1.0 build; if that changes, provide a non-expiring demo account.

Suggested review notes, edited to match the final binary:

> Trip Planner is a local-first travel planning app for iOS and iPadOS 26. Location access is optional and is used to show nearby trips, suggest nearby activities, and improve map-based planning. The app remains usable when location is denied. It uses Apple's on-device Foundation Models to draft itineraries. Generation is available only on Apple Intelligence-eligible hardware when Apple Intelligence is enabled, the model is ready, and the language is supported. Reviewers can still create and edit trips manually when generation is unavailable. Generated plans must be reviewed and explicitly saved. Live place details and directions are supplied through MapKit and Apple Maps. No account is required for V1.0.

Suggested review path:

1. Launch to the empty dashboard and select Add Trip.
2. Create a trip with a date window and duration.
3. Open the trip and, on eligible hardware, generate an itinerary.
4. Edit the draft and save it.
5. Add an activity using place search and open directions.
6. Set an exact date, activate the trip, and mark an item Done.
7. Open Settings to switch the app icon.

- [ ] Notes explain Apple Intelligence hardware and settings requirements.
- [ ] Notes explain that location permission is optional.
- [ ] Notes provide a manual path when generation is unavailable.
- [ ] Contact information is current throughout review.
- [ ] Any required special configuration or test account is supplied.

Apple specifically asks developers to include special settings, hardware requirements, and testing instructions in App Review Information. See [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

## Part 5: Archive, upload, and TestFlight processing

### Create the archive in Xcode

1. Open `Trip Planner/Trip Planner.xcodeproj`.
2. Select the `Trip Planner` scheme.
3. Select **Any iOS Device (arm64)** or a generic iOS device destination.
4. Confirm the Release configuration, bundle ID, team, version, and unique build number.
5. Choose **Product > Archive**.
6. In Organizer, select the new archive.
7. Choose **Validate App** and resolve every error; review every warning.
8. Choose **Distribute App > App Store Connect > Upload**.
9. Keep automatic signing enabled unless the release owner intentionally manages distribution profiles manually.
10. Record the archive creation date and uploaded build number.

### Wait for processing

- [ ] Upload completes successfully.
- [ ] App Store Connect associates the build with the correct app and version.
- [ ] Build processing reaches Complete.
- [ ] Resolve Missing Compliance or export documentation prompts.
- [ ] Review every upload warning before testing or submission.
- [ ] Confirm the processed build's icon, version, build number, SDK, and minimum OS.

Apple notes that an upload does not appear immediately; it must finish processing first. See [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) and [Build upload statuses](https://developer.apple.com/help/app-store-connect/reference/app-uploads/build-upload-statuses/).

## Part 6: Submit to App Review

### Final pre-submission gate

- [ ] The selected build is the exact TestFlight-approved candidate.
- [ ] Every device-test exit criterion is satisfied.
- [ ] No newer commit is being mistaken for the tested build.
- [ ] Metadata, privacy answers, age rating, export compliance, screenshots, support URL, and privacy policy are complete.
- [ ] Agreements and regional declarations are complete.
- [ ] App Review contact and notes are complete.
- [ ] Release option is selected.
- [ ] A rollback and support plan exists for launch day.

### Submission steps

1. In App Store Connect, open **Apps > Trip Planner**.
2. Select the iOS version `1.0` under Distribution.
3. In **Build**, choose the processed candidate and save. Only one build can be associated with a version at a time before submission. See [Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/).
4. Resolve every remaining required-information message.
5. Select **Add for Review** and add the version to a draft submission.
6. Open the draft in **App Review** and verify every included item.
7. Select **Submit for Review**. Adding an item for review does not itself send it to Apple. See [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
8. Monitor Waiting for Review, In Review, and any App Review messages.
9. Respond to questions in App Store Connect with clear reproduction steps and supporting evidence.
10. If rejected, do not upload a replacement blindly; identify the cited guideline, reproduce the issue, fix and retest, then reply or resubmit.

For V1.0, **Manually release this version** is recommended so approval does not immediately publish the app. After approval, perform a final metadata and support-readiness check, then release deliberately. Apple also supports automatic release and scheduled no-earlier-than release options; see [Select an App Store version release option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option).

## Part 7: Launch and post-release monitoring

- [ ] Confirm the production product page, screenshots, privacy label, age rating, and support links.
- [ ] Install the App Store build on a clean device.
- [ ] Repeat a short smoke test: launch, create trip, generate if available, persist, open directions, and switch icon.
- [ ] Monitor crashes, hangs, reviews, support email, and App Store Connect analytics.
- [ ] Triage launch defects by severity and data-loss risk.
- [ ] Keep the exact submitted source SHA, archive, dSYM, test evidence, metadata copy, and review correspondence.
- [ ] Update the privacy policy and App Store privacy answers before shipping later sharing, CloudKit, authentication, analytics, or backend functionality.

## Release sign-off

| Gate | Owner | Result | Evidence or notes |
| --- | --- | --- | --- |
| Clean and upgrade device tests | | | |
| iPhone and iPad coverage | | | |
| Foundation Models hardware tests | | | |
| Location and MapKit tests | | | |
| Accessibility review | | | |
| TestFlight internal exit | | | |
| TestFlight external exit | | | |
| Privacy and required-reason API audit | | | |
| Export compliance determination | | | |
| Metadata and screenshot review | | | |
| Archive validation and upload | | | |
| App Review submission authorization | | | |

Release owner approval:

- Name:
- Date:
- Commit SHA:
- Version and build:
- Decision: Approved / Rejected / Conditional
- Notes:

## Official Apple references

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [TestFlight Overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

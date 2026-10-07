# KEF Remote — common development commands
# Usage: make <target>

SPEAKER_SUBSYSTEM = com.kef-remote
LOG_FILE = $(HOME)/.kef-remote/logs/kef-remote.log

# Run all tests
test:
	swift test --disable-sandbox

# Find the speaker on the network and print every step (MAC=... to match one)
discover:
	swift run --disable-sandbox kef-discover $(if $(MAC),--mac $(MAC))

# Run every speaker command, read each back, then put the starting state
# back. It changes what the speaker plays: only when nobody is listening.
# INPUTS=1 also visits each input; DRY_RUN=1 uses a simulated speaker.
# KEF Remote must be quit: the speaker takes one connection at a time.
# Takes a few minutes: it waits for each power change, up to 20 s, then 15 s more.
speaker-check:
	@if [ -z "$(DRY_RUN)" ] && pgrep -x KEFRemote >/dev/null; then \
		echo "KEF Remote is running and holds the speaker's one connection. Quit it first (make kill)."; \
		exit 1; \
	fi
	swift run --disable-sandbox kef-check $(if $(INPUTS),--inputs) $(if $(DRY_RUN),--dry-run)

# Redraw the app icon's PNGs from Design/AppIcon.svg (commit the results)
APP_ICON_SET = Sources/KEFRemote/Assets.xcassets/AppIcon.appiconset
app-icon:
	swift Design/render-app-icon.swift Design/AppIcon.svg $(APP_ICON_SET)

# --- App launch ---

DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
APP_BUNDLE = $(shell ls -td $(DERIVED_DATA)/KEFRemote-*/Build/Products/Debug/KEFRemote.app 2>/dev/null | head -1)

# Launch the most recently built Debug .app standalone
run:
	@if [ -z "$(APP_BUNDLE)" ]; then echo "No debug build found — build in Xcode first (Cmd+B)"; exit 1; fi
	@echo "Launching: $(APP_BUNDLE)"
	open "$(APP_BUNDLE)"

# Build this checkout's branch and launch it, ready for a hand test.
# Quits any running KEF Remote first. No Xcode needed. Run it from the
# checkout or worktree that holds the branch under test.
TEST_BUILD_DIR = .build/test-build
TEST_APP = $(TEST_BUILD_DIR)/Build/Products/Debug/KEFRemote.app
test-build: kill
	@echo "Building branch: $$(git branch --show-current) ($$(git rev-parse --short HEAD))"
	xcodebuild -project KEFRemote.xcodeproj -scheme KEFRemote -configuration Debug -derivedDataPath $(TEST_BUILD_DIR) build -quiet
	open "$(TEST_APP)"
	@echo "Running: $(TEST_APP)"
	@echo "Watch the log with: make logs-tail"

# --- Release packaging ---

RELEASE_APP = $(shell ls -td $(DERIVED_DATA)/KEFRemote-*/Build/Products/Release/KEFRemote.app 2>/dev/null | head -1)
DIST_DIR = dist

# Zip the most recent Release .app into dist/KEFRemote-<version>.zip.
# Builds nothing: archive or build Release in Xcode first. The version
# is read from the built app's Info.plist (CFBundleShortVersionString).
package:
	@if [ -z "$(RELEASE_APP)" ]; then echo "No Release build found — build Release in Xcode first (Product > Build For > Profiling, or Archive)"; exit 1; fi
	@VERSION=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(RELEASE_APP)/Contents/Info.plist"); \
	ZIP="$(DIST_DIR)/KEFRemote-$$VERSION.zip"; \
	mkdir -p "$(DIST_DIR)"; \
	rm -f "$$ZIP"; \
	echo "Packaging: $(RELEASE_APP)"; \
	ditto -c -k --norsrc --keepParent "$(RELEASE_APP)" "$$ZIP"; \
	echo "Wrote $$ZIP"

# Kill all running KEFRemote instances (prevents stale background agents).
# Handles both standalone and Xcode-debugged processes. When Xcode's
# debugserver is the parent, the child can't be killed directly — we
# kill the debugserver first, which releases the held process.
kill:
	@PIDS=$$(pgrep -x KEFRemote 2>/dev/null); \
	if [ -z "$$PIDS" ]; then echo "No KEFRemote running"; exit 0; fi; \
	for PID in $$PIDS; do \
		PARENT=$$(ps -p $$PID -o ppid= 2>/dev/null | tr -d ' '); \
		if ps -p $$PARENT -o command= 2>/dev/null | grep -q debugserver; then \
			kill -9 $$PARENT 2>/dev/null; \
		else \
			kill -9 $$PID 2>/dev/null; \
		fi; \
	done; \
	sleep 0.3; \
	if pgrep -x KEFRemote >/dev/null 2>&1; then \
		echo "WARNING: KEFRemote still running — try stopping from Xcode"; \
	else \
		echo "KEFRemote stopped"; \
	fi

# --- Log file commands (work always — Xcode or standalone) ---

# Live stream from log file (works regardless of how app was launched)
logs-tail:
	tail -f "$(LOG_FILE)"

# Last 200 lines from log file (quick snapshot for agents)
logs-recent:
	tail -200 "$(LOG_FILE)"

# Full log file contents
logs-full:
	cat "$(LOG_FILE)"

# --- Log file filters (work always — Xcode, standalone, agent sandbox) ---

# Errors only
logs-errors:
	@grep -F "[ERROR]" "$(LOG_FILE)" || echo "No errors in log file"

# Warnings and errors
logs-warnings:
	@grep -E "\\[(WARN|ERROR)\\]" "$(LOG_FILE)" || echo "No warnings or errors in log file"

# Debug lines only (bytes on the wire)
logs-debug:
	@grep -F "[DEBUG]" "$(LOG_FILE)" || echo "No debug lines in log file"

# --- os.Logger stream commands (standalone app + interactive terminal only) ---
# `log stream` refuses to run inside the agent sandbox: agents use the
# log file targets above.

# Operational logs via unified logging
logs-stream:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --style compact

# Full trace: operational + bytes on the wire
logs-stream-debug:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --level debug --style compact

# Errors only via unified logging
logs-stream-errors:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)" AND messageType == error' --style compact

# Stop background log stream processes
logs-stop:
	pkill -f "log stream" 2>/dev/null || echo "No log stream running"

# --- Hardware control (kefctl named interfaces) ---

# kefctl (github.com/kraih/kefctl) is not vendored here. Point KEFCTL_DIR at a
# copy, in the environment or in a gitignored .claude/make.local.
-include .claude/make.local
KEFCTL_DIR ?= kefctl
KEFCTL = perl $(KEFCTL_DIR)/kefctl

# Allow tier — bounded, no-parameter operations (kef-*)

kef-on:
	$(KEFCTL) --on

kef-off:
	$(KEFCTL) --off

kef-status:
	$(KEFCTL) --status

kef-mute:
	$(KEFCTL) --mute

kef-unmute:
	$(KEFCTL) --unmute

kef-toggle:
	$(KEFCTL) --toggle

kef-play:
	$(KEFCTL) --play

kef-next:
	$(KEFCTL) --next

kef-previous:
	$(KEFCTL) --previous

# Ask tier — parameterised operations (kef-raw-*)

kef-raw-volume:
	@test -n "$(VOL)" || (echo "Usage: make kef-raw-volume VOL=<0-100>"; exit 1)
	$(KEFCTL) --volume $(VOL)

kef-raw-raise:
	@test -n "$(VOL)" || (echo "Usage: make kef-raw-raise VOL=<1-100>"; exit 1)
	$(KEFCTL) --raise $(VOL)

kef-raw-lower:
	@test -n "$(VOL)" || (echo "Usage: make kef-raw-lower VOL=<1-100>"; exit 1)
	$(KEFCTL) --lower $(VOL)

kef-raw-input:
	@test -n "$(SRC)" || (echo "Usage: make kef-raw-input SRC=<wifi|usb|bluetooth|aux|optical>"; exit 1)
	$(KEFCTL) --input $(SRC)

kef-raw-standby:
	@test -n "$(MIN)" || (echo "Usage: make kef-raw-standby MIN=<0|20|60>"; exit 1)
	$(KEFCTL) --standby $(MIN)

.PHONY: test discover speaker-check app-icon run test-build package kill logs-tail logs-recent logs-full logs-errors logs-warnings logs-debug logs-stream logs-stream-debug logs-stream-errors logs-stop kef-on kef-off kef-status kef-mute kef-unmute kef-toggle kef-play kef-next kef-previous kef-raw-volume kef-raw-raise kef-raw-lower kef-raw-input kef-raw-standby

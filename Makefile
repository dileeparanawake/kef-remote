# KEF Remote — common development commands
# Usage: make <target>

SPEAKER_SUBSYSTEM = com.kef-remote
LOG_FILE = $(HOME)/.kef-remote/logs/kef-remote.log

# Run all tests
test:
	swift test --disable-sandbox

# --- App launch ---

DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
APP_BUNDLE = $(shell ls -td $(DERIVED_DATA)/KEFRemote-*/Build/Products/Debug/KEFRemote.app 2>/dev/null | head -1)

# Launch the most recently built Debug .app standalone
run:
	@if [ -z "$(APP_BUNDLE)" ]; then echo "No debug build found — build in Xcode first (Cmd+B)"; exit 1; fi
	@echo "Launching: $(APP_BUNDLE)"
	open "$(APP_BUNDLE)"

# Kill all running KEFRemote instances (prevents stale background agents)
kill:
	@pkill -x KEFRemote 2>/dev/null && echo "Killed KEFRemote" || echo "No KEFRemote running"

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

# --- os.Logger stream commands (standalone only — use 'make run') ---

# Operational logs via unified logging (standalone only)
logs:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --style compact

# Full trace: operational + bytes on the wire
logs-debug:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --level debug --style compact

# Errors only
logs-errors:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)" AND messageType == error' --style compact

.PHONY: test run kill logs-tail logs-recent logs-full logs logs-debug logs-errors

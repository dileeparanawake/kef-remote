# KEF Remote — common development commands
# Usage: make <target>

SPEAKER_SUBSYSTEM = com.kef-remote

# Run all tests
test:
	swift test --disable-sandbox

# --- Log stream commands (app must be running) ---

# Operational logs only: what happened, what values (default view)
logs:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --style compact

# Full trace: operational + bytes on the wire
logs-debug:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --level debug --style compact

# Errors only
logs-errors:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)" AND messageType == error' --style compact

# Input events only (key presses, shortcuts)
logs-input:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)" AND category == "MediaKeyInterceptor"' --style compact

# Speaker communication only
logs-speaker:
	log stream --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)" AND category == "speaker"' --style compact

# Recent logs (last 5 minutes, useful after a session — no live stream)
logs-recent:
	log show --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --last 5m --style compact

logs-recent-debug:
	log show --predicate 'subsystem == "$(SPEAKER_SUBSYSTEM)"' --last 5m --level debug --style compact

.PHONY: test logs logs-debug logs-errors logs-input logs-speaker logs-recent logs-recent-debug

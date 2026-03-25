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

# --- Log file filter commands (work always — Xcode, standalone, sandbox) ---

# Errors only (from log file)
logs-errors:
	grep "\\[ERROR\\]" "$(LOG_FILE)" || echo "No errors in log file"

# Warnings and errors (from log file)
logs-warnings:
	grep -E "\\[(WARN|ERROR)\\]" "$(LOG_FILE)" || echo "No warnings or errors in log file"

# Debug-level entries only (from log file)
logs-debug:
	grep "\\[DEBUG\\]" "$(LOG_FILE)" || echo "No debug entries in log file"

# --- os.Logger stream commands (standalone + interactive terminal only) ---

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

KEFCTL = perl resources/reference/kefctl/kefctl

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

# --- Context repo commands (kef-remote-context companion directory) ---

CONTEXT_DIR = $(HOME)/coding/projects/context-engineering/projects/kef-remote-context

context-status:
	git -C $(CONTEXT_DIR) status

context-diff:
	git -C $(CONTEXT_DIR) diff

context-log:
	git -C $(CONTEXT_DIR) log --oneline -20

context-show:
	git -C $(CONTEXT_DIR) show $(if $(REF),$(REF),HEAD)

context-add:
	git -C $(CONTEXT_DIR) add -A

context-add-kef:
	git -C $(CONTEXT_DIR) add status.md plans/

context-commit:
	@test -n "$(MSG)" || (echo "Usage: make context-commit MSG=\"your message\""; exit 1)
	git -C $(CONTEXT_DIR) commit -m "$(MSG)"

# --- Metrics ---

metrics-tokens:
	python3 context/plans/v1/meta/notes/extract_tokens.py

.PHONY: test run kill logs-tail logs-recent logs-full logs-errors logs-warnings logs-debug logs-stream logs-stream-debug logs-stream-errors logs-stop kef-on kef-off kef-status kef-mute kef-unmute kef-toggle kef-play kef-next kef-previous kef-raw-volume kef-raw-raise kef-raw-lower kef-raw-input kef-raw-standby context-status context-diff context-log context-show context-add context-add-kef context-commit metrics-tokens

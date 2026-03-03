VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

STATUSLINE_SRC := $(abspath src/statusline-command.sh)
STATUSLINE_DEST := $(HOME)/.claude/statusline-command.sh

.PHONY: setup install test clean

install:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

setup: install
	@if [ -f "$(STATUSLINE_DEST)" ] && [ ! -L "$(STATUSLINE_DEST)" ]; then \
		cp "$(STATUSLINE_DEST)" "$(STATUSLINE_DEST).bak"; \
		echo "Backed up existing statusline script to $(STATUSLINE_DEST).bak"; \
	fi
	ln -sf "$(STATUSLINE_SRC)" "$(STATUSLINE_DEST)"
	@echo "Linked $(STATUSLINE_DEST) -> $(STATUSLINE_SRC)"

test:
	@echo '{}' | bash src/statusline-command.sh

clean:
	rm -rf $(VENV)

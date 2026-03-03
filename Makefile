STATUSLINE_SRC := $(abspath src/statusline.sh)
STATUSLINE_DEST := $(HOME)/.claude/statusline.sh

.PHONY: activate clean install setup print test 

activate:
	source ./venv/bin/activate

clean:
	rm -rf .venv **/__pycache__ .pytest_cache

install:
	python3 -m venv .venv
	pip install -r requirements.txt

setup: install
	@if [ -f "$(STATUSLINE_DEST)" ] && [ ! -L "$(STATUSLINE_DEST)" ]; then \
		cp "$(STATUSLINE_DEST)" "$(STATUSLINE_DEST).bak"; \
		echo "Backed up existing statusline script to $(STATUSLINE_DEST).bak"; \
	fi
	ln -sf "$(STATUSLINE_SRC)" "$(STATUSLINE_DEST)"
	@echo "Linked $(STATUSLINE_DEST) -> $(STATUSLINE_SRC)"

# Test printing out the statusline with live ccburn data, but no context.
print:
	@echo '{}' | bash src/statusline.sh

test:
	pytest tests/ -v

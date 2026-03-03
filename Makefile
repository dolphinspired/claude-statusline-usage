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
	bash src/setup.sh "$(STATUSLINE_SRC)" "$(STATUSLINE_DEST)"

# Test printing out the statusline with live ccburn data, but no context.
print:
	@echo '{}' | bash src/statusline.sh

test:
	pytest tests/ -v

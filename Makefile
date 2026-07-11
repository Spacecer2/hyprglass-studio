.PHONY: install uninstall dev test lint clean format docs release

install:
	./install.sh

uninstall:
	./uninstall.sh

dev:
	python -m studio --dev

test:
	pytest

lint:
	shellcheck install.sh uninstall.sh
	ruff check .

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete
	find . -type f -name '*.pyo' -delete

format:
	ruff format .

docs:
	mkdocs build

release:
	git tag "$$(cat VERSION)"
	git push origin "$$(cat VERSION)"

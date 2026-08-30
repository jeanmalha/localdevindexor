.PHONY: test lint install release

test:
	bats tests/

lint:
	shellcheck reindex.sh list.sh toggle-star.sh preview.sh edit-summary.sh install.sh
	zsh -n shell.zsh

install:
	./install.sh

release:
	@test -n "$(VERSION)" || (echo "Usage: make release VERSION=v0.x.y[-beta.N]"; exit 1)
	@echo "Running tests before tagging..."
	@$(MAKE) lint
	@$(MAKE) test
	@echo "Tagging $(VERSION)..."
	git tag -a $(VERSION) -m "Release $(VERSION)"
	git push origin $(VERSION)
	@echo "Tag pushed — GitHub Actions will create the release."

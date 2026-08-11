# A bare VERSION file is the single source of truth for the release version
# (bumped by vrsn, read by prepare-release). Every Spoon's `obj.version` is kept
# in lockstep with it by `make sync` — the Spoons ship together and are indexed
# together in docs/docs.json, so they share one version rather than each
# carrying its own.
VERSION_FILE = VERSION

# vrsn has no Lua reader, but --pattern locates the version in any plaintext
# file via a capture group. The version must be full semver: vrsn cannot parse a
# two-component version like "1.0".
SPOON_VERSION_PATTERN = obj\.version = "([0-9]+\.[0-9]+\.[0-9]+)"

SPOONS = $(wildcard Source/*.spoon)

.PHONY: help build sync verify patch minor major bump deploy-beta deploy

.DEFAULT_GOAL := help

help: ## Show this help
	@echo "hammerspoons — available make targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# MARK: - Building

build: ## Rebuild the installable Spoon zips in Spoons/ from Source/
	./build.sh

sync: ## Write the VERSION value into every Spoon, then rebuild the zips
	@version=$$(cat $(VERSION_FILE)); \
	for spoon in $(SPOONS); do \
		vrsn --custom "$$version" -f "$$spoon/init.lua" -p '$(SPOON_VERSION_PATTERN)' >/dev/null; \
		echo "set $$spoon to $$version"; \
	done
	@$(MAKE) --no-print-directory build

# Compares each committed zip against its Source/ tree by content rather than by
# bytes: zip stores modification times, so a rebuilt archive never matches the
# committed one byte for byte even when nothing changed.
verify: ## Check that the committed zips match Source/ (run by CI)
	@status=0; \
	tmp=$$(mktemp -d); \
	trap 'rm -rf "$$tmp"' EXIT; \
	for spoon in $(SPOONS); do \
		name=$$(basename "$$spoon"); \
		zip_path="Spoons/$$name.zip"; \
		if [ ! -f "$$zip_path" ]; then \
			echo "missing $$zip_path — run \`make build\`"; \
			status=1; \
			continue; \
		fi; \
		rm -rf "$$tmp/$$name"; \
		unzip -q "$$zip_path" -d "$$tmp/unpacked-$$name"; \
		if diff -r "$$spoon" "$$tmp/unpacked-$$name/$$name" >/dev/null; then \
			echo "ok $$zip_path"; \
		else \
			echo "stale $$zip_path — run \`make build\` and commit the result:"; \
			diff -r "$$spoon" "$$tmp/unpacked-$$name/$$name" || true; \
			status=1; \
		fi; \
	done; \
	exit $$status

# MARK: - Releasing
#
# `make {patch,minor,major}` bumps VERSION with vrsn, writes that version into
# every Spoon, rebuilds the zips, and commits the lot as one change — the zips
# are committed artifacts (SpoonInstall downloads them straight off the branch),
# so they must never lag the sources they came from.
#
# Then `make deploy` runs prepare-release, which migrates the CHANGELOG
# [Unreleased] section into a dated version section, commits, tags, and pushes.
# GitHub Actions picks up the tag, publishes the release from that changelog
# section, and attaches the zips so a specific version stays downloadable.
#
# Installing does not go through the release: SpoonInstall fetches
# docs/docs.json and Spoons/<Name>.spoon.zip from the branch. Shipping to users
# is what `make {patch,minor,major}` pushes to main, and the release is the
# record of it.
#
# Requires `vrsn` + `prepare-release` on PATH (from the armcknight/tools cask).

patch: ## Bump the patch version (x.y.Z), sync the Spoons, and commit
	@$(MAKE) --no-print-directory bump COMPONENT=patch

minor: ## Bump the minor version (x.Y.0), sync the Spoons, and commit
	@$(MAKE) --no-print-directory bump COMPONENT=minor

major: ## Bump the major version (X.0.0), sync the Spoons, and commit
	@$(MAKE) --no-print-directory bump COMPONENT=major

bump:
	@test -n "$(COMPONENT)" || { echo "bump requires COMPONENT=patch|minor|major"; exit 1; }
	vrsn $(COMPONENT) -f $(VERSION_FILE)
	@$(MAKE) --no-print-directory sync
	git add $(VERSION_FILE) $(SPOONS) Spoons
	git commit -m "Bump version to $$(cat $(VERSION_FILE))"

deploy-beta: ## Migrate the changelog, tag an RC, and push
	prepare-release rc --file $(VERSION_FILE) --push

deploy: ## Migrate the changelog, tag, and push the release
	prepare-release --file $(VERSION_FILE) --push

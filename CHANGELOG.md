# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Every Spoon in this repo shares this version — they are built, indexed, and
installed together.

## [Unreleased]

### Added

- Release automation: `make {patch,minor,major}` bumps `VERSION`, writes it into
  every Spoon, rebuilds the zips, and commits them together; `make deploy` tags
  and pushes; CI publishes the GitHub release with the zips attached.
- `make verify` checks that the committed zips still match `Source/`, so a Spoon
  change can't ship without its rebuilt zip. CI runs it on every push and PR.

### Changed

- Spoon versions are now full semver (`1.0` became `1.0.0`), which is what `vrsn`
  needs to bump them.

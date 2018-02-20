# Audited Bundler Update

## Installation

```
gem install bundler-audited_update
```

You probably don't want to add this to your Gemfile.

## Use

Run `audited_bundle_update`

This will run a bundle update, display the changelog for each gem upgraded, then show you a summary view of changes for
each gem.

Example output:

```
# Gem Changes

## Added Gems

* rails 5.2.0: https://github.com/rails/rails

## Upgraded Gems

### Major Upgrades

* byebug (9.1.0 -> 10.0.0): No impact

### Minor Upgrades

* capybara (2.17.0 -> 2.18.0): May help with flaky test XYZ.

### Point Upgrades

* bullet (5.7.1 -> 5.7.3): No impact.
```

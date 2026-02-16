# Changelog

## [0.3.0] - 2026-02-15

- **Async mode now extracts geo data at enqueue time** when `request:` is passed
  - Cloudflare headers are captured before the job is enqueued
  - Background jobs no longer need MaxMind to get geo data
  - Falls back to MaxMind lookup in the job if `request:` wasn't passed
- No breaking changes — existing code works unchanged

## [0.2.1] - 2026-02-09

- Fix async mode: change Railtie to Engine so `TrackJob` is autoloaded

## [0.2.0] - 2026-02-08

**Full rewrite.** Breaking changes from v0.1.0.

- Rename `TrackableActivity` → `Footprint` (new table: `footprints`)
- Add `event_type` column for categorizing events (replaces multiple associations per type)
- Add JSONB `metadata` column with GIN index for arbitrary event data
- Add `performer` polymorphic reference (who triggered the event)
- Add `occurred_at` timestamp (defaults to `Time.current`)
- Add extended geo fields: `region`, `continent`, `timezone`, `latitude`, `longitude` (via trackdown 0.3+)
- Add generic `track(:event_type, ip:)` method for ad-hoc events
- Add scopes: `by_event`, `by_country`, `recent`, `last_days`, `between`, `performed_by`
- Add class methods: `.event_types`, `.countries`
- Add async mode with `Footprinted::TrackJob` (ActiveJob)
- Require trackdown ~> 0.3 for full geo field support
- Document JSONB performance at scale, column promotion pattern, and database compatibility

### Breaking changes

- Table renamed from `trackable_activities` to `footprints` — run the new generator and migrate
- Model renamed from `Footprinted::TrackableActivity` to `Footprinted::Footprint`
- `has_trackable` now creates `track_<singular>(ip:)` methods instead of the old API

## [0.1.0] - 2024-09-25

- Initial release
- Added Trackable concern for easy activity tracking
- Integrated with trackdown gem for IP geolocation
- Added customizable tracking associations
- Created install generator for easy setup
- Added configuration options

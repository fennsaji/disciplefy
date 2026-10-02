# showcaseview (patched 3.0.0)

Copy of [showcaseview 3.0.0](https://pub.dev/packages/showcaseview/versions/3.0.0)
(MIT, see `LICENSE`) with one fix:

- `GetPosition.getRenderBox` and `AnchoredOverlay` measured the target with
  `localToGlobal` without checking that it and its render ancestors were laid
  out. When a page holding an active showcase is moved under new widgets in
  the same frame its overlay rebuilds (e.g. a route transition re-wrapping the
  page), that threw `Bad state: RenderBox was not laid out`. Such targets are
  now skipped until the next rebuild (`GetPosition.isMeasurable`).
- `_scrollIntoView` no longer force-unwraps a target context that has gone.

Upstream 5.1.0 still measures without this check, so upgrading does not fix
it. Drop this copy once upstream guards the measurement.

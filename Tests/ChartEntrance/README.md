# Chart entrance regression checks

Run with an available iOS simulator:

```sh
bash Tests/ChartEntrance/run.sh SIMULATOR_UUID
```

The isolated fixture extracts the production entrance modifier, reveal shape and
progress ring. Swift Charts uses the same plot modifier placement as StatsView,
including its non-animated selection transaction. No app data or release targets
are changed.

Checks cover progressive rendered pixels, replay on cached-page activation,
rapid switching and cancellation, chart tap handling, and Reduce Motion showing
complete charts immediately. The Reduce Motion test temporarily changes the
simulator's setting and restores it on teardown. Early, middle and final PNGs are saved inside the
fixture's simulator Documents directory; XCTest also retains a final screenshot.

# Fixed Main Page Headers

Run the production four-tab UI with isolated QA data:

```sh
bash Tests/FixedHeaders/run.sh SIMULATOR_UUID
```

Requires Xcode and XcodeGen. Production sources are copied to a temporary
project; only the app entry point is replaced. The QA bundle identifier has its
own data store and does not touch the user's ledger or the release target.

Chinese and English tests check all four titles against the right-hand controls,
verify stable positions through repeated up/down scrolling, exercise the date
menus, and retain top/scrolled/menu screenshots in the result bundle.
Run on a small iPhone as well as a standard iPhone to check toolbar fit.

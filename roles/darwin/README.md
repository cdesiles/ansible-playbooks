# Darwin (macOS)

Baseline macOS hosts through Homebrew. No-op on non-Darwin targets.

Configure in `inventory/host_vars/<host>/vars.yml`:

```yaml
darwin_homebrew_update: false   # update formula metadata before installing
darwin_taps:
  - anomalyco/tap
darwin_formulae:
  - jq
  - ripgrep
darwin_casks:
  - iterm2
```

Casks install GUI apps; leave the list empty if you don't want them managed.
Requires the `community.general` collection (`homebrew`, `homebrew_tap`,
`homebrew_cask`). Must run as the Homebrew-owning user — never with `become`.

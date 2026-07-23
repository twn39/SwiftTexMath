# PNG Golden Fixtures

Committed raster baselines for layout regression tests (`GoldenPNGTests.swift`).

## Regenerate

From the package root:

```bash
REGENERATE_GOLDENS=1 swift test --filter goldenPNGsMatchCommittedFixtures
```

This overwrites PNGs in this directory. Review the diff before committing.

## Notes

- Renderer: Latin Modern, scale 2×, 2pt padding, black on white.
- Comparison allows small antialiasing deltas across OS versions (`MathImage.matches`).
- Fixtures cover fractions, matrices, colorbox, `\middle`, macros, wrap, overset, cancel, array vlines, aligned, phantoms, primes, `\oiint`, `\cfrac`, and `array @{…}`.
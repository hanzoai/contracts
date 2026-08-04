# LLM.md - Hanzo Contracts

## Overview
Hanzo AI Smart Contracts - AI infrastructure and identity on blockchain

## Tech Stack
- **Language**: TypeScript/JavaScript

## Build & Run
```bash
npm install && npm run build
npm test
```

## Structure
```
contracts/
  LICENSE
  LICENSE-APACHE
  LICENSE-MIT
  LLM.md
  broadcast/
  cache/
  foundry.lock
  foundry.toml
  lib/
  out/
  package.json
  scripts/
  src/
  test/
```

## Key Files
- `package.json` -- Dependencies and scripts

## Licensing

`MIT OR Apache-2.0`, at your option — per HIP-0137 (`hanzoai/hips`, `HIPs/hip-0137-one-license.md`). Relicensed from BSD-3-Clause,
which HIP-0137 puts out of scope for `hanzoai`.

Two things were inconsistent and are now fixed together: every `.sol` file
declared a bare `SPDX-License-Identifier: MIT` while `LICENSE` said
BSD-3-Clause, and that `LICENSE` was dated 2024 — before this repo's first
commit (2026-01-31). The SPDX headers now read `MIT OR Apache-2.0` and the
copyright year matches the root.

`lib/openzeppelin-contracts`, `lib/openzeppelin-contracts-upgradeable`,
`lib/forge-std` and `lib/standard` are git submodules, not vendored source. They
keep their own upstream licences and are untouched by this change.

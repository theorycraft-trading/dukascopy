# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Streaming API with `Dukascopy.stream/3` for tick and bar data
- `DataFeed` behaviour implementation for TheoryCraft integration
- Support for 1600+ instruments (Forex, Stocks, Crypto, Commodities, Bonds, ETFs, Indices)
- Multiple timeframes support (tick, s, m, h, D, W, M)
- Automatic resampling from ticks to any timeframe
- CLI tool for downloading historical data
- Instrument search functionality
- Caching support for downloaded data
- Timezone and UTC offset options
- Price type selection (bid, ask, mid)
- Volume units conversion (millions, thousands, units)

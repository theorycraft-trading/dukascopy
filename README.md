# Dukascopy

[Dukascopy](https://github.com/theorycraft-trading/dukascopy) is a [TheoryCraft](https://github.com/theorycraft-trading/theory_craft) extension for downloading and streaming historical market data from Dukascopy Bank SA.

Access free historical tick and bar data for 1600+ instruments including Forex, Stocks, Crypto, Commodities, Bonds, ETFs, and Indices.

## ⚠️ Development Status

**This library is under active development and the API is subject to frequent changes.**

Breaking changes may occur between releases as we refine the interface and add new features.

## Installation

Add `dukascopy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dukascopy, github: "theorycraft-trading/dukascopy"}
  ]
end
```

## CLI Usage

Install the CLI:

```bash
mix escript.install github theorycraft-trading/dukascopy
```

### Download Data

```bash
# Download daily EUR/USD data
dukascopy download -i EUR/USD --from 2024-01-01 --to 2024-12-31

# Download 5-minute bars in JSON format
dukascopy download -i EUR/USD -t m5 --from 2024-01-01 -f json

# Download with caching enabled
dukascopy download -i AAPL.US/USD -t h1 --from 2024-01-01 --cache

# Download tick data
dukascopy download -i EUR/USD -t tick --from 2024-01-01 --to 2024-01-02
```

### Search Instruments

```bash
# Search for instruments
dukascopy search EUR
dukascopy search AAPL
dukascopy search xau
```

### CLI Options

```
Usage:
  dukascopy download -i INSTRUMENT --from DATE [options]
  dukascopy search <query>

Required:
  -i, --instrument    Trading instrument (e.g., EUR/USD, AAPL.US/USD)
  --from              Start date (YYYY-MM-DD)

Options:
  --to                End date (YYYY-MM-DD or 'now') [default: now]
  -t, --timeframe     Timeframe: tick, m1, m5, m15, m30, h1, h4, D, W, M [default: D]
  -p, --price-type    Price type: bid, ask, mid [default: bid]
  -f, --format        Output format: csv, json, ndjson [default: csv]
  -o, --output        Output directory [default: ./download]
  -h, --help          Show help message
```

## Elixir API

### Search Instruments

```elixir
alias Dukascopy.Instruments

# Get all instruments
Instruments.all()
# => ["EUR/USD", "GBP/USD", "AAPL.US/USD", "BTC/USD", ...]

# Filter by category
Instruments.forex_majors()  # => ["AUD/USD", "EUR/USD", "GBP/USD", ...]
Instruments.forex_crosses() # => ["AUD/CAD", "EUR/GBP", ...]
Instruments.metals()        # => ["XAU/USD", "XAG/USD", ...]
Instruments.stocks()        # => ["AAPL.US/USD", "TSLA.US/USD", ...]
Instruments.commodities()   # => ["BRENT.CMD/USD", "COPPER.CMD/USD", ...]
Instruments.agriculturals() # => ["COCOA.CMD/USD", "COFFEE.CMD/USX", ...]

# Search instruments by name
Instruments.search("eur")
# => ["EUR/USD", "EUR/GBP", "EUR/JPY", ...]
```

### DataFeed (TheoryCraft Integration)

Use `Dukascopy.DataFeed` with TheoryCraft's `MarketSource` to build trading pipelines:

```elixir
alias TheoryCraft.MarketSource

# Build a pipeline with Dukascopy data
opts = [
  instrument: "EUR/USD",
  granularity: :ticks,
  from: ~D[2024-01-01],
  to: ~D[2024-01-31]
]

market =
  %MarketSource{}
  |> MarketSource.add_data({Dukascopy.DataFeed, opts}, name: "EURUSD")
  |> MarketSource.resample("m5", name: "EURUSD_m5")
  |> MarketSource.resample("h1", name: "EURUSD_h1")

# Stream events through the pipeline
for event <- MarketSource.stream(market) do
  IO.inspect(event)
end
```

Available granularities: `:ticks`, `:minute`, `:hour`, `:day`

### Streaming API

Use `Dukascopy.stream/3` for aggregated data with automatic resampling:

```elixir
# Stream raw ticks
Dukascopy.stream("EUR/USD", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
|> Enum.take(1000)

# Stream 5-minute bars
Dukascopy.stream("EUR/USD", "m5", from: ~D[2024-01-01], to: ~D[2024-01-31])
|> Enum.to_list()

# Stream hourly bars with options
Dukascopy.stream("EUR/USD", "h1",
  from: ~D[2024-01-01],
  to: ~D[2024-12-31],
  price_type: :mid,
  timezone: "America/New_York"
)
|> Enum.to_list()

# Stream daily bars with caching
Dukascopy.stream("EUR/USD", "D",
  date_range: Date.range(~D[2020-01-01], ~D[2024-01-01]),
  use_cache: true
)
|> Enum.to_list()

# Stream weekly bars
Dukascopy.stream("EUR/USD", "W",
  from: ~D[2024-01-01],
  to: ~D[2024-12-31],
  market_open: ~T[17:00:00],
  weekly_open: :sunday
)
|> Enum.to_list()
```

Supported timeframes (strings or atoms):
- `:ticks` - Raw tick data
- `t<N>` - N ticks per bar (e.g., `t5`, `t100`)
- `s<N>` - N-second bars (e.g., `s30`)
- `m<N>` - N-minute bars (e.g., `m1`, `m5`, `m15`)
- `h<N>` - N-hour bars (e.g., `h1`, `h4`)
- `D<N>` - N-day bars (e.g., `D`, `D3`)
- `W<N>` - N-week bars (e.g., `W`)
- `M<N>` - N-month bars (e.g., `M`)

## Instruments

| Category | Count | Examples |
|----------|-------|----------|
| Forex Majors | 7 | EUR/USD, GBP/USD, USD/JPY |
| Forex Crosses | 290+ | EUR/GBP, AUD/NZD, GBP/JPY |
| Metals | 50+ | XAU/USD, XAG/USD, XPT/USD |
| Stocks | 1000+ | AAPL.US/USD, TSLA.US/USD |
| Commodities | 10+ | BRENT.CMD/USD, COPPER.CMD/USD |
| Agriculturals | 6 | COCOA.CMD/USD, COFFEE.CMD/USX |

## Development

```bash
# Run tests (excludes network tests by default)
mix test

# Run tests including network tests
mix test --include network

# Run CI checks (credo + tests)
mix ci

# Update instrument metadata from Dukascopy API
mix dukascopy.gen.instruments
```

## License

Copyright (C) 2025 TheoryCraft Trading

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

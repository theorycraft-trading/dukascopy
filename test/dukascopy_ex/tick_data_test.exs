defmodule DukascopyEx.TickDataTest do
  use ExUnit.Case, async: true

  alias DukascopyEx.TestFixtures
  alias DukascopyEx.TickData
  alias TheoryCraft.MarketSource.Tick

  ## Tests

  # Do not use doctests here as they would require network access
  # doctest DukascopyEx.TickData

  describe "fetch/4" do
    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               TickData.fetch("UNKNOWN", ~D[2024-11-15], 10)
    end

    test "fetches and parses tick data" do
      opts = TestFixtures.stub_dukascopy(:tick_data_fetch)

      # 2019-02-04 -> EURUSD/2019/01/04 (month is 0-indexed)
      assert {:ok, ticks} = TickData.fetch("EUR/USD", ~D[2019-02-04], 0, opts)
      assert length(ticks) > 0

      assert %Tick{
               time: time,
               ask: ask,
               bid: bid,
               ask_volume: ask_vol,
               bid_volume: bid_vol
             } = hd(ticks)

      assert %DateTime{year: 2019, month: 2, day: 4, hour: 0} = time
      assert is_float(ask)
      assert is_float(bid)
      assert is_float(ask_vol)
      assert is_float(bid_vol)
    end

    test "returns empty list for 404 (no data)" do
      opts = TestFixtures.stub_dukascopy(:tick_data_404)

      # This path doesn't exist in fixtures
      assert {:ok, []} = TickData.fetch("EUR/USD", ~D[2000-01-01], 0, opts)
    end

    test "fetches tick data for different hours" do
      opts = TestFixtures.stub_dukascopy(:tick_data_hours)

      # Hour 10
      assert {:ok, ticks_h10} = TickData.fetch("EUR/USD", ~D[2019-02-04], 10, opts)
      assert length(ticks_h10) > 0
      assert %Tick{time: %DateTime{hour: 10}} = hd(ticks_h10)

      # Hour 23
      assert {:ok, ticks_h23} = TickData.fetch("EUR/USD", ~D[2019-02-04], 23, opts)
      assert length(ticks_h23) > 0
      assert %Tick{time: %DateTime{hour: 23}} = hd(ticks_h23)
    end
  end

  describe "tick parsing" do
    test "parses all tick fields correctly" do
      opts = TestFixtures.stub_dukascopy(:tick_parsing)

      {:ok, ticks} = TickData.fetch("EUR/USD", ~D[2019-02-04], 0, opts)
      [tick | _] = ticks

      # Verify all fields are present and have correct types
      assert is_struct(tick, Tick)
      assert is_struct(tick.time, DateTime)
      assert is_float(tick.ask)
      assert is_float(tick.bid)
      assert is_float(tick.ask_volume)
      assert is_float(tick.bid_volume)

      # Ask should be >= bid (typical for forex)
      assert tick.ask >= tick.bid
    end

    test "respects point_value option" do
      opts = TestFixtures.stub_dukascopy(:tick_point_value)

      # Default point_value for EUR/USD
      {:ok, ticks_default} = TickData.fetch("EUR/USD", ~D[2019-02-04], 0, opts)

      # Custom point_value
      {:ok, ticks_custom} =
        TickData.fetch(
          "EUR/USD",
          ~D[2019-02-04],
          0,
          Keyword.merge(opts, point_value: 10)
        )

      # With point_value 10, prices should be much larger
      [t1 | _] = ticks_default
      [t2 | _] = ticks_custom

      # Default EUR/USD point_value is 100_000, so ratio should be 10_000
      assert_in_delta t2.ask / t1.ask, 10_000, 1
    end
  end

  describe "fetch!/4" do
    test "raises on unknown instrument" do
      assert_raise RuntimeError, ~r/unknown_instrument/, fn ->
        TickData.fetch!("UNKNOWN", ~D[2024-11-15], 10)
      end
    end

    test "returns ticks on success" do
      opts = TestFixtures.stub_dukascopy(:tick_bang)

      ticks = TickData.fetch!("EUR/USD", ~D[2019-02-04], 0, opts)
      assert length(ticks) > 0
      assert %Tick{} = hd(ticks)
    end
  end
end

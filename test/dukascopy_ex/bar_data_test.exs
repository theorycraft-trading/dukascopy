defmodule DukascopyEx.BarDataTest do
  use ExUnit.Case, async: true

  alias DukascopyEx.BarData
  alias DukascopyEx.TestFixtures
  alias TheoryCraft.MarketSource.Bar

  ## Tests

  describe "fetch/4" do
    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               BarData.fetch("UNKNOWN", :minute, ~D[2024-11-15])
    end

    test "returns error for invalid timeframe" do
      assert_raise FunctionClauseError, fn ->
        BarData.fetch("EUR/USD", :invalid, ~D[2024-11-15])
      end
    end

    test "fetches minute bars" do
      opts = TestFixtures.stub_dukascopy(:bar_minute)

      # 2019-02-04 -> EURUSD/2019/01/04/BID_candles_min_1.bi5
      assert {:ok, bars} = BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], opts)
      assert length(bars) > 0

      assert %Bar{
               time: time,
               open: open,
               high: high,
               low: low,
               close: close,
               volume: volume
             } = hd(bars)

      assert %DateTime{year: 2019, month: 2, day: 4, hour: 0, minute: 0} = time
      assert is_float(open)
      assert is_float(high)
      assert is_float(low)
      assert is_float(close)
      assert is_float(volume)
      assert high >= low
    end

    test "fetches hourly bars" do
      opts = TestFixtures.stub_dukascopy(:bar_hourly)

      # 2019-02-01 -> EURUSD/2019/01/BID_candles_hour_1.bi5
      assert {:ok, bars} = BarData.fetch("EUR/USD", :hour, ~D[2019-02-01], opts)
      assert length(bars) > 0

      assert %Bar{time: time, open: open, high: high, low: low, close: close} = hd(bars)
      # First bar should be at the start of the month
      assert %DateTime{year: 2019, month: 2, day: 1, hour: 0} = time
      assert is_float(open)
      assert is_float(high)
      assert is_float(low)
      assert is_float(close)
      assert high >= low
    end

    test "fetches daily bars" do
      opts = TestFixtures.stub_dukascopy(:bar_daily)

      # 2019-06-15 -> EURUSD/2019/BID_candles_day_1.bi5
      assert {:ok, bars} = BarData.fetch("EUR/USD", :day, ~D[2019-06-15], opts)
      assert length(bars) > 0

      assert %Bar{time: time, open: open, high: high, low: low, close: close} = hd(bars)
      # First bar should be at the start of the year
      assert %DateTime{year: 2019, month: 1, day: 1, hour: 0} = time
      assert is_float(open)
      assert is_float(high)
      assert is_float(low)
      assert is_float(close)
      assert high >= low
    end

    test "returns empty list for 404 (no data)" do
      opts = TestFixtures.stub_dukascopy(:bar_404)

      # This path doesn't exist in fixtures
      assert {:ok, []} = BarData.fetch("EUR/USD", :minute, ~D[2000-01-01], opts)
    end
  end

  describe "price_type option" do
    test "defaults to :bid" do
      opts = TestFixtures.stub_dukascopy(:bar_price_bid)

      # Should use BID_candles_min_1.bi5
      assert {:ok, bars} = BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], opts)
      assert length(bars) > 0
    end

    test "supports :ask price_type" do
      opts = TestFixtures.stub_dukascopy(:bar_price_ask)

      # We don't have ASK fixtures, so should return 404 -> empty
      assert {:ok, []} =
               BarData.fetch(
                 "EUR/USD",
                 :minute,
                 ~D[2019-02-04],
                 Keyword.merge(opts, price_type: :ask)
               )
    end
  end

  describe "bar parsing" do
    test "parses all bar fields correctly" do
      opts = TestFixtures.stub_dukascopy(:bar_parsing)

      {:ok, bars} = BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], opts)
      [bar | _] = bars

      # Verify all fields are present and have correct types
      assert is_struct(bar, Bar)
      assert is_struct(bar.time, DateTime)
      assert is_float(bar.open)
      assert is_float(bar.high)
      assert is_float(bar.low)
      assert is_float(bar.close)
      assert is_float(bar.volume)

      # High should be highest, low should be lowest (with float tolerance)
      assert bar.high >= bar.low
    end

    test "respects point_value option" do
      opts = TestFixtures.stub_dukascopy(:bar_point_value)

      # Default point_value for EUR/USD
      {:ok, bars_default} = BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], opts)

      # Custom point_value
      {:ok, bars_custom} =
        BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], Keyword.merge(opts, point_value: 10))

      # With point_value 10, prices should be much larger
      [b1 | _] = bars_default
      [b2 | _] = bars_custom

      # Default EUR/USD point_value is 100_000, so ratio should be 10_000
      assert_in_delta b2.open / b1.open, 10_000, 1
    end
  end

  describe "fetch!/4" do
    test "raises on unknown instrument" do
      assert_raise RuntimeError, ~r/unknown_instrument/, fn ->
        BarData.fetch!("UNKNOWN", :minute, ~D[2024-11-15])
      end
    end

    test "returns bars on success" do
      opts = TestFixtures.stub_dukascopy(:bar_bang)

      bars = BarData.fetch!("EUR/USD", :minute, ~D[2019-02-04], opts)
      assert length(bars) > 0
      assert %Bar{} = hd(bars)
    end
  end
end

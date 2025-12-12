defmodule DukascopyEx.BarDataTest do
  use ExUnit.Case, async: true

  import DukascopyEx.TestAssertions

  alias DukascopyEx.BarData
  alias DukascopyEx.TestFixtures

  ## Tests

  describe "fetch/4 validation" do
    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               BarData.fetch("UNKNOWN", :minute, ~D[2024-11-15])
    end

    test "raises for invalid timeframe" do
      assert_raise FunctionClauseError, fn ->
        BarData.fetch("EUR/USD", :invalid, ~D[2024-11-15])
      end
    end
  end

  describe "fetch/4 minute bars parsing" do
    test "parses first m1 bar with exact values" do
      opts = TestFixtures.stub_dukascopy(:bar_m1_exact)

      {:ok, bars} = BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], opts)
      [first | _] = bars

      # First m1 bar from BID_candles_min_1.bi5: [0, 114543, 114569, 114542, 114570, 293.76]
      # Binary format: [time_delta_sec, open, close, low, high, volume]
      assert first.time == ~U[2019-02-04 00:00:00Z]
      assert first.open == 1.14543
      assert first.close == 1.14569
      assert first.low == 1.14542
      assert first.high == 1.14570
      assert_in_delta first.volume, 293.76, 0.01
    end

    test "parses multiple m1 bars in correct order" do
      opts = TestFixtures.stub_dukascopy(:bar_m1_order)

      {:ok, bars} = BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], opts)

      # 1 day of m1 bars = 1440 bars
      assert length(bars) == 1440
      assert_uniform_spacing bars, :timer.minutes(1)

      # Second bar: [60, 114569, 114575, 114565, 114580, 271.59]
      b2 = Enum.at(bars, 1)
      assert b2.time == ~U[2019-02-04 00:01:00Z]
      assert b2.open == 1.14569
      assert b2.close == 1.14575
      assert b2.low == 1.14565
      assert b2.high == 1.14580
      assert_in_delta b2.volume, 271.59, 0.01

      # Third bar: [120, 114575, 114563, 114562, 114581, 386.57]
      b3 = Enum.at(bars, 2)
      assert b3.time == ~U[2019-02-04 00:02:00Z]
      assert b3.open == 1.14575
      assert b3.close == 1.14563
      assert b3.low == 1.14562
      assert b3.high == 1.14581
      assert_in_delta b3.volume, 386.57, 0.01
    end
  end

  describe "fetch/4 hourly bars parsing" do
    test "parses first h1 bar with exact values" do
      opts = TestFixtures.stub_dukascopy(:bar_h1_exact)

      {:ok, bars} = BarData.fetch("EUR/USD", :hour, ~D[2019-02-01], opts)
      [first | _] = bars

      # First h1 bar from BID_candles_hour_1.bi5: [0, 114482, 114481, 114462, 114499, 6718.49]
      assert first.time == ~U[2019-02-01 00:00:00Z]
      assert first.open == 1.14482
      assert first.close == 1.14481
      assert first.low == 1.14462
      assert first.high == 1.14499
      assert_in_delta first.volume, 6718.49, 0.01
    end

    test "parses multiple h1 bars in correct order" do
      opts = TestFixtures.stub_dukascopy(:bar_h1_order)

      {:ok, bars} = BarData.fetch("EUR/USD", :hour, ~D[2019-02-01], opts)

      # 1 month of h1 bars = 672 bars (28 days * 24 hours)
      assert length(bars) == 672
      assert_uniform_spacing bars, :timer.hours(1)

      # Second bar: [3600, 114482, 114425, 114377, 114489, 12105.65]
      b2 = Enum.at(bars, 1)
      assert b2.time == ~U[2019-02-01 01:00:00Z]
      assert b2.open == 1.14482
      assert b2.close == 1.14425
      assert b2.low == 1.14377
      assert b2.high == 1.14489
      assert_in_delta b2.volume, 12_105.65, 0.01
    end
  end

  describe "fetch/4 daily bars parsing" do
    test "parses first d1 bar with exact values" do
      opts = TestFixtures.stub_dukascopy(:bar_d1_exact)

      {:ok, bars} = BarData.fetch("EUR/USD", :day, ~D[2019-06-15], opts)
      [first | _] = bars

      # First d1 bar from BID_candles_day_1.bi5: [0, 114598, 114612, 114566, 114676, 11818.90]
      assert first.time == ~U[2019-01-01 00:00:00Z]
      assert first.open == 1.14598
      assert first.close == 1.14612
      assert first.low == 1.14566
      assert first.high == 1.14676
      assert_in_delta first.volume, 11_818.90, 0.01
    end

    test "parses multiple d1 bars in correct order" do
      opts = TestFixtures.stub_dukascopy(:bar_d1_order)

      {:ok, bars} = BarData.fetch("EUR/USD", :day, ~D[2019-06-15], opts)

      # 1 year of d1 bars = 365 bars
      assert length(bars) == 365
      assert_uniform_spacing bars, :timer.hours(24)

      # Second bar: [86400, 114612, 113121, 113092, 114967, 455444.66]
      b2 = Enum.at(bars, 1)
      assert b2.time == ~U[2019-01-02 00:00:00Z]
      assert b2.open == 1.14612
      assert b2.close == 1.13121
      assert b2.low == 1.13092
      assert b2.high == 1.14967
      assert_in_delta b2.volume, 455_444.66, 0.1
    end
  end

  describe "fetch/4 point_value option" do
    test "respects custom point_value" do
      opts = TestFixtures.stub_dukascopy(:bar_point_value)

      # With custom point_value = 10, raw value 114543 becomes 11454.3
      {:ok, bars} =
        BarData.fetch("EUR/USD", :minute, ~D[2019-02-04], Keyword.merge(opts, point_value: 10))

      [first | _] = bars

      assert first.open == 11_454.3
      assert first.close == 11_456.9
      assert first.low == 11_454.2
      assert first.high == 11_457.0
    end
  end

  describe "fetch/4 edge cases" do
    test "returns empty list for 404 (no data)" do
      opts = TestFixtures.stub_dukascopy(:bar_404)

      assert {:ok, []} = BarData.fetch("EUR/USD", :minute, ~D[2000-01-01], opts)
    end
  end

  describe "fetch!/4" do
    test "raises on unknown instrument" do
      assert_raise RuntimeError, ~r/unknown_instrument/, fn ->
        BarData.fetch!("UNKNOWN", :minute, ~D[2024-11-15])
      end
    end

    test "returns bars on success with correct values" do
      opts = TestFixtures.stub_dukascopy(:bar_bang)

      bars = BarData.fetch!("EUR/USD", :minute, ~D[2019-02-04], opts)
      [first | _] = bars

      assert first.open == 1.14543
      assert first.high == 1.14570
    end
  end

  describe "fetch/4 with :mid price_type" do
    test "returns minute bars with averaged OHLC values" do
      opts = TestFixtures.stub_dukascopy(:bar_mid_minute)

      {:ok, bars} =
        BarData.fetch(
          "EUR/USD",
          :minute,
          ~D[2019-02-04],
          Keyword.put(opts, :price_type, :mid)
        )

      [first | _] = bars

      # mid = (bid + ask) / 2
      # BID: open=1.14543, high=1.1457, low=1.14542, close=1.14569
      # ASK: open=1.14545, high=1.14574, low=1.14545, close=1.14574
      assert first.time == ~U[2019-02-04 00:00:00Z]
      assert_in_delta first.open, 1.14544, 0.000001
      assert_in_delta first.high, 1.14572, 0.000001
      assert_in_delta first.low, 1.145435, 0.000001
      assert_in_delta first.close, 1.145715, 0.000001
    end

    test "returns minute bars with summed volumes" do
      opts = TestFixtures.stub_dukascopy(:bar_mid_minute_vol)

      {:ok, bars} =
        BarData.fetch(
          "EUR/USD",
          :minute,
          ~D[2019-02-04],
          Keyword.put(opts, :price_type, :mid)
        )

      [first | _] = bars

      # BID vol: 293.76, ASK vol: 401.87
      assert_in_delta first.volume, 695.63, 0.01
    end

    test "returns hour bars with averaged OHLC values" do
      opts = TestFixtures.stub_dukascopy(:bar_mid_hour)

      {:ok, bars} =
        BarData.fetch(
          "EUR/USD",
          :hour,
          ~D[2019-02-01],
          Keyword.put(opts, :price_type, :mid)
        )

      [first | _] = bars

      # BID: open=1.14482, high=1.14499, low=1.14462, close=1.14481
      # ASK: open=1.14485, high=1.14503, low=1.14466, close=1.14486
      assert first.time == ~U[2019-02-01 00:00:00Z]
      assert_in_delta first.open, 1.144835, 0.000001
      assert_in_delta first.high, 1.14501, 0.000001
      assert_in_delta first.low, 1.14464, 0.000001
      assert_in_delta first.close, 1.144835, 0.000001
    end

    test "returns day bars with averaged OHLC values" do
      opts = TestFixtures.stub_dukascopy(:bar_mid_day)

      {:ok, bars} =
        BarData.fetch(
          "EUR/USD",
          :day,
          ~D[2019-01-01],
          Keyword.put(opts, :price_type, :mid)
        )

      [first | _] = bars

      # BID: open=1.14598, high=1.14676, low=1.14566, close=1.14612
      # ASK: open=1.14682, high=1.14691, low=1.14611, close=1.14616
      assert first.time == ~U[2019-01-01 00:00:00Z]
      assert_in_delta first.open, 1.1464, 0.000001
      assert_in_delta first.high, 1.146835, 0.000001
      assert_in_delta first.low, 1.145885, 0.000001
      assert_in_delta first.close, 1.14614, 0.000001
    end
  end
end

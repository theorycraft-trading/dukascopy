defmodule Dukascopy.TickDataTest do
  use ExUnit.Case, async: true

  import Dukascopy.TestAssertions

  alias Dukascopy.TestFixtures
  alias Dukascopy.TickData

  ## Tests

  describe "fetch/4 validation" do
    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               TickData.fetch("UNKNOWN", ~D[2024-11-15], 10)
    end
  end

  describe "fetch/4 tick parsing" do
    test "parses first tick with exact values" do
      opts = TestFixtures.stub_dukascopy(:tick_parsing_exact)

      {:ok, ticks} = TickData.fetch("EUR/USD", ~D[2019-02-04], 0, opts)
      [first | _] = ticks

      # First tick from 00h_ticks.bi5: [994, 114545, 114543, 1, 2.059999942779541]
      # Base time: 2019-02-04 00:00:00.000 UTC + 994ms
      assert first.time == ~U[2019-02-04 00:00:00.994Z]
      assert first.ask == 1.14545
      assert first.bid == 1.14543
      assert first.ask_volume == 1.0
      assert_in_delta first.bid_volume, 2.06, 0.01
    end

    test "parses multiple ticks in correct order" do
      opts = TestFixtures.stub_dukascopy(:tick_parsing_order)

      {:ok, ticks} = TickData.fetch("EUR/USD", ~D[2019-02-04], 0, opts)

      # Hour 0 of 2019-02-04 contains 3733 ticks
      assert length(ticks) == 3733
      assert_chronological_order ticks

      # Second tick: [1271, 114546, 114544, 1, 1]
      t2 = Enum.at(ticks, 1)
      assert t2.time == ~U[2019-02-04 00:00:01.271Z]
      assert t2.ask == 1.14546
      assert t2.bid == 1.14544
      assert t2.ask_volume == 1.0
      assert t2.bid_volume == 1.0

      # Third tick: [1464, 114545, 114542, 1, 8.35]
      t3 = Enum.at(ticks, 2)
      assert t3.time == ~U[2019-02-04 00:00:01.464Z]
      assert t3.ask == 1.14545
      assert t3.bid == 1.14542
      assert t3.ask_volume == 1.0
      assert_in_delta t3.bid_volume, 8.35, 0.01
    end

    test "parses ticks for different hours" do
      opts = TestFixtures.stub_dukascopy(:tick_hours)

      # Hour 10
      {:ok, ticks_h10} = TickData.fetch("EUR/USD", ~D[2019-02-04], 10, opts)
      [first_h10 | _] = ticks_h10
      assert first_h10.time.hour == 10

      # Hour 23
      {:ok, ticks_h23} = TickData.fetch("EUR/USD", ~D[2019-02-04], 23, opts)
      [first_h23 | _] = ticks_h23
      assert first_h23.time.hour == 23
    end

    test "respects point_value option" do
      opts = TestFixtures.stub_dukascopy(:tick_point_value)

      # With custom point_value = 10, raw value 114545 becomes 11454.5
      {:ok, ticks} =
        TickData.fetch(
          "EUR/USD",
          ~D[2019-02-04],
          0,
          Keyword.merge(opts, point_value: 10)
        )

      [first | _] = ticks

      assert first.ask == 11_454.5
      assert first.bid == 11_454.3
    end
  end

  describe "fetch/4 edge cases" do
    test "returns empty list for 404 (no data)" do
      opts = TestFixtures.stub_dukascopy(:tick_404)

      assert {:ok, []} = TickData.fetch("EUR/USD", ~D[2000-01-01], 0, opts)
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
      assert [_ | _] = ticks
      assert hd(ticks).ask == 1.14545
    end
  end
end

defmodule Dukascopy.InstrumentsTest do
  use ExUnit.Case, async: true

  alias Dukascopy.Instruments

  ## Tests

  doctest Dukascopy.Instruments

  describe "asset group helpers" do
    test "returns index instruments" do
      assert "USA30.IDX/USD" in Instruments.indices()
      assert "USATECH.IDX/USD" in Instruments.indices()
    end

    test "returns crypto instruments" do
      assert "BTC/USD" in Instruments.crypto()
      assert "ETH/USD" in Instruments.crypto()
    end
  end

  describe "get_history_start/2" do
    test "returns the earliest native tick history timestamp" do
      assert {:ok, ~U[2007-01-01 00:00:05.163Z]} =
               Instruments.get_history_start("EUR/USD", :tick)
    end

    test "returns the earliest native minute history timestamp" do
      assert {:ok, ~U[2007-01-01 00:00:00.000Z]} =
               Instruments.get_history_start("EUR/USD", :minute)
    end

    test "normalizes second-based minute history metadata" do
      assert {:ok, ~U[2013-10-12 22:00:00.000Z]} =
               Instruments.get_history_start("BRENT.CMD/USD", :minute)
    end

    test "returns the earliest native hour history timestamp" do
      assert {:ok, ~U[2003-05-04 19:00:00.000Z]} =
               Instruments.get_history_start("EUR/USD", :hour)
    end

    test "uses the hour history start for day data" do
      assert Instruments.get_history_start("EUR/USD", :hour) ==
               Instruments.get_history_start("EUR/USD", :day)
    end

    test "returns an error for unknown instruments" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               Instruments.get_history_start("UNKNOWN", :minute)
    end

    test "returns an error for unsupported granularities" do
      assert {:error, {:unsupported_granularity, :m5}} =
               Instruments.get_history_start("EUR/USD", :m5)
    end
  end

  describe "get_history_start!/2" do
    test "returns the history start timestamp" do
      assert ~U[2007-01-01 00:00:05.163Z] =
               Instruments.get_history_start!("EUR/USD", :tick)
    end

    test "raises for unknown instruments" do
      assert_raise ArgumentError, "unknown instrument: UNKNOWN", fn ->
        Instruments.get_history_start!("UNKNOWN", :minute)
      end
    end

    test "raises for unsupported granularities" do
      assert_raise ArgumentError, "unsupported granularity: :m5", fn ->
        Instruments.get_history_start!("EUR/USD", :m5)
      end
    end
  end
end

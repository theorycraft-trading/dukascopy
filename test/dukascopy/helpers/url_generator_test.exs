defmodule Dukascopy.Helpers.UrlGeneratorTest do
  use ExUnit.Case, async: true

  alias Dukascopy.Helpers.UrlGenerator

  ## Tick URL tests

  describe "generate_urls/5 for ticks" do
    test "generates 26 hourly URLs across two days" do
      from = ~U[2019-06-22 16:00:00Z]
      to = ~U[2019-06-23 18:00:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :ticks, from, to)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/16h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/17h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/18h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/19h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/20h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/21h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/22h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/23h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/00h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/01h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/02h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/03h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/04h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/05h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/06h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/07h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/08h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/09h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/10h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/11h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/12h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/13h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/14h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/15h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/16h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/23/17h_ticks.bi5"
             ]
    end

    test "handles month boundary transition" do
      from = ~U[2019-06-30 23:59:00Z]
      to = ~U[2019-07-01 00:01:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/CAD", :ticks, from, to)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURCAD/2019/05/30/23h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURCAD/2019/06/01/00h_ticks.bi5"
             ]
    end
  end

  ## M1 (minute bar) URL tests

  describe "generate_urls/5 for minute bars" do
    test "generates 7 daily URLs for a week" do
      from = ~U[2019-03-02 00:00:00Z]
      to = ~U[2019-03-09 00:00:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("GBP/USD", :minute, from, to, price_type: :bid)

      assert urls == [
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/02/BID_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/03/BID_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/04/BID_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/05/BID_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/06/BID_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/07/BID_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/GBPUSD/2019/02/08/BID_candles_min_1.bi5"
             ]
    end

    test "generates daily URLs with ASK price type" do
      from = ~U[2019-05-19 12:00:00Z]
      to = ~U[2019-05-22 14:30:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/CAD", :minute, from, to, price_type: :ask)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURCAD/2019/04/19/ASK_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/EURCAD/2019/04/20/ASK_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/EURCAD/2019/04/21/ASK_candles_min_1.bi5",
               "#{UrlGenerator.base_url()}/EURCAD/2019/04/22/ASK_candles_min_1.bi5"
             ]
    end

    test "generates 1 URL for same day range" do
      from = ~U[2019-05-19 12:11:00Z]
      to = ~U[2019-05-19 12:19:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/CAD", :minute, from, to, price_type: :ask)

      assert urls == ["#{UrlGenerator.base_url()}/EURCAD/2019/04/19/ASK_candles_min_1.bi5"]
    end
  end

  ## H1 (hourly bar) URL tests

  describe "generate_urls/5 for hourly bars" do
    test "generates 4 monthly URLs for 4 months" do
      from = ~U[2019-01-01 00:00:00Z]
      to = ~U[2019-05-01 00:00:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :hour, from, to, price_type: :bid)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2019/00/BID_candles_hour_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/01/BID_candles_hour_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/02/BID_candles_hour_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/03/BID_candles_hour_1.bi5"
             ]
    end

    test "generates URLs across year boundary" do
      from = ~U[2018-12-01 00:00:00Z]
      to = ~U[2019-03-01 00:00:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :hour, from, to, price_type: :bid)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2018/11/BID_candles_hour_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/00/BID_candles_hour_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/01/BID_candles_hour_1.bi5"
             ]
    end
  end

  ## D1 (daily bar) URL tests

  describe "generate_urls/5 for daily bars" do
    test "generates 2 yearly URLs for 2 years" do
      from = ~U[2017-12-08 00:00:00Z]
      to = ~U[2018-05-22 00:00:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :day, from, to, price_type: :bid)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2017/BID_candles_day_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2018/BID_candles_day_1.bi5"
             ]
    end

    test "generates yearly URLs with ASK price type" do
      from = ~U[2015-01-01 00:00:00Z]
      to = ~U[2019-01-01 00:00:00Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :day, from, to, price_type: :ask)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2015/ASK_candles_day_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2016/ASK_candles_day_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2017/ASK_candles_day_1.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2018/ASK_candles_day_1.bi5"
             ]
    end
  end

  ## Validation tests

  describe "generate_urls/5 validation" do
    test "returns error for unknown instrument" do
      from = ~U[2019-01-01 00:00:00Z]
      to = ~U[2019-01-02 00:00:00Z]

      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               UrlGenerator.generate_urls("UNKNOWN", :ticks, from, to)
    end
  end

  ## build_tick_url/3 tests

  describe "build_tick_url/3" do
    test "builds correct URL for EUR/USD" do
      {:ok, url} = UrlGenerator.build_tick_url("EUR/USD", ~D[2019-06-22], 16)
      assert url == "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/16h_ticks.bi5"
    end

    test "builds correct URL for hour 0" do
      {:ok, url} = UrlGenerator.build_tick_url("EUR/USD", ~D[2019-01-01], 0)
      assert url == "#{UrlGenerator.base_url()}/EURUSD/2019/00/01/00h_ticks.bi5"
    end

    test "builds correct URL for hour 23" do
      {:ok, url} = UrlGenerator.build_tick_url("EUR/USD", ~D[2019-12-31], 23)
      assert url == "#{UrlGenerator.base_url()}/EURUSD/2019/11/31/23h_ticks.bi5"
    end
  end

  ## build_bar_url/4 tests

  describe "build_bar_url/4" do
    test "builds correct minute bar URL with BID" do
      {:ok, url} =
        UrlGenerator.build_bar_url("GBP/USD", :minute, ~D[2019-03-02], price_type: :bid)

      assert url == "#{UrlGenerator.base_url()}/GBPUSD/2019/02/02/BID_candles_min_1.bi5"
    end

    test "builds correct minute bar URL with ASK" do
      {:ok, url} =
        UrlGenerator.build_bar_url("EUR/CAD", :minute, ~D[2019-05-19], price_type: :ask)

      assert url == "#{UrlGenerator.base_url()}/EURCAD/2019/04/19/ASK_candles_min_1.bi5"
    end

    test "builds correct hourly bar URL" do
      {:ok, url} = UrlGenerator.build_bar_url("EUR/USD", :hour, ~D[2019-01-15], price_type: :bid)
      assert url == "#{UrlGenerator.base_url()}/EURUSD/2019/00/BID_candles_hour_1.bi5"
    end

    test "builds correct daily bar URL" do
      {:ok, url} = UrlGenerator.build_bar_url("BTC/USD", :day, ~D[2018-12-08], price_type: :bid)
      assert url == "#{UrlGenerator.base_url()}/BTCUSD/2018/BID_candles_day_1.bi5"
    end
  end

  ## UTC Offset tests

  describe "generate_urls/5 with utc_offset" do
    test "applies utc_offset to date range before generating URLs" do
      from = ~U[2019-06-22 16:00:00Z]
      to = ~U[2019-06-22 18:00:00Z]

      {:ok, urls} =
        UrlGenerator.generate_urls("EUR/USD", :ticks, from, to, utc_offset: ~T[01:00:00])

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/17h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2019/05/22/18h_ticks.bi5"
             ]
    end
  end

  ## Date Limiting tests

  describe "generate_urls/5 date limiting" do
    test "limits to date to current time to avoid future requests" do
      from = ~U[2024-01-01 00:00:00Z]
      to = ~U[2099-12-31 23:59:59Z]

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :day, from, to)

      # Should not generate URLs for 2099, only up to current year
      refute Enum.any?(urls, &String.contains?(&1, "2099"))
      assert Enum.any?(urls, &String.contains?(&1, "2024"))
    end
  end

  ## Timezone conversion tests

  describe "generate_urls/5 with timezone" do
    test "converts non-UTC datetime to UTC before generating URLs" do
      # 01/01/2024 10:00 Paris (UTC+1 winter) = 09:00 UTC
      {:ok, from_paris} = DateTime.new(~D[2024-01-01], ~T[10:00:00], "Europe/Paris")
      # 01/01/2024 12:00 Paris = 11:00 UTC
      {:ok, to_paris} = DateTime.new(~D[2024-01-01], ~T[12:00:00], "Europe/Paris")

      {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :ticks, from_paris, to_paris)

      assert urls == [
               "#{UrlGenerator.base_url()}/EURUSD/2024/00/01/09h_ticks.bi5",
               "#{UrlGenerator.base_url()}/EURUSD/2024/00/01/10h_ticks.bi5"
             ]
    end

    test "handles DST correctly - winter vs summer" do
      # Winter: 01/01/2024 10:00 Paris = 09:00 UTC (UTC+1)
      {:ok, winter} = DateTime.new(~D[2024-01-01], ~T[10:00:00], "Europe/Paris")
      # Summer: 01/07/2024 10:00 Paris = 08:00 UTC (UTC+2)
      {:ok, summer} = DateTime.new(~D[2024-07-01], ~T[10:00:00], "Europe/Paris")

      {:ok, winter_urls} =
        UrlGenerator.generate_urls("EUR/USD", :ticks, winter, DateTime.add(winter, 1, :hour))

      {:ok, summer_urls} =
        UrlGenerator.generate_urls("EUR/USD", :ticks, summer, DateTime.add(summer, 1, :hour))

      assert winter_urls == ["#{UrlGenerator.base_url()}/EURUSD/2024/00/01/09h_ticks.bi5"]
      assert summer_urls == ["#{UrlGenerator.base_url()}/EURUSD/2024/06/01/08h_ticks.bi5"]
    end
  end
end

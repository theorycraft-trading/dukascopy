defmodule Dukascopy.TestAssertions do
  @moduledoc false

  import ExUnit.Assertions

  ## Public API

  def assert_chronological_order([first | rest]) do
    for current <- rest, reduce: first do
      prev ->
        assert DateTime.compare(prev.time, current.time) == :lt,
               "Not chronological: #{prev.time} >= #{current.time}"

        current
    end
  end

  def assert_uniform_spacing([first | rest], expected_ms) do
    for current <- rest, reduce: first do
      prev ->
        diff_ms = DateTime.diff(current.time, prev.time, :millisecond)

        assert diff_ms == expected_ms,
               "Expected #{expected_ms}ms spacing, got #{diff_ms}ms between #{prev.time} and #{current.time}"

        current
    end
  end
end

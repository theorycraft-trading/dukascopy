defmodule Dukascopy.Cursor do
  @moduledoc false

  #
  # Cursor for paginated Dukascopy reads.
  #
  # The cursor identifies a position in the underlying source stream, not an
  # offset in the output stream. `source_time` is the timestamp of the next
  # source event to read. `source_skip` disambiguates multiple source events
  # with the same timestamp.
  #

  alias __MODULE__

  @enforce_keys [:source_time, :source_skip]
  defstruct [:source_time, :source_skip]

  @type t :: %Cursor{
          source_time: DateTime.t(),
          source_skip: non_neg_integer()
        }
end

defmodule Dukascopy.Enums do
  @moduledoc """
  Enumerations for Dukascopy.

  Uses SimpleEnum to generate types and validation macros.

  ## Generated types

    * `price_type_keys` - `:bid | :ask | :mid`
    * `volume_units_keys` - `:millions | :thousands | :units`
    * `granularity_keys` - `:ticks | :minute | :hour | :day`
    * `weekly_open_keys` - `:monday | :tuesday | ... | :sunday`

  ## Usage

      require Dukascopy.Enums, as: Enums

      # Validation (returns the key or raises)
      price_type = Enums.price_type(:bid, :key)  #=> :bid
      Enums.price_type(:invalid, :key)           #=> ** (ArgumentError)

      # Introspection
      Enums.price_type(:__keys__)  #=> [:bid, :ask, :mid]

  """

  import SimpleEnum, only: [defenum: 2]

  defenum :price_type, [:bid, :ask, :mid]
  defenum :volume_units, [:millions, :thousands, :units]
  defenum :granularity, [:ticks, :minute, :hour, :day]

  defenum :weekly_open, [
    :monday,
    :tuesday,
    :wednesday,
    :thursday,
    :friday,
    :saturday,
    :sunday
  ]
end

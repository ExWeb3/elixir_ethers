defmodule Elixirium.Types do
  @moduledoc "EVM types and compound type definitions"

  @typedoc """
  Ethereum address in its hex format with 0x

  Example: 0xdAC17F958D2ee523a2206206994597C13D831ec7
  """
  @type t_address :: <<_::336>>

  def to_elixir_type(type) do
    case type do
      :address ->
        quote do: Elixirium.Types.t_address()

      {:uint, _} ->
        quote do: non_neg_integer

      {:int, _} ->
        quote do: integer

      {:bytes, _} ->
        quote do: binary()

      :bytes ->
        quote do: binary()

      :bool ->
        quote do: boolean()

      {:array, sub_type} ->
        sub_type = to_elixir_type(sub_type)

        quote do
          [unquote(sub_type)]
        end
    end
  end
end

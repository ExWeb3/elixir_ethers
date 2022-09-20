defmodule Elixirium.Types do
  @moduledoc "EVM types and compound type definitions"

  require Logger

  @typedoc """
  Ethereum address in its hex format with 0x

  Example: 0xdAC17F958D2ee523a2206206994597C13D831ec7
  """
  @type t_address :: <<_::336>>

  @doc """
  Converts EVM data types to typespecs for documentation
  """
  def to_elixir_type(type) do
    case type do
      :address ->
        quote do: Elixirium.Types.t_address()

      {:array, sub_type, _element_count} ->
        to_elixir_type({:array, sub_type})

      {:array, sub_type} ->
        sub_type = to_elixir_type(sub_type)

        quote do
          [unquote(sub_type)]
        end

      {:bytes, size} ->
        quote do: <<_::unquote(size * 8)>>

      :bytes ->
        quote do: binary()

      :bool ->
        quote do: boolean()

      :function ->
        raise "Not implemented"

      {:fixed, _element_count, _precision} ->
        quote do: float()

      {:int, _} ->
        quote do: integer

      :string ->
        quote do: String.t()

      {:typle, sub_types} ->
        sub_types = Enum.map(sub_types, &to_elixir_type/1)

        quote do: unquote(sub_types)

      {:ufixed, _element_count, _precision} ->
        quote do: float()

      {:uint, _} ->
        quote do: non_neg_integer

      unknown ->
        Logger.warn("Unknown type #{inspect(unknown)}")
        quote do: term
    end
  end
end

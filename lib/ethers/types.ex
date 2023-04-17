defmodule Ethers.Types do
  @moduledoc "EVM types and compound type definitions"

  require Logger

  @typedoc """
  Ethereum address in its hex format with 0x

  Example: 0xdAC17F958D2ee523a2206206994597C13D831ec7
  """
  @type t_address :: <<_::336>>
  @typedoc """
  Ethereum transaction has in it's hex format with 0x

  Example: 0xd4288c8e733eb71a39fe2e8dd4912ce54d8d26d9874f30309b26b4b071260422
  """
  @type t_transaction_hash :: <<_::528>>

  @doc """
  Converts EVM data types to typespecs for documentation
  """
  def to_elixir_type(type) do
    case type do
      :address ->
        quote do: Ethers.Types.t_address()

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

      {:tuple, sub_types} ->
        sub_types = Enum.map(sub_types, &to_elixir_type/1)

        quote do: {unquote_splicing(sub_types)}

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

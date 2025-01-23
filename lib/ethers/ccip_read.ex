defmodule Ethers.CcipRead do
  @moduledoc """
  CCIP Read ([EIP-3668](https://eips.ethereum.org/EIPS/eip-3668)) implementation

  NOTE: Currently supports URLs with "https" scheme only
  """

  require Logger

  alias Ethers.Contracts.CcipRead.Errors.OffchainLookup
  alias Ethers.TxData
  alias Ethers.Utils

  @error_selector "0x556f1830"
  @error_selector_bin Utils.hex_decode!(@error_selector)
  @supported_schemas ["https"]

  @doc """
  Same as `Ethers.call/2` but will handle `Ethers.Contacts.CcipRead.Errors.OffchainLookup` errors
  and performs an offchain lookup as per [EIP-3668](https://eips.ethereum.org/EIPS/eip-3668) specs.

  ## Options and Overrides
  Accepts same options as `Ethers.call/2`
  """
  @spec call(TxData.t(), Keyword.t()) :: {:ok, [term()] | term()} | {:error, term()}
  def call(tx_data, opts) do
    case Ethers.call(tx_data, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, %_{} = error} ->
        if offchain_lookup_error?(error) do
          ccip_resolve(error, tx_data, opts)
        else
          {:error, error}
        end

      {:error, %{"data" => <<@error_selector, _::binary>> = error_data}} ->
        with {:ok, decoded_error} <- Utils.hex_decode(error_data),
             {:ok, lookup_error} <- OffchainLookup.decode(decoded_error) do
          ccip_resolve(lookup_error, tx_data, opts)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ccip_resolve(error, tx_data, opts) do
    with {:ok, data} <-
           error.urls
           |> Enum.filter(fn url ->
             url |> String.downcase() |> String.starts_with?(@supported_schemas)
           end)
           |> resolve_first(error) do
      data = ABI.TypeEncoder.encode([data, error.extra_data], [:bytes, :bytes])
      tx_data = %{tx_data | data: error.callback_function <> data}
      Ethers.call(tx_data, opts)
    end
  end

  defp resolve_first([], _), do: {:error, :ccip_read_failed}

  defp resolve_first([url | rest], error) do
    case do_resolve_single(url, error) do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} ->
        Logger.error("CCIP READ: failed resolving #{url} error: #{inspect(reason)}")

        resolve_first(rest, error)
    end
  end

  defp do_resolve_single(url_template, error) do
    sender = Ethers.Utils.hex_encode(error.sender)
    data = Ethers.Utils.hex_encode(error.call_data)

    req_opts =
      if String.contains?(url_template, "{data}") do
        [method: :get]
      else
        [method: :post, json: %{data: data, sender: sender}]
      end

    url = url_template |> String.replace("{sender}", sender) |> String.replace("{data}", data)
    req_opts = req_opts |> Keyword.put(:url, url) |> Keyword.merge(ccip_req_opts())

    Logger.debug("CCIP READ: trying #{url}")

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: 200, body: %{"data" => data}}} ->
        case Utils.hex_decode(data) do
          {:ok, hex} -> {:ok, hex}
          :error -> {:error, :hex_decode_failed}
        end

      {:ok, resp} ->
        {:error, resp}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp offchain_lookup_error?(%mod{}) do
    mod.function_selector().method_id == @error_selector_bin
  rescue
    UndefinedFunctionError ->
      false
  end

  defp ccip_req_opts do
    Application.get_env(:ethers, :ccip_req_opts, [])
  end
end

defmodule Ethers.CcipReadTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.CcipRead
  alias Ethers.Contract.Test.CcipReadTestContract
  alias Ethers.Utils

  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

  setup do
    address = deploy(CcipReadTestContract, from: @from)
    [address: address]
  end

  describe "call/2" do
    test "returns successful result when no offchain lookup is needed", %{address: address} do
      assert {:ok, "direct value"} =
               CcipReadTestContract.get_direct_value()
               |> CcipRead.call(to: address)
    end

    test "handles OffchainLookup error and performs offchain lookup", %{address: address} do
      Req.Test.expect(Ethers.CcipReq, fn conn ->
        assert ["ccip", sender, data] = conn.path_info

        # Verify the request parameters
        assert String.starts_with?(sender, "0x")
        assert String.starts_with?(data, "0x")

        Req.Test.json(conn, %{data: data})
      end)

      assert {:ok, 100} =
               CcipReadTestContract.get_value(100)
               |> CcipRead.call(to: address)
    end

    test "filters out non-https URLs from the lookup list", %{address: address} do
      # The contract provides both https and non-https URLs
      # Our implementation should only try the https ones
      Req.Test.expect(Ethers.CcipReq, fn conn ->
        assert conn.scheme == :https
        assert ["ccip", _sender, data] = conn.path_info
        Req.Test.json(conn, %{data: data})
      end)

      assert {:ok, 300} =
               CcipReadTestContract.get_value(300)
               |> CcipRead.call(to: address)
    end

    test "tries next URL when first URL fails", %{address: address} do
      # First request fails
      Req.Test.expect(Ethers.CcipReq, 2, fn conn ->
        if conn.host == "example.com" do
          conn
          |> Plug.Conn.put_status(500)
          |> Req.Test.json(%{data: "0x"})
        else
          # Second URL succeeds
          Req.Test.json(conn, %{
            data: ABI.TypeEncoder.encode([700], [{:uint, 256}]) |> Utils.hex_encode()
          })
        end
      end)

      assert {:ok, 700} =
               CcipReadTestContract.get_value(400)
               |> CcipRead.call(to: address)
    end

    test "returns error when all URLs fail", %{address: address} do
      # Both URLs fail
      Req.Test.stub(Ethers.CcipReq, fn conn ->
        Plug.Conn.put_status(conn, 500)
        |> Req.Test.text("Failed")
      end)

      assert {:error, :ccip_read_failed} =
               CcipReadTestContract.get_value(500)
               |> CcipRead.call(to: address)
    end

    test "returns error when response is not 200", %{address: address} do
      Req.Test.stub(Ethers.CcipReq, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{error: "Not found"})
      end)

      assert {:error, :ccip_read_failed} =
               CcipReadTestContract.get_value(600)
               |> CcipRead.call(to: address)
    end

    test "returns error when response body is invalid", %{address: address} do
      Req.Test.stub(Ethers.CcipReq, fn conn ->
        conn
        |> Plug.Conn.put_status(200)
        |> Req.Test.text("invalid json")
      end)

      assert {:error, :ccip_read_failed} =
               CcipReadTestContract.get_value(700)
               |> CcipRead.call(to: address)
    end

    test "returns error when hex decoding fails", %{address: address} do
      Req.Test.stub(Ethers.CcipReq, fn conn ->
        Req.Test.json(conn, %{data: "invalid hex"})
      end)

      assert {:error, :ccip_read_failed} =
               CcipReadTestContract.get_value(800)
               |> CcipRead.call(to: address)
    end

    test "returns original error when it's not an OffchainLookup error", %{address: address} do
      assert {:error, %Ethers.Contract.Test.CcipReadTestContract.Errors.InvalidValue{}} =
               CcipReadTestContract.get_value(0)
               |> CcipRead.call(to: address)

      # Sending value to a non-payable function should return the original error
      assert {:error, %{"code" => 3}} =
               CcipReadTestContract.get_value(1)
               |> CcipRead.call(to: address, value: 1000)
    end
  end
end

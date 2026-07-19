defmodule Ethers.SiweTest do
  use ExUnit.Case, async: true

  alias Ethers.Siwe
  alias Ethers.Siwe.Message

  doctest Ethers.Siwe

  @fixtures_path "test/support/fixtures/siwe"

  @valid_params [
    domain: "example.com",
    address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    statement: "Sign in to Example",
    uri: "https://example.com/login",
    chain_id: 1,
    nonce: "32891756",
    issued_at: "2021-09-30T16:25:24.000Z"
  ]

  defp fixture(name) do
    [@fixtures_path, name]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp fields_to_params(fields) do
    mapping = %{
      "scheme" => :scheme,
      "domain" => :domain,
      "address" => :address,
      "statement" => :statement,
      "uri" => :uri,
      "version" => :version,
      "chainId" => :chain_id,
      "nonce" => :nonce,
      "issuedAt" => :issued_at,
      "expirationTime" => :expiration_time,
      "notBefore" => :not_before,
      "requestId" => :request_id,
      "resources" => :resources
    }

    Map.new(fields, fn {key, value} -> {Map.fetch!(mapping, key), value} end)
  end

  describe "new/1" do
    test "builds a message from valid params" do
      assert {:ok, %Message{} = message} = Siwe.new(@valid_params)

      assert message.domain == "example.com"
      assert message.address == "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      assert message.statement == "Sign in to Example"
      assert message.uri == "https://example.com/login"
      assert message.version == "1"
      assert message.chain_id == 1
      assert message.nonce == "32891756"
      assert message.issued_at == "2021-09-30T16:25:24.000Z"
      assert message.expiration_time == nil
      assert message.not_before == nil
      assert message.request_id == nil
      assert message.resources == []
    end

    test "accepts a map with atom keys" do
      assert {:ok, %Message{domain: "example.com"}} = Siwe.new(Map.new(@valid_params))
    end

    test "checksums the address" do
      params = Keyword.put(@valid_params, :address, "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")

      assert {:ok, %Message{address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"}} =
               Siwe.new(params)
    end

    test "defaults issued_at to now" do
      params = Keyword.delete(@valid_params, :issued_at)

      assert {:ok, %Message{issued_at: issued_at}} = Siwe.new(params)
      assert {:ok, issued_at_dt, 0} = DateTime.from_iso8601(issued_at)
      assert DateTime.diff(DateTime.utc_now(), issued_at_dt) < 5
    end

    test "accepts DateTime values for timestamps" do
      params =
        Keyword.merge(@valid_params,
          issued_at: ~U[2021-09-30 16:25:24Z],
          expiration_time: ~U[2021-09-30 16:30:24.000Z],
          not_before: ~U[2021-09-30 16:20:24Z]
        )

      assert {:ok, %Message{} = message} = Siwe.new(params)
      assert message.issued_at == "2021-09-30T16:25:24Z"
      assert message.expiration_time == "2021-09-30T16:30:24.000Z"
      assert message.not_before == "2021-09-30T16:20:24Z"
    end

    test "accepts optional scheme, request_id and resources" do
      params =
        Keyword.merge(@valid_params,
          scheme: "https",
          request_id: "some_id",
          resources: ["ipfs://Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu"]
        )

      assert {:ok, %Message{} = message} = Siwe.new(params)
      assert message.scheme == "https"
      assert message.request_id == "some_id"
      assert message.resources == ["ipfs://Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu"]
    end

    test "returns error for missing required fields" do
      for {key, error} <- [
            domain: :missing_domain,
            address: :missing_address,
            uri: :missing_uri,
            chain_id: :missing_chain_id,
            nonce: :missing_nonce
          ] do
        params = Keyword.delete(@valid_params, key)
        assert {:error, ^error} = Siwe.new(params)
      end
    end

    test "returns error for invalid fields" do
      for {key, value, error} <- [
            {:domain, "#nope", :invalid_domain},
            {:domain, "example.com:", :invalid_domain},
            {:domain, 42, :invalid_domain},
            {:scheme, "1https", :invalid_scheme},
            {:scheme, 42, :invalid_scheme},
            {:address, "0x1234", :invalid_address},
            {:address, "not an address", :invalid_address},
            {:address, "0x" <> String.duplicate("zx", 20), :invalid_address},
            {:statement, "line\nbreak", :invalid_statement},
            {:statement, 42, :invalid_statement},
            {:uri, ":not_a_uri", :invalid_uri},
            {:uri, "no_scheme", :invalid_uri},
            {:version, "2", :invalid_version},
            {:chain_id, "one", :invalid_chain_id},
            {:chain_id, -1, :invalid_chain_id},
            {:nonce, "1234567", :invalid_nonce},
            {:nonce, "with spaces!", :invalid_nonce},
            {:nonce, 12_345_678, :invalid_nonce},
            {:issued_at, "Wed Oct 05 2011", :invalid_issued_at},
            {:issued_at, 42, :invalid_issued_at},
            {:expiration_time, "not-a-date", :invalid_expiration_time},
            {:not_before, "2021-13-40T00:00:00Z", :invalid_not_before},
            {:request_id, "new\nline", :invalid_request_id},
            {:request_id, 42, :invalid_request_id},
            {:resources, [":bad_uri"], :invalid_resources},
            {:resources, [42], :invalid_resources},
            {:resources, "not-a-list", :invalid_resources}
          ] do
        params = Keyword.put(@valid_params, key, value)
        assert {:error, ^error} = Siwe.new(params), "expected #{error} for #{key}"
      end
    end

    test "rejects reference negative object vectors" do
      # `missing version` and `missing issuedAt` are excluded: `new/1` deliberately defaults
      # those fields. `address not EIP-55` is excluded: `new/1` normalizes the address to its
      # checksummed form instead of rejecting (strict rejection applies to `parse/1`).
      excluded = ["missing version", "missing issuedAt", "address not EIP-55"]

      for {name, fields} <- fixture("parsing_negative_objects.json"), name not in excluded do
        params = fields_to_params(fields)
        assert {:error, _reason} = Siwe.new(params), "expected error for #{inspect(name)}"
      end
    end
  end

  describe "new!/1" do
    test "returns the message struct" do
      assert %Message{domain: "example.com"} = Siwe.new!(@valid_params)
    end

    test "raises on invalid params" do
      assert_raise ArgumentError, ~r/invalid_nonce/, fn ->
        Siwe.new!(Keyword.put(@valid_params, :nonce, "short"))
      end
    end
  end

  describe "generate_nonce/0" do
    test "generates alphanumeric nonces of at least 8 characters" do
      for _ <- 1..100 do
        nonce = Siwe.generate_nonce()
        assert nonce =~ ~r/^[a-zA-Z0-9]{8,}$/
      end
    end

    test "generates unique nonces" do
      nonces = for _ <- 1..100, do: Siwe.generate_nonce()
      assert length(Enum.uniq(nonces)) == 100
    end
  end

  describe "to_message/1" do
    test "renders a message with all fields" do
      message =
        Siwe.new!(
          scheme: "https",
          domain: "example.com",
          address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
          statement: "Sign in to Example",
          uri: "https://example.com/login",
          chain_id: 1,
          nonce: "32891756",
          issued_at: "2021-09-30T16:25:24.000Z",
          expiration_time: "2021-10-30T16:25:24.000Z",
          not_before: "2021-09-29T16:25:24.000Z",
          request_id: "some_id",
          resources: [
            "ipfs://Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu",
            "https://example.com/claim.json"
          ]
        )

      assert Siwe.to_message(message) == """
             https://example.com wants you to sign in with your Ethereum account:
             0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

             Sign in to Example

             URI: https://example.com/login
             Version: 1
             Chain ID: 1
             Nonce: 32891756
             Issued At: 2021-09-30T16:25:24.000Z
             Expiration Time: 2021-10-30T16:25:24.000Z
             Not Before: 2021-09-29T16:25:24.000Z
             Request ID: some_id
             Resources:
             - ipfs://Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu
             - https://example.com/claim.json\
             """
    end

    test "renders a message without optional fields" do
      message = Siwe.new!(Keyword.delete(@valid_params, :statement))

      assert Siwe.to_message(message) == """
             example.com wants you to sign in with your Ethereum account:
             0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2


             URI: https://example.com/login
             Version: 1
             Chain ID: 1
             Nonce: 32891756
             Issued At: 2021-09-30T16:25:24.000Z\
             """
    end

    test "implements String.Chars" do
      message = Siwe.new!(@valid_params)
      assert to_string(message) == Siwe.to_message(message)
    end
  end

  describe "parse/1" do
    test "parses and round-trips the reference positive vectors" do
      for {name, %{"message" => raw, "fields" => fields}} <- fixture("parsing_positive.json") do
        assert {:ok, %Message{} = message} = Siwe.parse(raw), "failed to parse #{inspect(name)}"

        assert Siwe.to_message(message) == raw, "round-trip failed for #{inspect(name)}"

        for {key, expected} <- fields_to_params(fields) do
          assert Map.fetch!(message, key) == expected,
                 "field #{key} mismatch for #{inspect(name)}"
        end
      end
    end

    test "rejects the reference negative vectors" do
      for {name, raw} <- fixture("parsing_negative.json") do
        assert {:error, _reason} = Siwe.parse(raw), "expected error for #{inspect(name)}"
      end
    end

    test "rejects truncated messages" do
      header = "example.com wants you to sign in with your Ethereum account:"
      address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

      assert {:error, :invalid_message_format} = Siwe.parse(header)
      assert {:error, :invalid_message_format} = Siwe.parse("#{header}\n#{address}\n\n")
      assert {:error, :invalid_message_format} = Siwe.parse("#{header}\n#{address}\n\n\n")
      assert {:error, :invalid_message_format} = Siwe.parse("not a siwe message")
    end

    test "rejects messages with trailing newline" do
      message = Siwe.new!(@valid_params)
      assert {:error, _reason} = Siwe.parse(Siwe.to_message(message) <> "\n")
    end

    test "rejects non-checksummed addresses" do
      raw =
        @valid_params
        |> Siwe.new!()
        |> Siwe.to_message()
        |> String.replace(
          "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
          "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        )

      assert {:error, :invalid_address} = Siwe.parse(raw)
    end

    test "round-trips a message built with new!/1" do
      message =
        Siwe.new!(
          Keyword.merge(@valid_params,
            expiration_time: "2021-10-30T16:25:24Z",
            resources: ["https://example.com/claim.json"]
          )
        )

      assert {:ok, parsed} = message |> Siwe.to_message() |> Siwe.parse()
      assert parsed == message
    end
  end

  describe "validate/2" do
    setup do
      message =
        Siwe.new!(
          Keyword.merge(@valid_params,
            not_before: "2021-09-30T16:00:00Z",
            expiration_time: "2021-09-30T17:00:00Z"
          )
        )

      %{message: message}
    end

    test "returns :ok for a valid message", %{message: message} do
      assert :ok =
               Siwe.validate(message,
                 domain: "example.com",
                 nonce: "32891756",
                 address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
                 time: ~U[2021-09-30 16:30:00Z]
               )
    end

    test "returns :ok without match options", %{message: message} do
      assert :ok = Siwe.validate(message, time: ~U[2021-09-30 16:30:00Z])
    end

    test "defaults time to now" do
      message = Siwe.new!(@valid_params)
      assert :ok = Siwe.validate(message)
    end

    test "expiration time is exclusive", %{message: message} do
      assert {:error, :expired} = Siwe.validate(message, time: ~U[2021-09-30 17:00:00Z])
      assert {:error, :expired} = Siwe.validate(message, time: ~U[2021-09-30 18:00:00Z])
      assert :ok = Siwe.validate(message, time: ~U[2021-09-30 16:59:59Z])
    end

    test "not before is inclusive", %{message: message} do
      assert {:error, :not_yet_valid} = Siwe.validate(message, time: ~U[2021-09-30 15:59:59Z])
      assert :ok = Siwe.validate(message, time: ~U[2021-09-30 16:00:00Z])
    end

    test "detects domain mismatch", %{message: message} do
      assert {:error, :domain_mismatch} =
               Siwe.validate(message, domain: "evil.com", time: ~U[2021-09-30 16:30:00Z])
    end

    test "detects scheme mismatch", %{message: message} do
      assert {:error, :scheme_mismatch} =
               Siwe.validate(message, scheme: "https", time: ~U[2021-09-30 16:30:00Z])

      https_message = %{message | scheme: "https"}

      assert :ok =
               Siwe.validate(https_message, scheme: "https", time: ~U[2021-09-30 16:30:00Z])

      assert {:error, :scheme_mismatch} =
               Siwe.validate(https_message, scheme: "http", time: ~U[2021-09-30 16:30:00Z])
    end

    test "detects nonce mismatch", %{message: message} do
      assert {:error, :nonce_mismatch} =
               Siwe.validate(message, nonce: "12341234", time: ~U[2021-09-30 16:30:00Z])
    end

    test "compares addresses case-insensitively", %{message: message} do
      assert :ok =
               Siwe.validate(message,
                 address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
                 time: ~U[2021-09-30 16:30:00Z]
               )
    end

    test "detects address mismatch", %{message: message} do
      assert {:error, :address_mismatch} =
               Siwe.validate(message,
                 address: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
                 time: ~U[2021-09-30 16:30:00Z]
               )
    end

    test "rejects invalid expected address", %{message: message} do
      assert {:error, :invalid_address} =
               Siwe.validate(message, address: "nope", time: ~U[2021-09-30 16:30:00Z])

      assert {:error, :invalid_address} =
               Siwe.validate(message,
                 address: "0x" <> String.duplicate("zx", 20),
                 time: ~U[2021-09-30 16:30:00Z]
               )
    end

    test "rejects unsupported versions" do
      %Message{} = message = Siwe.new!(@valid_params)
      assert {:error, :invalid_version} = Siwe.validate(%Message{message | version: "2"})
    end

    test "rejects unparseable timestamps in the struct" do
      %Message{} = message = Siwe.new!(@valid_params)

      assert {:error, :invalid_expiration_time} =
               Siwe.validate(%Message{message | expiration_time: "not-a-date"})

      assert {:error, :invalid_not_before} =
               Siwe.validate(%Message{message | not_before: "not-a-date"})
    end
  end
end

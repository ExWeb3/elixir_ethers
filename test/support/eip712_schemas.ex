defmodule Ethers.Support.EIP712.Person do
  @moduledoc false
  # Example EIP-712 schema used by the `Ethers.TypedData.Schema` moduledoc doctest.
  use Ethers.TypedData.Schema

  typed_schema "Person" do
    field(:name, :string)
    field(:wallet, :address)
  end
end

defmodule Ethers.Support.EIP712.Mail do
  @moduledoc false
  # Example EIP-712 schema used by the `Ethers.TypedData.Schema` moduledoc doctest.
  use Ethers.TypedData.Schema

  alias Ethers.Support.EIP712.Person

  typed_schema "Mail" do
    field(:from, Person)
    field(:to, Person)
    field(:contents, :string)
  end
end

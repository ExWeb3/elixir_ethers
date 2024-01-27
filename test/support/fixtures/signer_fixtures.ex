defmodule Ethers.SignerFixtures do
  @moduledoc """
  This module defines fixtures for Signers.
  """

  def kms_public_key_response do
    {:ok,
     %{
       "PublicKey" =>
         "MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEsdTvgjvTDk/BF/COdU/4/v6HgCaceKifvcBfxKnZpCt5wFzZEgwWSLTsz1T9YaCaS0Xb0D0g7TaT8VAD+Tesmg=="
     }}
  end

  def kms_sign_response do
    {:ok,
     %{
       "Signature" =>
         "MEUCIDK6M5izIjRFuFiEniddbbsaZwjzBbsrjEJxQ/kjm7m+AiEArAX1ZsnrEthrafd+uH2PeEQ+VAN08CH/pxzG/UV2KFw="
     }}
  end
end

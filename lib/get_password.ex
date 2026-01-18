defmodule GetPassword do
  @moduledoc """
  Implement secure / sane password reading.
  """
  use Rustler, otp_app: :get_password, crate: "get_password"

  @default_prompt "Password: "
  @flush_delay 50

  @reader :user_drv_reader

  @doc """
  Does exactly what you think it does.  Gets a password without echoing it.

  Accepts a string prompt as its sole parameter.
  Returns an `:ok` tuple when successful or an `:error` tuple if it fails.
  """
  def get_password(prompt \\ @default_prompt) do
    disable_reader()
    :timer.sleep(@flush_delay)

    try do
      read_password(prompt)
    after
      enable_reader()
    end
  end

  @doc """
  Works the same as `get_password/*`, except for return value.

  Success returns the password string.
  Failure raises an exception.
  """
  def get_password!(prompt \\ @default_prompt) do
    case get_password(prompt) do
      {:ok, pw} ->
        pw

      {:error, reason} ->
        raise RuntimeError, "unexpected error (#{inspect(reason)}) reading password"
    end
  end

  # Rust NIF to do the heavy-lifting
  defp read_password(_prompt), do: :erlang.nif_error(:nif_not_loaded)

  # helper functions used to ensure sane console behavior
  defp disable_reader() do
    call(@reader, :disable)
  end

  defp enable_reader() do
    call(@reader, :enable)
  end

  defp call(pid, msg) do
    ref = Process.monitor(pid, alias: :reply_demonitor)
    Process.send(pid, {ref, msg}, [])

    receive do
      {^ref, reply} ->
        {:ok, reply}

      {:DOWN, ^ref, _, _, reason} ->
        {:error, reason}
    end
  end
end

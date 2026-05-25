defmodule Scout.AuthTokens do
  @moduledoc """
  File-backed access tokens for Scout's management UI.

  Tokens live beside `settings.yaml` in `auth.txt`. The file is generated on
  first use and is intentionally separate from application config.
  """

  import Bitwise

  @token_count 10
  @token_bytes 32
  @filename "auth.txt"

  @doc """
  Returns the expected `auth.txt` path.
  """
  def path do
    Scout.Settings.settings_path()
    |> Path.dirname()
    |> Path.join(@filename)
  end

  @doc """
  Creates `auth.txt` with generated tokens when it does not already exist.

  Existing files are never overwritten so local token rotation and revocation
  remain under operator control.
  """
  def ensure_file! do
    path = path()

    case File.stat(path) do
      {:ok, _stat} ->
        path

      {:error, :enoent} ->
        write_new_file!(path)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read", path: path
    end
  end

  @doc """
  Returns active tokens from `auth.txt`.

  Blank lines and lines beginning with `#` are ignored.
  """
  def tokens do
    ensure_file!()
    |> File.stream!([], :line)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&ignored_line?/1)
  end

  @doc """
  Checks whether a candidate token is present in `auth.txt`.
  """
  def valid_token?(token) when is_binary(token) do
    candidate = String.trim(token)

    candidate != "" and Enum.any?(tokens(), &secure_compare(candidate, &1))
  end

  def valid_token?(_token), do: false

  defp write_new_file!(path) do
    File.mkdir_p!(Path.dirname(path))

    content = [
      "# Scout management UI access tokens\n",
      "# Keep this file on the device. One token per line; remove a line to revoke it.\n",
      "\n",
      Enum.map_join(1..@token_count, "\n", fn _index -> generate_token() end),
      "\n"
    ]

    case File.write(path, content, [:exclusive]) do
      :ok -> path
      {:error, :eexist} -> path
      {:error, reason} -> raise File.Error, reason: reason, action: "write", path: path
    end
  end

  defp generate_token do
    "scout_" <> Base.url_encode64(:crypto.strong_rand_bytes(@token_bytes), padding: false)
  end

  defp ignored_line?(""), do: true
  defp ignored_line?("#" <> _comment), do: true
  defp ignored_line?(_line), do: false

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    left
    |> :crypto.exor(right)
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn byte, acc -> bor(byte, acc) end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false
end

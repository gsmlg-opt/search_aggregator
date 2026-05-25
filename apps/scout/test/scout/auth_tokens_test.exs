defmodule Scout.AuthTokensTest do
  use ExUnit.Case, async: false

  setup do
    previous_settings_path = Application.fetch_env!(:scout, :settings_path)
    tmp_dir = Path.join(System.tmp_dir!(), "scout-auth-#{System.unique_integer([:positive])}")
    settings_path = Path.join(tmp_dir, "settings.yaml")

    File.mkdir_p!(tmp_dir)
    File.write!(settings_path, "general:\n  instance_name: Test Scout\n")
    Application.put_env(:scout, :settings_path, settings_path)

    on_exit(fn ->
      Application.put_env(:scout, :settings_path, previous_settings_path)
      File.rm_rf!(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  test "ensure_file! creates auth.txt with ten generated tokens", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "auth.txt")

    assert Scout.AuthTokens.ensure_file!() == path
    assert File.exists?(path)

    tokens = Scout.AuthTokens.tokens()

    assert length(tokens) == 10
    assert Enum.uniq(tokens) == tokens
    assert Enum.all?(tokens, &String.match?(&1, ~r/\Ascout_[A-Za-z0-9_-]{43}\z/))
  end

  test "ensure_file! preserves an existing auth.txt", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "auth.txt")
    existing = "first-token\nsecond-token\n"

    File.write!(path, existing)

    assert Scout.AuthTokens.ensure_file!() == path
    assert File.read!(path) == existing
  end

  test "valid_token? accepts uncommented file tokens only", %{tmp_dir: tmp_dir} do
    Path.join(tmp_dir, "auth.txt")
    |> File.write!("# Scout tokens\n\nvalid-token\n  another-valid-token  \n")

    assert Scout.AuthTokens.valid_token?("valid-token")
    assert Scout.AuthTokens.valid_token?("another-valid-token")
    refute Scout.AuthTokens.valid_token?("missing-token")
    refute Scout.AuthTokens.valid_token?("")
    refute Scout.AuthTokens.valid_token?(nil)
  end
end

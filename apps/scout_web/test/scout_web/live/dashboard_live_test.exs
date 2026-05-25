defmodule ScoutWeb.DashboardLiveTest do
  use ScoutWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Scout.Fetch.Result
  alias Scout.Server.ResultHandler

  setup do
    {tmp_dir, token} = prepare_auth_file()

    reset_job_manager()

    previous_publisher = Application.get_env(:scout_server, :job_publisher)
    Application.put_env(:scout_server, :job_publisher, __MODULE__.Publisher)

    on_exit(fn ->
      restore_env(:job_publisher, previous_publisher)
      File.rm_rf!(tmp_dir)
      reset_job_manager()
    end)

    %{token: token}
  end

  test "renders the Scout dashboard", %{conn: conn, token: token} do
    conn = log_in(conn, token)

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#fetch-form")
    assert has_element?(view, "#jobs")
    assert has_element?(view, "#agents")
  end

  test "renders completed fetch content in a DuskMoon markdown modal", %{conn: conn, token: token} do
    Phoenix.PubSub.subscribe(Scout.PubSub, "scout:jobs")

    assert {:ok, %{job_id: job_id}} =
             Scout.Server.submit_fetch(%{"url" => "https://example.com/docs"})

    assert_job_status(job_id, "completed")

    conn = log_in(conn, token)
    {:ok, view, html} = live(conn, ~p"/")

    assert has_element?(view, "#job-#{job_id}", "Show content")
    assert has_element?(view, "#job-content-#{job_id} el-dm-markdown.job-markdown-fullscreen")
    assert html =~ "# Example Documentation"
    assert html =~ "Fetched https://example.com/docs"
  end

  defp log_in(conn, token) do
    init_test_session(conn, %{management_token: token})
  end

  defp assert_job_status(job_id, expected) do
    receive do
      {:job_updated, %{job_id: ^job_id, status: ^expected} = job} ->
        job

      {:job_updated, %{job_id: ^job_id}} ->
        assert_job_status(job_id, expected)
    after
      1_000 -> flunk("expected job #{job_id} to reach #{expected}")
    end
  end

  defp reset_job_manager do
    if Process.whereis(Scout.Server.JobManager) do
      Supervisor.terminate_child(Scout.Server.Supervisor, Scout.Server.JobManager)
      Supervisor.restart_child(Scout.Server.Supervisor, Scout.Server.JobManager)
    end
  end

  defp prepare_auth_file do
    previous_settings_path = Application.fetch_env!(:scout, :settings_path)

    tmp_dir =
      Path.join(System.tmp_dir!(), "scout-dashboard-auth-#{System.unique_integer([:positive])}")

    settings_path = Path.join(tmp_dir, "settings.yaml")
    token = "test-management-token"

    File.mkdir_p!(tmp_dir)
    File.write!(settings_path, "general:\n  instance_name: Test Scout\n")
    Application.put_env(:scout, :settings_path, settings_path)
    File.write!(Path.join(tmp_dir, "auth.txt"), "#{token}\n")

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:scout, :settings_path, previous_settings_path)
    end)

    {tmp_dir, token}
  end

  defp restore_env(key, nil), do: Application.delete_env(:scout_server, key)
  defp restore_env(key, value), do: Application.put_env(:scout_server, key, value)

  defmodule Publisher do
    def publish_job(job) do
      markdown = "# Example Documentation\n\nFetched #{job.url}"

      ResultHandler.handle_result(
        Result.success(job, %{
          markdown: markdown,
          title: "Example Documentation",
          final_url: job.url,
          agent_id: "test-agent-1",
          duration_ms: 1,
          word_count: 4
        })
      )

      :ok
    end
  end
end

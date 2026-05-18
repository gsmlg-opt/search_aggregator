defmodule ScoutWeb.DashboardLiveTest do
  use ScoutWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Scout.Fetch.Result
  alias Scout.Server.ResultHandler

  setup do
    reset_job_manager()

    previous_publisher = Application.get_env(:scout_server, :job_publisher)
    Application.put_env(:scout_server, :job_publisher, __MODULE__.Publisher)

    on_exit(fn ->
      restore_env(:job_publisher, previous_publisher)
      reset_job_manager()
    end)

    :ok
  end

  test "renders the Scout dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#fetch-form")
    assert has_element?(view, "#jobs")
    assert has_element?(view, "#agents")
  end

  test "renders completed fetch content in an expandable DuskMoon markdown preview", %{conn: conn} do
    Phoenix.PubSub.subscribe(Scout.PubSub, "scout:jobs")

    assert {:ok, %{job_id: job_id}} =
             Scout.Server.submit_fetch(%{"url" => "https://example.com/docs"})

    assert_job_status(job_id, "completed")

    {:ok, view, html} = live(conn, ~p"/")

    assert has_element?(view, "#job-#{job_id} .job-output-toggle", "Fetch content")
    assert has_element?(view, "#job-#{job_id} .job-output el-dm-markdown.job-markdown")
    assert html =~ "# Example Documentation"
    assert html =~ "Fetched https://example.com/docs"
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

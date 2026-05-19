defmodule ScoutWeb.DashboardLive do
  use ScoutWeb, :live_view

  @jobs_topic "scout:jobs"
  @agents_topic "scout:agents"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Scout.PubSub, @jobs_topic)
      Phoenix.PubSub.subscribe(Scout.PubSub, @agents_topic)
    end

    jobs = Scout.Server.list_fetches()
    agents = Scout.Server.list_agents()

    {:ok,
     socket
     |> stream_configure(:jobs, dom_id: &"job-#{&1.job_id}")
     |> stream_configure(:agents, dom_id: &"agent-#{&1.agent_id}")
     |> assign(:page_title, "Dashboard")
     |> assign(:form, to_form(%{"url" => ""}, as: :fetch))
     |> assign_job_stats(jobs)
     |> assign_agent_stats(agents)
     |> stream(:jobs, jobs, reset: true)
     |> stream(:agents, agents, reset: true)}
  end

  @impl true
  def handle_event("submit_fetch", %{"fetch" => params}, socket) do
    case Scout.Server.submit_fetch(params) do
      {:ok, job} ->
        jobs = Scout.Server.list_fetches()

        {:noreply,
         socket
         |> put_flash(:info, "Fetch queued")
         |> assign(:form, to_form(%{"url" => ""}, as: :fetch))
         |> assign_job_stats(jobs)
         |> stream_insert(:jobs, job, at: 0)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error.message)}
    end
  end

  @impl true
  def handle_event("theme_changed", %{"theme" => _theme}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:job_updated, job}, socket) do
    {:noreply,
     socket
     |> assign_job_stats(Scout.Server.list_fetches())
     |> stream_insert(:jobs, job, at: 0)}
  end

  def handle_info({:agent_updated, agent}, socket) do
    agents = Scout.Server.list_agents()

    {:noreply,
     socket
     |> assign_agent_stats(agents)
     |> stream_insert(:agents, agent)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="dashboard-page">
        <section class="dashboard-header">
          <div>
            <p class="eyebrow">Scout Server</p>
            <h1>Distributed Markdown fetch pipeline</h1>
          </div>
          <div class="header-metrics" aria-label="Scout status summary">
            <div>
              <span class="metric">{@job_count}</span>
              <span class="metric-label">jobs</span>
            </div>
            <div>
              <span class="metric">{@completed_count}</span>
              <span class="metric-label">completed</span>
            </div>
            <div>
              <span class="metric">{@agent_count}</span>
              <span class="metric-label">agents</span>
            </div>
          </div>
        </section>

        <section class="fetch-band">
          <.form for={@form} id="fetch-form" phx-submit="submit_fetch" class="fetch-form">
            <.dm_input
              field={@form[:url]}
              type="url"
              placeholder="https://example.com/docs/page"
              autocomplete="url"
            />
            <.dm_btn variant="primary" type="submit">Queue Fetch</.dm_btn>
          </.form>
        </section>

        <section class="dashboard-grid">
          <div class="work-surface">
            <div class="section-heading">
              <h2>Fetch Jobs</h2>
              <span>{@running_count} running</span>
            </div>
            <div id="jobs" phx-update="stream" class="job-list">
              <div id="jobs-empty" class="empty-row hidden only:block">
                No fetch jobs yet.
              </div>
              <article :for={{id, job} <- @streams.jobs} id={id} class="job-row">
                <div class="job-main">
                  <span class={["status-pill", status_class(job.status)]}>{job.status}</span>
                  <div class="flex-1 min-w-0">
                    <a href={job.url} target="_blank" rel="noreferrer" class="block truncate">{job.url}</a>
                  </div>
                  <.dm_modal
                    :if={markdown = job_markdown(job)}
                    id={"job-content-#{job.job_id}"}
                    size="full"
                  >
                    <:trigger :let={dialog_id}>
                      <.dm_btn variant="secondary" size="xs" onclick={"document.getElementById('#{dialog_id}').show()"}>
                        Show content
                      </.dm_btn>
                    </:trigger>
                    <:title>
                      <div class="flex items-center gap-2 pr-8">
                        <span class={["status-pill", status_class(job.status)]}>{job.status}</span>
                        <span class="truncate">{job.url}</span>
                      </div>
                    </:title>
                    <:body>
                      <.dm_markdown
                        id={"job-markdown-modal-#{job.job_id}"}
                        class="job-markdown-fullscreen"
                        content={markdown}
                        theme="auto"
                      />
                    </:body>
                  </.dm_modal>
                </div>
                <div class="job-meta">
                  <span>attempt {job.attempt}/{job.max_attempts}</span>
                  <span>{job.timeout_ms} ms timeout</span>
                  <span :if={job[:region_hint]}>region {job.region_hint}</span>
                  <span :if={job[:result] && job.result[:word_count]}>
                    {job.result.word_count} words
                  </span>
                </div>
                <p :if={job[:error]} class="job-error">{job.error.message}</p>
              </article>
            </div>
          </div>

          <aside class="work-surface">
            <div class="section-heading">
              <h2>Agents</h2>
              <span>{@agent_capacity} capacity</span>
            </div>
            <div id="agents" phx-update="stream" class="agent-list">
              <div id="agents-empty" class="empty-row hidden only:block">
                Waiting for agent heartbeat.
              </div>
              <article :for={{id, agent} <- @streams.agents} id={id} class="agent-row">
                <div>
                  <strong>{agent.agent_id}</strong>
                  <span class="muted">{agent.region}</span>
                </div>
                <span class={["status-pill", status_class(agent.status)]}>{agent.status}</span>
                <div class="job-meta">
                  <span>{agent.running_jobs}/{agent.capacity} running</span>
                  <span>v{agent.version}</span>
                </div>
              </article>
            </div>
          </aside>
        </section>
      </main>
    </Layouts.app>
    """
  end

  defp assign_job_stats(socket, jobs) do
    assign(socket,
      job_count: length(jobs),
      completed_count: Enum.count(jobs, &(&1.status == "completed")),
      running_count: Enum.count(jobs, &(&1.status == "running"))
    )
  end

  defp assign_agent_stats(socket, agents) do
    assign(socket,
      agent_count: length(agents),
      agent_capacity: Enum.reduce(agents, 0, &(&1.capacity + &2))
    )
  end

  defp status_class("completed"), do: "status-ok"
  defp status_class("healthy"), do: "status-ok"
  defp status_class("running"), do: "status-running"
  defp status_class("queued"), do: "status-queued"
  defp status_class("retrying"), do: "status-running"
  defp status_class(_status), do: "status-error"

  defp job_markdown(%{result: %{markdown: markdown}}) when is_binary(markdown) do
    present_string(markdown)
  end

  defp job_markdown(%{result: %{"markdown" => markdown}}) when is_binary(markdown) do
    present_string(markdown)
  end

  defp job_markdown(_job), do: nil

  defp present_string(value) do
    case String.trim(value) do
      "" -> nil
      _content -> value
    end
  end
end

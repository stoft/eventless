defmodule Eventless.EventController do
  use Eventless.Web, :controller

  alias Eventless.Event
  alias Eventless.Repo

  plug :scrub_params, "event" when action in [:create, :update]

  def index(conn, _params) do
    events = Repo.all(Event)
    render(conn, "index.json", events: events)
  end

  def create(conn, %{"event" => event_params}) do
    changeset = Event.changeset(%Event{}, event_params)

    case Repo.insert(changeset) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", event_path(conn, :show, event))
        |> render("show.json", event: event)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Eventless.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def create(conn, %{"rule_id" => rule_id, "event" => event}) do
    update(conn, %{"rule_id" => rule_id, "id" => event["id"]})
  end

  def show(conn, %{"id" => id}) do
    event = Repo.get!(Event, id)
    render(conn, "show.json", event: event)
  end

  def update(conn, %{"rule_id" => rule_id, "id" => id}) do
    _rule = Repo.get!(Rule, rule_id)
    event = Repo.get!(Event, id)
    event = %{event| rule_id: rule_id}

    changeset = Event.changeset(event, event)

    case Repo.update(changeset) do
      {:ok, event} ->
        render(conn, "show.json", event: event)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Eventless.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "event" => event_params}) do
    event = Repo.get!(Event, id)
    changeset = Event.changeset(event, event_params)

    case Repo.update(changeset) do
      {:ok, event} ->
        render(conn, "show.json", event: event)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Eventless.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"rule_id" => rule_id, "id" => id}) do
    _rule = Repo.get!(Rule, rule_id)
    event = Repo.get!(Event, id)

    event = %{event | rule_id: ""}

    changeset = Event.changeset(event, event)

    case Repo.update(changeset) do
      {:ok, _event} ->
        # redirect(conn, to: Router.Helpers.rule_path(conn, :show, rule_id))
        send_resp(conn, :no_content, "")
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Eventless.ChangesetView, "error.json", changeset: changeset)
    end

    send_resp(conn, :no_content, "")
  end

  def delete(conn, %{"id" => id}) do
    IO.puts "Delete 2 called."
    event = Repo.get!(Event, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(event)

    send_resp(conn, :no_content, "")
  end

end

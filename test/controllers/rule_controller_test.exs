defmodule Eventless.RuleControllerTest do
  use Eventless.ConnCase

  alias Eventless.Rule
  @valid_attrs %{}
  @invalid_attrs %{}

  setup do
    conn = conn() |> put_req_header("accept", "application/json")
    {:ok, conn: conn}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, rule_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    rule = Repo.insert! %Rule{}
    conn = get conn, rule_path(conn, :show, rule)
    assert json_response(conn, 200)["data"] == %{"id" => rule.id}
  end

  test "does not show resource and instead throw error when id is nonexistent", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      get conn, rule_path(conn, :show, -1)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, rule_path(conn, :create), rule: @valid_attrs
    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get_by(Rule, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, rule_path(conn, :create), rule: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    rule = Repo.insert! %Rule{}
    conn = put conn, rule_path(conn, :update, rule), rule: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(Rule, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    rule = Repo.insert! %Rule{}
    conn = put conn, rule_path(conn, :update, rule), rule: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    rule = Repo.insert! %Rule{}
    conn = delete conn, rule_path(conn, :delete, rule)
    assert response(conn, 204)
    refute Repo.get(Rule, rule.id)
  end
end

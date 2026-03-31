defmodule Api.ErrorJSON do
  @moduledoc "Renders JSON error responses for Phoenix error handling."

  def render("404.json", _assigns) do
    %{error: "not_found", message: "Resource not found"}
  end

  def render("500.json", _assigns) do
    %{error: "internal_error", message: "Internal server error"}
  end

  def render(template, _assigns) do
    %{error: Phoenix.Controller.status_message_from_template(template)}
  end
end

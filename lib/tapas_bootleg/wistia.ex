defmodule TapasBootleg.Wistia do
  defrecord Account, api_password: nil
  defrecord Project, hashed_id: nil

  def doit do
    upload_file(account, "RubyTapas001.mp4", "RubyTapas Complete")
  end

  def upload_file(Account[api_password: api_password],
                  filename,
                  project_name,
                  http_options // []) do
    project    = project_for_name(account, project_name)
    project_id = project.hashed_id
    url = "https://upload.wistia.com/"
    parts = [{"api_password", api_password},
             {"project_id", project_id},
             {:file, filename}]
    {:ok, status, headers, client} =
      :hackney.request(:post, url, [], {:multipart, parts}, http_options)
  end

  def project_for_name(Account[api_password: api_password],
                            project_name) do
    import Enum
    project_list = request(:get,
                           "https://api.wistia.com/v1/projects.json",
                           api_password)
    project = find(project_list, [], fn(project) ->
                                         project["name"] == project_name
                                     end)
    Project[hashed_id: project["hashedId"]]
  end

  def account do
    account(Dotenv.get("WISTIA_API_PASSWORD"))
  end

  def account(api_password) do
    Account[api_password: api_password]
  end

  def request(method, url, api_password) do
    {:ok, 200, _headers, client} =
      :hackney.request(method, url, [], "", basic_auth: {"api", api_password})
    {:ok, body} = :hackney.body(client)
    {:ok, data} = JSON.decode(body)
    data
  end
end
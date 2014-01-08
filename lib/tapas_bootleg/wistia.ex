defmodule TapasBootleg.Wistia do
  defrecord Account, api_password: nil
  defrecord Project, name: nil, hashed_id: nil, account: nil

  def upload_file(project,
                  filename,
                  http_options // []) do
    upload_file(project.account,
                filename,
                project.name,
                http_options)
  end


  def upload_file(Account[api_password: api_password],
                  filename,
                  project_name,
                  http_options) do
    project    = project_for_name(account, project_name)
    project_id = project.hashed_id
    url = "https://upload.wistia.com/"
    parts = [{"api_password", api_password},
             {"project_id", project_id},
             {:file, filename}]
    {:ok, _status, _headers, _client} =
      :hackney.request(:post, url, [], {:multipart, parts}, http_options)
  end

  def handle_upload_events do
    receive do
      {:hackney_response, client, {:status, code, reason}} ->
        IO.puts "Received status #{code} #{reason}"
        handle_upload_events
      {:hackney_response, client, {:headers, headers}} ->
        IO.puts "Received headers"
        IO.inspect headers
      {:hackney_response, client, :done} ->
        IO.puts "Upload finished"
      {:hackney_response, client, chunk} ->
        IO.puts "Received chunk:"
        IO.inspect chunk
      other ->
        IO.puts "Other: #{other}"
    end
  end

  def list_project_videos(Project[hashed_id: hashed_id,
                                  account: Account[api_password: api_password]]) do
    import Enum
    data = request(:get,
                   "https://api.wistia.com/v1/projects/#{hashed_id}.json",
                   api_password)
    data["medias"] |> filter_map(fn(media) -> media["type"] == "Video" end,
                                 fn(media) -> media["name"] end)
  end

  def project_for_name(Account[api_password: api_password] = account,
                            project_name) do
    import Enum
    project_list = request(:get,
                           "https://api.wistia.com/v1/projects.json",
                           api_password)
    project = find(project_list, [], fn(project) ->
                                         project["name"] == project_name
                                     end)
    Project[name:      project["name"],
            hashed_id: project["hashedId"],
            account:   account]
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
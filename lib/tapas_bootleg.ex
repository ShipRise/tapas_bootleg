defmodule TapasBootleg do
  import Enum
  use Application.Behaviour

  defrecord :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlAttribute, Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")

  defrecord Account, subdomain: nil, login: nil, password: nil
  defrecord Episode, name: nil, number: nil, video_url: nil, filename: nil, account: nil

  @number_pattern %r/
      (?<!\d)                   # preceded by non-digits
      \d{3}[a-z]?               # exactly three digits in a row (maybe 1 letter too)
      (?!\d)                    # followed by non-digits
    /x


  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do
    TapasBootleg.Supervisor.start_link
  end

  def upload_missing_videos(wistia_project // wistia_project,
                            episodes // fetch_episodes) do
    import Enum
    eps = missing_episodes(wistia_project, episodes)
    IO.puts "Uploading #{count(eps)} missing episodes"

    each(eps, fn(ep) ->
                  IO.puts "Grabbing #{ep.name} from DPD"
                  download_video(ep)
                  filename = ep.filename
                  IO.puts "Uploading #{filename} to Wistia"
                  TapasBootleg.Wistia.upload_file(wistia_project, filename)
                  IO.puts "Done with #{ep.name}"
                  IO.puts "Collecting garbage"
              end)
    IO.puts "All episodes uploaded"
  end

  def login, do: Dotenv.get("DPD_USER_LOGIN") || raise "Missing login"
  def password, do: Dotenv.get("DPD_USER_PASSWORD") || raise "Missing password"

  def account do
    TapasBootleg.Account[subdomain: "rubytapas",
                         login: login,
                         password: password]
  end

  def fetch_feed(account // account)

  def fetch_feed(Account[subdomain: subdomain,
                         login:     login,
                         password:  password]) do
    url = "https://#{subdomain}.dpdcart.com/feed"
    {:ok, 200, _headers, client} = :hackney.get(url, [], "",
                                                 basic_auth: {login, password})
    {:ok, body} = :hackney.body(client)
    {:ok, body}
  end

  def fetch_video_list(account) do
    fetch_episodes(account)
    |> flat_map fn(episode) ->
                    [{episode.name, episode.video_url}]
                end
  end

  def fetch_episodes(account // account) do
    {:ok, body}   = fetch_feed(account)
    {doc, _rest}  = :xmerl_scan.string(bitstring_to_list(body))
    item_elts     = :xmerl_xpath.string('//item', doc)
    item_elts |> map fn(item_elt) ->
                         episode_from_item(item_elt, doc).update(account: account)
                     end
  end

  def download_video(Episode[filename: filename] = episode) do
    Stream.resource(fn -> begin_download(episode) end,
                    &continue_download/1,
                    &finish_download/1)
    |> File.stream_to!(filename)
    |> Stream.run
  end

  def begin_download(Episode[video_url: video_url,
                             account:   Account[login:    login,
                                                password: password]]) do
    IO.puts "Downloading #{video_url}"
    {:ok, _status, headers, client} =
      :hackney.get(video_url, [], "", basic_auth: {login, password})
    total_size = headers["Content-Length"] |> binary_to_integer
    {client, total_size, 0}
  end

  def continue_download({client, total_size, size}) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        new_size = size + size(data)
        {data, {client, total_size, new_size}}
      :done ->
        IO.puts "No more data"
        nil
      {:error, reason} ->
        raise reason
    end
  end

  def finish_download({client, total_size, size}) do
    IO.puts "Finished downloading #{size} bytes"
  end

  def episode_from_item(item_element, doc) do
    [name_text]   = find_child('./title', item_element, doc).content
    name          = name_text.value |> to_string
    video_url     = video_url_from_item(item_element, doc)
    filename      = case video_url do
                      nil ->
                        IO.puts "No enclosure for ep: #{name}"
                        nil
                      video_url -> video_url |> String.split("/") |> List.last
                    end
    number = case Regex.run(@number_pattern, name) do
               nil -> IO.puts "No number for ep: #{name}"
               [number] -> number
             end
    Episode.new(name: name, filename: filename, video_url: video_url, number: number)
  end

  def video_url_from_item(item_element, doc) do
    enclosure_elt = find_child('./enclosure', item_element, doc)
    case enclosure_elt do
      nil -> nil
      enclosure_elt ->
        attrs         = enclosure_elt.attributes |> reduce [], &attributes_to_keylist/2
        video_url     = attrs[:url]
    end
  end

  def missing_episodes(wistia_project // wistia_project,
                      episodes // fetch_episodes) do
    import Enum
    available_numbers = episodes |> map(fn(ep) -> ep.number end) |> HashSet.new
    uploaded_numbers  = uploaded_episode_numbers(wistia_project) |> HashSet.new
    missing_numbers   = Set.difference(available_numbers, uploaded_numbers)
    episodes |> filter(fn(ep) ->
                           ep.number in missing_numbers
                       end)
  end

  def uploaded_episode_numbers(wistia_project // wistia_project) do
    import TapasBootleg.Wistia
    wistia_project
    |> list_project_videos
    |> Enum.flat_map(fn(title) ->
                         case Regex.run(@number_pattern, title) do
                           [number] -> [number]
                         else []
                         end
                     end)
  end

  def wistia_project(wistia_account // wistia_account) do
    import TapasBootleg.Wistia
    wistia_account |> project_for_name("RubyTapas Complete")
  end

  defp find_child(xpath, element, doc) do
    first(:xmerl_xpath.string(xpath, element, element.parents, doc, []))
  end

  defp attributes_to_keylist(attr, attrs) do
    Dict.merge(attrs, [{attr.name, to_string(attr.value)}])
  end

  defp wistia_account do
    TapasBootleg.Wistia.account
  end
end

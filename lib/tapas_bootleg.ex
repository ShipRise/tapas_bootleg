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
      \d{3}[a-z]?               # exactly three digits in a row
      (?!\d)                    # followed by non-digits
    /x


  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do
    TapasBootleg.Supervisor.start_link
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
    {:ok, body, _client} = :hackney.body(client)
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
      {:ok, data, client} ->
        new_size = size + size(data)
        IO.puts "Downloaded #{new_size} of #{total_size}"
        {data, {client, total_size, new_size}}
      {:done, client} ->
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

  defp find_child(xpath, element, doc) do
    first(:xmerl_xpath.string(xpath, element, element.parents, doc, []))
  end

  defp attributes_to_keylist(attr, attrs) do
    Dict.merge(attrs, [{attr.name, to_string(attr.value)}])
  end
end

defmodule TapasBootlegTest do
  use ExUnit.Case

  def login, do: Dotenv.get("DPD_USER_LOGIN") || raise "Missing login"
  def password, do: Dotenv.get("DPD_USER_PASSWORD") || raise "Missing password"
  def account do
    TapasBootleg.Account[subdomain: "rubytapas",
                         login: login,
                         password: password]
  end

  test "fetching the content feed" do
    {:ok, _feed} = TapasBootleg.fetch_feed(account)
  end

  test "fetching the video list" do
    list = TapasBootleg.fetch_video_list(account)
    assert list["155 Matching Triples"] ==
      "https://rubytapas.dpdcart.com:443/feed/download/16172/155-matching-triples.mp4"
  end
end

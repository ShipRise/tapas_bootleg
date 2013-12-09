defmodule TapasBootleg.Mixfile do
  use Mix.Project

  def project do
    [ app: :tapas_bootleg,
      version: "0.0.1",
      elixir: "~> 0.11.1",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [
     applications: [:hackney, :dotenv_elixir],
     mod: { TapasBootleg, [] }
    ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat.git" }
  defp deps do
    [{:hackney, github: "benoitc/hackney", tag: "0.7.0" },
     {:dotenv_elixir, github: "avdi/dotenv_elixir" }]
  end
end

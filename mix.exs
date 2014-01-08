defmodule TapasBootleg.Mixfile do
  use Mix.Project

  def project do
    [ app: :tapas_bootleg,
      version: "0.0.1",
      elixir: "~> 0.12",
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
    [{:hackney_lib, github: "benoitc/hackney_lib", tag: "0.2.2", override: true },
     {:hackney, github: "benoitc/hackney", tag: "0.10.1" },
     {:dotenv_elixir, github: "avdi/dotenv_elixir", ref: "d839927eb6a8d86bd024b6bf25ab662de14c80c7" },
     {:json,"0.2.7",[github: "cblage/elixir-json", tag: "v0.2.7"]}]
  end
end

defmodule App.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      AppWeb.Telemetry,
      App.Repo,
      {DNSCluster, query: Application.get_env(:app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: App.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: App.Finch},
      # Start a worker by calling: App.Worker.start_link(arg)
      # {App.Worker, arg},
      # Start to serve requests, typically the last entry
      {Nx.Serving, serving: whisper_serving(), name: WhisperServing},
      App.StreamState,
      rtmp_server(),
      AppWeb.Presence,
      AppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AppWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp whisper_serving() do
    {:ok, whisper} = Bumblebee.load_model({:hf, "openai/whisper-tiny"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "openai/whisper-tiny"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/whisper-tiny"})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "openai/whisper-tiny"})

    Bumblebee.Audio.speech_to_text_whisper(
      whisper,
      featurizer,
      tokenizer,
      generation_config,
      defn_options: [compiler: EXLA]
    )
  end

  defp rtmp_server() do
    {
      Membrane.RTMPServer,
      handler: %App.StreamHandler{controlling_process: self()},
      port: 1935,
      client_timeout: 5_000,
      use_ssl?: false,
      handle_new_client: fn client_ref, _app, _stream_key ->
        hls_dir = "./tmp/stream"
        File.mkdir_p!(hls_dir)
        signaling = Membrane.WebRTC.SignalingChannel.new()

        t =
          Task.start(fn ->
            Boombox.run(input: {:rtmp, client_ref}, output: {:webrtc, signaling})
          end)

        # Boombox.run(input: {:webrtc, signaling}, output: {:hls, "#{hls_dir}/index.m3u8"})
        start_transcription(signaling)

        Task.await(t)
      end
    }
  end

  defp start_transcription(signaling) do
    Boombox.run(
      input: {:webrtc, signaling},
      output:
        {:stream,
         video: false, audio: :binary, audio_rate: 16_000, audio_channels: 1, audio_format: :f32le}
    )
    |> Stream.map(&Nx.from_binary(&1.payload, :f32))
    |> Stream.chunk_every(200)
    |> Enum.each(fn chunk ->
      batch = Nx.concatenate(chunk)

      Nx.Serving.batched_run(WhisperServing, batch).chunks
      |> Enum.map_join(& &1.text)
      |> Logger.info()
    end)
  end
end

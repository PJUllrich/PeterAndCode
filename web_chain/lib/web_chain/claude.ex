defmodule WebChain.Claude do
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatAnthropic
  alias LangChain.Message

  def summarize(text, callback_handler, chain \\ nil) do
    chain = chain || new_chain(callback_handler)

    {:ok, updated_chain, response} =
      chain
      |> LLMChain.add_messages([
        Message.new_system!(
          "You love to summarize articles. Please summarize the article that I'll send you in the next message."
        ),
        Message.new_user!(text)
      ])
      |> LLMChain.run()

    {updated_chain, response}
  end

  def add_message(message, callback_handler, chain \\ nil) do
    chain = chain || new_chain(callback_handler)

    {:ok, updated_chain, response} =
      chain
      |> LLMChain.add_message(Message.new_user!(message))
      |> LLMChain.run()

    {updated_chain, response}
  end

  defp new_chain(callback_handler) do
    LLMChain.new!(%{
      llm: %ChatAnthropic{
        model: "claude-3-5-haiku-latest",
        stream: true,
        callbacks: [callback_handler]
      },
      callbacks: [callback_handler]
    })
  end
end

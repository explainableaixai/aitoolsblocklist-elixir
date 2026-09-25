client = AIToolsBlocklist.Client.new(System.fetch_env!("AQ_API_KEY"))
IO.inspect(AIToolsBlocklist.Client.check(client, "chat.openai.com"))

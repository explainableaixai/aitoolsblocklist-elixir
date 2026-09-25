# AIToolsBlocklist

Elixir client for AI Tools Blocklist, the data behind [allowlist and blocklist management tools](https://www.aitoolsblocklist.com). Ask about a hostname and get back whether it belongs to an AI tool, the tool's categories, and what its vendor says about training on customer data. It is built on `Req`, so it fits naturally into Phoenix apps, Oban jobs and plain scripts.

## Installation

```elixir
def deps do
  [{:aitoolsblocklist, "~> 1.0"}]
end
```

## First lookup

```elixir
client = AIToolsBlocklist.Client.new(System.fetch_env!("AQ_API_KEY"))

case AIToolsBlocklist.Client.check(client, "chat.mistral.ai") do
  {:ok, %{"blocked" => true} = tool} ->
    IO.puts("#{tool["domain"]} is an AI tool: #{tool["primary_category"]}")

  {:ok, %{"blocked" => false}} ->
    IO.puts("not in the register")

  {:error, {:api_error, status, body}} ->
    IO.puts("API answered #{status}: #{inspect(body)}")

  {:error, reason} ->
    IO.puts("request failed: #{inspect(reason)}")
end
```

`check/2` returns tagged tuples, never raises for HTTP problems, and hands you the decoded JSON as a map with string keys.

## The map you get back

For an AI tool:

- `"blocked"`: `true`
- `"primary_category"` and `"ai_type"`: what the tool mainly does, and whether AI is the product or a feature
- `"categories"`: a list of maps with `"category"` and, often, `"subcategory"`
- `"matched_domain"`: only present when a parent domain matched
- `"trains_on_data"`, `"opt_out_available"`, `"enterprise_no_training"`, `"api_no_training"`: each `"yes"`, `"no"`, `"opt_out_default"` or `"unstated"`
- `"terms_checked"`: the date of the terms review

For anything else, `"blocked"` is `false` and `"categories"` is an empty list.

Pattern matching makes policy code short and readable:

```elixir
def decide({:ok, %{"blocked" => false}}), do: :allow
def decide({:ok, %{"trains_on_data" => "no"}}), do: :allow_and_log
def decide({:ok, %{"trains_on_data" => t}}) when t in ["yes", "unstated"], do: :block
def decide({:ok, _}), do: :warn
def decide({:error, _}), do: :unknown
```

## Retries you get for free

The client uses `Req.get/2`, and Req retries safe requests by default. Timeouts, connection errors and responses of 408, 429 and common 5xx statuses are retried a few times with exponential backoff before you see an error. For most callers that means a single `check/2` call already copes with brief hiccups. Errors that reach you are either persistent or not retryable, such as a 401 for a bad key.

## A Plug for Phoenix

Internal tools sometimes need a quick "is this AI?" endpoint that does not expose the key. A small plug and an ETS cache do the job:

```elixir
defmodule MyAppWeb.AiCheck do
  import Plug.Conn
  @ttl :timer.hours(12)

  def init(opts), do: opts

  def call(%{path_params: %{"host" => host}} = conn, _opts) do
    result = cached(String.downcase(host))
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(result))
  end

  defp cached(host) do
    now = System.monotonic_time(:millisecond)
    case :ets.lookup(:ai_check_cache, host) do
      [{^host, value, exp}] when exp > now -> value
      _ ->
        value =
          case AIToolsBlocklist.Client.check(client(), host) do
            {:ok, map} -> Map.take(map, ["domain", "blocked", "primary_category", "trains_on_data"])
            {:error, _} -> %{"domain" => host, "error" => true}
          end
        :ets.insert(:ai_check_cache, {host, value, now + @ttl})
        value
    end
  end

  defp client, do: AIToolsBlocklist.Client.new(Application.fetch_env!(:my_app, :atb_key))
end
```

Create the table once at startup with `:ets.new(:ai_check_cache, [:named_table, :public, read_concurrency: true])`. Cache negative answers too, since most hosts are not AI tools.

## Checking many hosts at once

`Task.async_stream/3` gives controlled concurrency with almost no code:

```elixir
hosts
|> Task.async_stream(&AIToolsBlocklist.Client.check(client, &1), max_concurrency: 4, timeout: 30_000)
|> Enum.map(fn {:ok, result} -> result end)
```

Four concurrent lookups keep a batch quick without leaning on rate limits.

## Configuration

`new/2` takes the API key and an optional `:base_url`:

```elixir
AIToolsBlocklist.Client.new(key, base_url: "http://localhost:4001/stub")
```

The base URL is handy for tests against a local stub or for routing through an internal gateway. `new/2` only accepts a non-empty binary key. Anything else raises a `FunctionClauseError` right away, which catches configuration mistakes at boot. The same guard applies to the host passed to `check/2`.

Keep the key in runtime configuration, loaded in `config/runtime.exs` from an environment variable, not in compiled config.

## Error shapes

| Result | Meaning |
|---|---|
| `{:error, {:api_error, 401, body}}` | Key not recognised |
| `{:error, {:api_error, 403, body}}` | Plan inactive or monthly quota used |
| `{:error, {:api_error, 429, body}}` | Still rate limited after Req's retries |
| `{:error, %Req.TransportError{}}` | Network problem after retries |

## When lookups are not enough

Resolvers and firewalls that see every DNS query should not call an API per query. Plans with the downloadable list let you load all classified domains into ETS at boot and refresh nightly. Keep `check/2` for new hosts and admin tooling.

## Related services

Start with evidence: [a shadow AI detection tool](https://www.shadowaitools.com/how-it-works.php) shows which tools people already use. If your system runs LLM agents, add an [AI agent allow list for LLM agents](https://www.aiagentallowlist.com/agent-guardrails.php). For the non-AI part of the web, including [web filtering for remote employees and branch offices](https://www.webfilteringdatabase.com/web-filtering-database.php), use the general database.

The register is also on [pub.dev for Flutter](https://pub.dev/packages/aitoolsblocklist), on [crates.io for Rust](https://crates.io/crates/aitoolsblocklist), and as [a Go module](https://pkg.go.dev/github.com/explainableaixai/aitoolsblocklist-go).

## License

MIT

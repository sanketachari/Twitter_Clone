defmodule Twitter.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    :ets.new(:user_lookup, [:set, :public, :named_table])

    children = [supervisor(TwitterWeb.Endpoint, []),
                worker(TwitterWeb.Server, [%{}])
              ]
    total_users = 100


    # Adding muliple clients here
    children = children ++ Enum.map(1..total_users, fn x ->
        worker(Twitter.SocketClient, [to_string(x), total_users], id: x)
    end)

    opts = [strategy: :one_for_one, name: Twitter.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    children = Supervisor.which_children(pid)
    children = Enum.filter(children, fn(x) -> is_integer(elem(x, 0)) end)

    :timer.sleep(50000)

    tweets = TwitterWeb.Server.query_tweets_of_hashtag( "#DOS")
    IO.inspect length(tweets), label: "Total tweets with hashtag #DOS "
    IO.puts "Tweets (Showing Max 10): "
    IO.inspect Enum.take(tweets, 10)
    IO.puts ""

    tweets = TwitterWeb.Server.query_tweets_of_mention("@user1")
    IO.inspect length(tweets), label: "Total tweets with mention @user1"
    IO.puts "Tweets (Showing Max 10): "
    IO.inspect Enum.take(tweets, 10)
    IO.puts ""

    IO.puts "Printing user1 details:"
    TwitterWeb.Server.print_user("1")
    # TwitterWeb.Server.print_state()

    wait()
  end

  def wait() do
    receive do
      {msg} -> IO.inspect msg
    end
  end

  def subscribe_to_tweet(server, users) do

    tweets = Client.get_tweets(server)

    Enum.each(users, fn user ->
        [tweetId_atom] = Enum.take_random(Map.keys(tweets), 1)
        tweetId = to_string(tweetId_atom)
        if(Enum.random([true, false])) do
          Client.subscribe_to_tweet(server, user, tweetId)
        end
     end)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TwitterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

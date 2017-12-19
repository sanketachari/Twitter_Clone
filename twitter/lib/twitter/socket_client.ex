defmodule Twitter.SocketClient do
    @moduledoc false
    require Logger
    alias Phoenix.Channels.GenSocketClient
    @behaviour GenSocketClient
  
    def start_link(id, total_users) do
      GenSocketClient.start_link(
            __MODULE__,
            Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
            %{"url" => "ws://localhost:4000/socket/websocket", "id" => id, "total_users" => total_users}
          )
    end
  
    def init(initial_state) do
      {:connect, Map.get(initial_state, "url"), [], 
          %{first_join: true, ping_ref: 1, id: Map.get(initial_state, "id"), 
                total_users: Map.get(initial_state, "total_users"), engine_state: %{}}}
    end
  
    def handle_connected(transport, state) do
      # Logger.info("connected")
      IO.inspect "User" <> state.id <> " connected"
      GenSocketClient.join(transport, "engine", %{"id" => state.id})
      # :ets.new(:user_table, [:set, :public, :named_table])
      {:ok, state}
    end
  
    def handle_disconnected(reason, state) do
      Logger.error("disconnected: #{inspect reason}")
      Process.send_after(self(), :connect, :timer.seconds(1))
      {:ok, state}
    end
  
    def handle_joined(topic, _payload, _transport, state) do
      Logger.info("joined the topic #{topic}")

      # ------  Add follower -----
      :timer.send_after(:timer.seconds(1), self(), :add_random_followers)
      :timer.sleep(2000)

      :timer.send_after(:timer.seconds(1), self(), :get_usernames)
      :timer.sleep(1000)

      # :timer.send_after(:timer.seconds(1), self(), :subscribe_to_tweet)

      {:ok, %{state | first_join: false, ping_ref: 1}}

    end
  
    def handle_join_error(topic, payload, _transport, state) do
      Logger.error("join error on the topic #{topic}: #{inspect payload}")
      {:ok, state}
    end
  
    def handle_channel_closed(topic, payload, _transport, state) do
      Logger.error("disconnected from the topic #{topic}: #{inspect payload}")
      Process.send_after(self(), {:join, topic}, :timer.seconds(1))
      {:ok, state}
    end
  
    def handle_message(topic, event, payload, _transport, state) do
      # IO.inspect event, label: "handle message, event is "
      # Logger.warn("message on topic #{topic}: #{event} #{inspect payload}")

      if event == "usernames" do
        :ets.insert(:user_lookup, {"usernames_" <> state.id, payload})

        # ------  Send Tweet -----
        :timer.send_after(:timer.seconds(1), self(), :send_tweet)
        :timer.sleep(1000)
      end

      if event == "tweets" do
        :ets.insert(:user_lookup, {"tweets_" <> state.id, payload})

        # ------  Subscribe to tweets -----
        :timer.send_after(:timer.seconds(1), self(), :subscribe_to_tweet)
        :timer.sleep(1000)
      end
      {:ok, state}
    end
  
    def handle_reply("engine", _ref, %{"status" => "ok"} = payload, _transport, state) do
      # IO.inspect self(), label: "In handle reply pid is "
      # Logger.info("server pong ##{payload["response"]["ping_ref"]}")
      {:ok, state}
    end

    def handle_reply(topic, _ref, payload, _transport, state) do
      Logger.warn("reply on topic #{topic}: #{inspect payload}")
      {:ok, state}
    end
  
    def handle_info(:connect, _transport, state) do
      Logger.info("connecting")
      {:connect, state}
    end

    def handle_info({:join, topic}, transport, state) do
      Logger.info("joining the topic #{topic}")
      case GenSocketClient.join(transport, topic) do
        {:error, reason} ->
          Logger.error("error joining the topic #{topic}: #{inspect reason}")
          Process.send_after(self(), {:join, topic}, :timer.seconds(1))
        {:ok, _ref} -> :ok
      end
  
      {:ok, state}
    end

    def handle_info(:add_random_followers, transport, state) do
      total_users = state.total_users
      max_followers = trunc(:math.ceil(total_users * 0.2))
      total_followers = Enum.random(1..max_followers)
      users = Enum.map(1..total_users, fn x -> to_string(x) end)
      user = state.id
      others = List.delete(users, user)
      followers = Enum.take_random(others, total_followers)
      Enum.each(followers, fn follower -> GenSocketClient.push(transport, "engine" , "add_follower", %{"id" => state.id, "follower" => follower}) end)
      {:ok, state}
    end

    def handle_info(:send_tweet, transport, state) do
      total_users = state.total_users

      :timer.sleep(5000) 
      [{_, map_usernames}] = :ets.lookup(:user_lookup, "usernames_" <> state.id)
      # users = Enum.map(1..total_users, fn x -> to_string(x) end)
      # user_names = Enum.map(users, fn user ->  usernames[user]["username"] end)
      user_names = Map.keys(map_usernames)
      user = state.id

      [u1, u2] = Enum.take_random(user_names , 2)
      tweet1 = "Some random tweet #randomtweet #newtweet @" <> u1 <> " @" <> u2
      [u1, u2] = Enum.take_random(user_names , 2)
      tweet2 = "This is #mytweet some tweet #sometweet @" <> u1 <> " @" <> u2
      [u1, u2] = Enum.take_random(user_names , 2)
      tweet3 = "Another tweet, study #DOS and do #projects @" <> u1 <> " @" <> u2

      [tweet] = Enum.take_random([tweet1, tweet2, tweet3], 1)

      #Extract hashtags in a tweet
      {:ok, pattern} = Regex.compile("#(\\S+)")
      matches = Regex.scan(pattern, tweet)
      hashtags = Enum.map(matches, fn match -> Enum.at(match, 0) end)

      #Extract mentions in a tweet
      {:ok, pattern} = Regex.compile("@(\\S+)")
      matches = Regex.scan(pattern, tweet)
      mentions = Enum.map(matches, fn match -> Enum.at(match, 0) end)

      # Randomly tweet or retweet
      if(Enum.random([true, false])) do
        GenSocketClient.push(transport, "engine" , "send_tweet", %{"id" => user, "tweet" => tweet, "hashtags" => hashtags, "mentions" => mentions, "isRetweet" => true}) # Retweet
      else
        GenSocketClient.push(transport, "engine" , "send_tweet", %{"id" => user, "tweet" => tweet, "hashtags" => hashtags, "mentions" => mentions, "isRetweet" => false}) # Tweet
      end

      # ------  Get Tweets -----
      :timer.send_after(:timer.seconds(1), self(), :get_tweets)
      :timer.sleep(1000)

      {:ok, state}
    end

    def handle_info(:get_tweets, transport, state) do
      GenSocketClient.push(transport, "engine" , "get_tweets", %{})
      {:ok, state}
    end

    def handle_info(:get_usernames, transport, state) do
      GenSocketClient.push(transport, "engine" , "get_usernames", %{})
      {:ok, state}
    end

    def handle_info(:subscribe_to_tweet, transport, state) do
      [{_, tweets}] = :ets.lookup(:user_lookup, "tweets_" <> state.id)
      # IO.inspect tweets, label: "tweets are "
      [tweetId_atom] = Enum.take_random(Map.keys(tweets), 1)
      tweetId = to_string(tweetId_atom)
      :timer.sleep(5000) 
      GenSocketClient.push(transport, "engine" , "subscribe_to_tweet", %{"id" => state.id, "tweetId" => tweetId})
      {:ok, state}
    end

    def handle_info(message, _transport, state) do
      Logger.warn("Unhandled message #{inspect message}")
      {:ok, state}
    end

    def print_state() do
      IO.inspect "In Print state"
    end

  end

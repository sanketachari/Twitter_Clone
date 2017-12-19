defmodule TwitterWeb.Server do
    use GenServer
    use TwitterWeb, :channel

    def start_link(initial_state) do
        GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
    end

    def add_user(user_id, user_name, socket) do
        GenServer.cast(__MODULE__, {:add_user, user_id, user_name, socket})
    end

    def add_follower( user_id, follower_id) do
        GenServer.cast(__MODULE__, {:add_follower, user_id, follower_id})
    end

    def send_tweet(user_id, tweet, hashtags, mentions, is_retweet) do
        GenServer.cast(__MODULE__, {:send_tweet, user_id, tweet, hashtags, mentions, is_retweet})
    end

    def subscribe_to_tweet(user_id, tweetId) do
        GenServer.cast(__MODULE__, {:subscribe_to_tweet, user_id, tweetId})
    end

    def query_subscribed_tweets(user_id) do
        GenServer.call(__MODULE__, {:query_subscribed_tweets, user_id})
    end

    def query_retweets(user_id) do
        GenServer.call(__MODULE__, {:get_retweets, user_id})
    end

    def query_tweets_of_hashtag(hashtag) do
        GenServer.call(__MODULE__, {:get_tweets_of_hashtag, hashtag})
    end

    def query_tweets_of_mention(mention) do
        GenServer.call(__MODULE__, {:get_tweets_of_mention, mention})
    end

    def get_users() do
        GenServer.call(__MODULE__, {:get_users})  #Returns a list of users
    end

    def get_followers(user_id) do
        GenServer.call(__MODULE__, {:get_followers, user_id})  #Returns a list of user followers
    end

    def get_username(user_id) do
        GenServer.call(__MODULE__, {:get_username, user_id})  #Returns username
    end

    def get_tweets(socket) do
        GenServer.call(__MODULE__, {:get_tweets, socket})  #Returns a list of user tweets
    end

    def get_user_details(user_id) do
        GenServer.call(__MODULE__, {:get_user_details, user_id})
    end

    def get_usernames(socket) do
        GenServer.call(__MODULE__, {:get_usernames, socket})
    end

    def print_user(user_id) do
        GenServer.call(__MODULE__, {:print_user, user_id})
    end

    def print_state() do
        GenServer.call(__MODULE__, {:print_state})
    end


    # ------------  Server --------------

    def init(_) do
        # {:ok, %{"users" => [id1, id2..], "hashtags" => %{}, "user_details" => %{id => %{"tweets" => [], "followers" =>[], "notifications" => %{source_id => [tweet1, ...]}}}}}
        {:ok, %{"users" => %{}, "usernames" => %{} , "tweets" => %{}, "user_details" => %{}, "hashtags" => %{}, "mentions" => %{}}}
    end

    def handle_cast({:add_user, user_id, user_name, socket}, state) do
        :ets.insert(:user_lookup, {user_id, socket})
        users = state["users"]
        active_user = Map.put(state["users"], user_id, Enum.random([true, false]))  # Set active = true initially
        state = Map.put(state, "users", active_user)
        username_map = Map.put(state["usernames"], user_name, user_id)
        state = Map.put(state, "usernames", username_map)
        user_details = Map.get(state, "user_details")
        user_details = Map.put(user_details, user_id, %{"username" => user_name, "tweets" => [], "retweets" => [], "followers" => [], "notifications" => %{}, "subscribed" => []})
        state = Map.put(state, "user_details", user_details)

        #  IO.inspect(state, label: "State after adding user: ")
        {:noreply, state}
    end

    def handle_cast({:add_follower, user_id, follower_id}, state) do
        #TODO Add checks if user doesn't exist
        user_details_id = state["user_details"][user_id]
        followers = user_details_id["followers"]
        user_details_id = Map.put(user_details_id, "followers", [follower_id | followers])
        user_details = state["user_details"]
        user_details = Map.put(user_details, user_id, user_details_id)
        state = Map.put(state, "user_details", user_details)

        # IO.inspect(state, label: "State after adding follower: ")
        {:noreply, state}
    end

    def handle_cast({:send_tweet, user_id, tweet, hashtags, mentions, is_retweet}, state) do
        user_details_id = state["user_details"][user_id]

        if(is_retweet) do
            retweets = user_details_id["retweets"]
            user_details_id = Map.put(user_details_id, "retweets", [tweet | retweets])
        else
            tweets = user_details_id["tweets"]
            user_details_id = Map.put(user_details_id, "tweets", [tweet | tweets])

            # Update the hashtags map
            # %{"hashtags" => %{"hashtag": %{id => []}}

            state = Enum.reduce(hashtags, state, fn(hashtag, state) ->
                hashtags_map = state["hashtags"]
                if hashtags_map[hashtag] == nil do
                    hashtags_map = Map.put(hashtags_map, hashtag, %{})
                end

                hashtag_details = hashtags_map[hashtag]

                if(hashtag_details[user_id] != nil) do
                    hashtag_details = Map.put(hashtag_details, user_id, [tweet] ++ hashtag_details[user_id])
                else
                    hashtag_details = Map.put(hashtag_details, user_id, [tweet])
                end

                hashtags_map = Map.put(hashtags_map, hashtag, hashtag_details)
                state = Map.put(state, "hashtags", hashtags_map)
            end)

            # Update the mentions map
            # %{"mentions" => %{"mention": %{id => []}}

            state = Enum.reduce(mentions, state, fn(mention, state) ->

                mentions_map = state["mentions"]
                if mentions_map[mention] == nil do
                    mentions_map = Map.put(mentions_map, mention, %{})
                end

                mention_details = mentions_map[mention]

                if(mention_details[user_id] != nil) do
                    mention_details = Map.put(mention_details, user_id, [tweet | mention_details[user_id]])
                else
                    mention_details = Map.put(mention_details, user_id, [tweet])
                end

                mentions_map = Map.put(mentions_map, mention, mention_details)
                state = Map.put(state, "mentions", mentions_map)
            end)
        end

        # Add tweetId and tweet to generic collection
        tweets = Map.put(state["tweets"],Base.encode16(:crypto.hash(:sha256, tweet)) , {tweet, user_id})
        state = Map.put(state, "tweets", tweets)


        user_details = state["user_details"]
        user_details = Map.put(user_details, user_id, user_details_id)
        state = Map.put(state, "user_details", user_details)

        followers = state["user_details"][user_id]["followers"]
        #Sending tweet to every follower and adding it to their notifications
        #NOTE Outside scope of state not accessed inside Enum - Use recursion or Enum.reduce()

        # IO.inspect state, label: "Server's state is"

        state = Enum.reduce(followers, state, fn(follower_id, state) ->
            user_details_id = state["user_details"][follower_id]
            notifications = user_details_id["notifications"]
            if notifications[user_id] != nil do
                notifications = Map.put(notifications, user_id, [tweet | notifications[user_id]])
            else
                notifications = Map.put(notifications, user_id, [tweet])
            end
            user_details_id = Map.put(user_details_id, "notifications", notifications)
            user_details = state["user_details"]
            user_details = Map.put(user_details, follower_id, user_details_id)
            # send(follower_id, {:tweet, [tweet] ++ ["Tweet from user: "] ++ [user_id] ++ ["forwarded to follower: "] ++ [follower_id] })
            [{_, socket}] = :ets.lookup(:user_lookup, follower_id)
            # push socket, "tweet",  %{"tweet" => "Hi" } #[tweet] ++ ["Tweet from user: "] ++ [user_id] ++ ["forwarded to follower: "] ++ [follower_id]}
            state = Map.put(state, "user_details", user_details)
            end)

        # IO.inspect(state, label: "State after sending a tweet: ")
        {:noreply, state}
    end

    def handle_cast({:subscribe_to_tweet, user_id, tweetId} ,state) do
        # {tweet, id }= state["tweets"][tweetId]
        user_details = state["user_details"]
        user_details_id = state["user_details"][user_id]
        subscribed = user_details_id["subscribed"]

        user_details_id = Map.put(user_details_id, "subscribed", [state["tweets"][tweetId]] ++ subscribed)
        user_details = Map.put(user_details, user_id, user_details_id)
        state = Map.put(state, "user_details", user_details)
        {:noreply, state}
    end

    def handle_call({:get_users}, _from, state) do
        {:reply, state["users"], state}
    end

    def handle_call({:get_user_details, user_id}, _from, state) do
        {:reply, state["user_details"][user_id], state}
    end

    def handle_call({:get_followers, user_id}, _from, state) do
        {:reply, state["user_details"][user_id]["followers"], state}
    end

    def handle_call({:get_subscribed_tweets, user_id}, _from, state) do
        {:reply, state["user_details"][user_id]["subscribed"], state}
    end

    def handle_call({:get_retweets, user_id}, _from, state) do
        {:reply, state["user_details"][user_id]["retweets"], state}
    end

    def handle_call({:get_tweets_of_hashtag, hashtag}, _from, state) do
        hashtag_map = state["hashtags"][hashtag]
        tweets = []
        if hashtag_map != nil do
        keys = Map.keys(hashtag_map)
        if keys != nil do
            tweets = Enum.reduce(keys, [], fn(key, acc) -> acc ++ hashtag_map[key] end)
        end
        end
        {:reply, tweets, state}
    end

    def handle_call({:get_tweets_of_mention, mention}, _from, state) do
        mention_map = state["mentions"][mention]
        tweets = []
        if mention_map != nil do
            keys = Map.keys(mention_map)
            if keys != nil do
                tweets = Enum.reduce(keys, [], fn(key, acc) -> acc ++ mention_map[key] end)
            end
        end
        {:reply, tweets, state}
    end

    def handle_call({:get_username, user_id}, _from, state) do
        {:reply, state["user_details"][user_id]["username"], state}
    end

    def handle_call({:get_tweets, socket}, _from, state) do
        tweets = Enum.reduce(state["tweets"], %{}, fn({v, k}, acc ) -> Map.put(acc, v, elem(k, 0)) end)
        push socket, "tweets", tweets
        {:reply, state["tweets"], state}
    end

    def handle_call({:get_usernames, socket}, _from, state) do
        push socket, "usernames", state["usernames"]
        {:reply, state , state}
    end

    def handle_call({:print_user, user_id}, from, state) do
        IO.inspect(state["user_details"][user_id])
        {:reply,state["user_details"][user_id], state}
    end

    def handle_call({:print_state}, _from, state) do
        IO.inspect state
        {:reply, state , state}
    end
end

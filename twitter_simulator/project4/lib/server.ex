defmodule Server do

    def init(:ok) do
        # {:ok, %{"users" => [pid1, pid2..], "hashtags" => %{}, "user_details" => %{pid => %{"tweets" => [], "followers" =>[], "notifications" => %{source_pid => [tweet1, ...]}}}}}
        {:ok, %{"users" => %{}, "usernames" => %{} , "tweets" => %{}, "user_details" => %{}, "hashtags" => %{}, "mentions" => %{}}}
    end

    def handle_cast({:add_user, user_pid, user_name}, state) do
        users = state["users"]
        active_user = Map.put(state["users"], user_pid, Enum.random([true, false]))  # Set active = true initially
        state = Map.put(state, "users", active_user)
        username_map = Map.put(state["usernames"], user_name, user_pid)
        state = Map.put(state, "usernames", username_map)
        user_details = Map.get(state, "user_details")
        user_details = Map.put(user_details, user_pid, %{"username" => user_name, "tweets" => [], "retweets" => [], "followers" => [], "notifications" => %{}, "subscribed" => []})
        state = Map.put(state, "user_details", user_details)

        #  IO.inspect(state, label: "State after adding user: ")
        {:noreply, state}
    end

    def handle_cast({:add_follower, user_pid, follower_pid}, state) do
        #TODO Add checks if user doesn't exist
        user_details_pid = state["user_details"][user_pid]
        followers = user_details_pid["followers"]
        user_details_pid = Map.put(user_details_pid, "followers", [follower_pid | followers])
        user_details = state["user_details"]
        user_details = Map.put(user_details, user_pid, user_details_pid)
        state = Map.put(state, "user_details", user_details)

        # IO.inspect(state, label: "State after adding follower: ")
        {:noreply, state}
    end

    def handle_cast({:send_tweet, user_pid, tweet, hashtags, mentions, is_retweet}, state) do
        user_details_pid = state["user_details"][user_pid]

        if(is_retweet) do
            retweets = user_details_pid["retweets"]
            user_details_pid = Map.put(user_details_pid, "retweets", [tweet | retweets])
        else
            tweets = user_details_pid["tweets"]
            user_details_pid = Map.put(user_details_pid, "tweets", [tweet | tweets])

            # Update the hashtags map
            # %{"hashtags" => %{"hashtag": %{pid => []}}

            state = Enum.reduce(hashtags, state, fn(hashtag, state) ->
                hashtags_map = state["hashtags"]
                if hashtags_map[hashtag] == nil do
                    hashtags_map = Map.put(hashtags_map, hashtag, %{})
                end

                hashtag_details = hashtags_map[hashtag]

                if(hashtag_details[user_pid] != nil) do
                    hashtag_details = Map.put(hashtag_details, user_pid, [tweet] ++ hashtag_details[user_pid])
                else
                    hashtag_details = Map.put(hashtag_details, user_pid, [tweet])
                end

                hashtags_map = Map.put(hashtags_map, hashtag, hashtag_details)
                state = Map.put(state, "hashtags", hashtags_map)
            end)

            # Update the mentions map
            # %{"mentions" => %{"mention": %{pid => []}}

            state = Enum.reduce(mentions, state, fn(mention, state) ->

                mentions_map = state["mentions"]
                if mentions_map[mention] == nil do
                    mentions_map = Map.put(mentions_map, mention, %{})
                end

                mention_details = mentions_map[mention]

                if(mention_details[user_pid] != nil) do
                    mention_details = Map.put(mention_details, user_pid, [tweet | mention_details[user_pid]])
                else
                    mention_details = Map.put(mention_details, user_pid, [tweet])
                end

                mentions_map = Map.put(mentions_map, mention, mention_details)
                state = Map.put(state, "mentions", mentions_map)
            end)
        end

        # Add tweetId and tweet to generic collection
        tweets = Map.put(state["tweets"],Base.encode16(:crypto.hash(:sha256, tweet)) , {tweet, user_pid})
        state = Map.put(state, "tweets", tweets)


        user_details = state["user_details"]
        user_details = Map.put(user_details, user_pid, user_details_pid)
        state = Map.put(state, "user_details", user_details)

        followers = state["user_details"][user_pid]["followers"]
        #Sending tweet to every follower and adding it to their notifications
        #NOTE Outside scope of state not accessed inside Enum - Use recursion or Enum.reduce()
        state = Enum.reduce(followers, state, fn(follower_pid, state) ->
          user_details_pid = state["user_details"][follower_pid]
          notifications = user_details_pid["notifications"]
          if notifications[user_pid] != nil do
              notifications = Map.put(notifications, user_pid, [tweet | notifications[user_pid]])
            else
              notifications = Map.put(notifications, user_pid, [tweet])
          end
          user_details_pid = Map.put(user_details_pid, "notifications", notifications)
          user_details = state["user_details"]
          user_details = Map.put(user_details, follower_pid, user_details_pid)
          send(follower_pid, {:tweet, [tweet] ++ ["Tweet from user: "] ++ [user_pid] ++ ["forwarded to follower: "] ++ [follower_pid] })
          state = Map.put(state, "user_details", user_details)
         end)

        # IO.inspect(state, label: "State after sending a tweet: ")
        {:noreply, state}
    end

    def handle_cast({:subscribe_to_tweet, user_pid, tweetId} ,state) do
        # {tweet, pid }= state["tweets"][tweetId]
        user_details = state["user_details"]
        user_details_pid = state["user_details"][user_pid]
        subscribed = user_details_pid["subscribed"]

        user_details_pid = Map.put(user_details_pid, "subscribed", [tweetId] ++ subscribed)
        user_details = Map.put(user_details, user_pid, user_details_pid)
        state = Map.put(state, "user_details", user_details)
        {:noreply, state}
    end

    def handle_call({:get_users}, _from, state) do
        {:reply, state["users"], state}
    end

    def handle_call({:get_user_details, user_pid}, _from, state) do
        {:reply, state["user_details"][user_pid], state}
    end

    def handle_call({:get_followers, user_pid}, _from, state) do
        {:reply, state["user_details"][user_pid]["followers"], state}
    end

    def handle_call({:get_subscribed_tweets, user_pid}, _from, state) do
      {:reply, state["user_details"][user_pid]["subscribed"], state}
    end

    def handle_call({:get_retweets, user_pid}, _from, state) do
      {:reply, state["user_details"][user_pid]["retweets"], state}
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

     def handle_call({:get_username, user_pid}, _from, state) do
      {:reply, state["user_details"][user_pid]["username"], state}
    end

    def handle_call({:get_tweets}, _from, state) do
      {:reply, state["tweets"], state}
    end

    def handle_call(:get_state, _from, state) do
      {:reply, state , state}
    end

    def handle_call({:print_user, user_pid}, from, state) do
      IO.inspect(state["user_details"][user_pid])
      {:reply,state["user_details"][user_pid], state}
    end

end

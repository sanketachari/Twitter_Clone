defmodule Project4 do

  def init_users(server, total_users) do
    Enum.map(1..total_users, fn x -> pid = spawn(Project4, :listen_for_tweets, [])
      Client.add_user(server, pid, "user"<> to_string(x) )
      pid
    end)
  end

  def add_random_followers(server, users) do
    total_users = length(users)
    max_followers = trunc(:math.ceil(total_users * 0.2))

    Enum.each(0..total_users - 1, fn index -> user = Enum.at(users, index)
      total_followers = Enum.random(1..max_followers)
      others = List.delete(users, user)
      followers = Enum.take_random(others, total_followers)
      Enum.each(followers, fn follower -> Client.add_follower(server, user, follower) end)
    end)
  end

  def send_tweet(server, users) do

    #Get usernames
    total_users = length(users)
    user_names = []

    user_names = Enum.map(users, fn user ->  Client.get_username(server, user) end)

    Enum.each(users, fn user ->
      [u1, u2] = Enum.take_random(user_names , 2)
      tweet1 = "Some random tweet #randomtweet #newtweet @" <> u1 <> " @" <> u2
      [u1, u2] = Enum.take_random(user_names , 2)
      tweet2 = "This is #mytweet some tweet #sometweet @" <> u1 <> " @" <> u2
      [u1, u2] = Enum.take_random(user_names , 2)
      tweet3 = "Another tweet, study #DOS and do #projects @" <> u1 <> " @" <> u2

      [tweet] = Enum.take_random([tweet1, tweet2, tweet3], 1)
      # IO.inspect tweet

      hashtags = extract_data(tweet, "#(\\S+)") #Extract hashtags in a tweet
      mentions = extract_data(tweet, "@(\\S+)") #Extract mentions in a tweet

      # Randomly tweet or retweet
      if(Enum.random([true, false])) do
        Client.send_tweet(server, user, tweet, hashtags, mentions, true) # Retweet
      else
        Client.send_tweet(server, user, tweet, hashtags, mentions, false) # Tweet
      end
    end)
  end

  def extract_data(tweet, regex) do
    {:ok, pattern} = Regex.compile(regex)
    matches = Regex.scan(pattern, tweet)
    Enum.map(matches, fn match -> Enum.at(match, 0) end)
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

  def main(args \\ []) do

    {_, input, _} = OptionParser.parse(args)

    if length(input) == 1 do
      numNodes = String.to_integer(List.first(input))

      if numNodes < 10 do
        numNodes = 10
      end
    else
      numNodes = 10
    end

    {_, server} = Client.start_link("")

    users = init_users(server, numNodes)
    # IO.inspect(users)
    add_random_followers(server, users)
    send_tweet(server, users)

    # Subscribe to random tweets
    subscribe_to_tweet(server, users)

    # Client.print_state(server)

    state = Client.get_state(server)

    IO.puts ""
    IO.inspect numNodes, label: "Number of users present"
    IO.puts ""

    IO.inspect length(Map.keys(state["tweets"])), label: "Total tweets till now"
    IO.puts ""

    tweets = Client.query_tweets_of_hashtag(server, "#DOS")
    IO.inspect length(tweets), label: "Total tweets with hashtag #DOS "
    IO.puts "Tweets (Showing Max 10): "
    IO.inspect Enum.take(tweets, 10)
    IO.puts ""

    tweets = Client.query_tweets_of_mention(server, "@user1")
    IO.inspect length(tweets), label: "Total tweets with mention @user1"
    IO.puts "Tweets (Showing Max 10): "
    IO.inspect Enum.take(tweets, 10)
    IO.puts ""

    IO.puts "Printing user1 details:"
    Client.print_user(server, Enum.at(users, 0))

    receive do
      msg -> IO.puts(msg)
    end

  end

  #NOTE Elixir does not have nested functions
  def listen_for_tweets() do
    #Receiving tweet from user following
    receive do
      {:tweet, tweet} -> #IO.inspect(tweet)
    end
    listen_for_tweets()
  end

end

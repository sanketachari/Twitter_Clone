defmodule Client do
    use GenServer

    def start_link(x) do
        GenServer.start_link(Server, :ok)
    end

    def add_user(server, user_pid, user_name) do
        GenServer.cast(server, {:add_user, user_pid, user_name})
    end

    def add_follower(server, user_pid, follower_pid) do
        GenServer.cast(server, {:add_follower, user_pid, follower_pid})
    end

    def send_tweet(server, user_pid, tweet, hashtags, mentions, is_retweet) do
        GenServer.cast(server, {:send_tweet, user_pid, tweet, hashtags, mentions, is_retweet})
    end

    def subscribe_to_tweet(server, user_pid, tweetId) do
        GenServer.cast(server, {:subscribe_to_tweet, user_pid, tweetId})
    end

    def query_subscribed_tweets(server, user_pid) do
        GenServer.call(server, {:query_subscribed_tweets, user_pid})
    end

    def query_retweets(server, user_pid) do
        GenServer.call(server, {:get_retweets, user_pid})
    end

    def query_tweets_of_hashtag(server, hashtag) do
        GenServer.call(server, {:get_tweets_of_hashtag, hashtag})
    end

    def query_tweets_of_mention(server, mention) do
        GenServer.call(server, {:get_tweets_of_mention, mention})
    end

    def get_users(server) do
        GenServer.call(server, {:get_users})  #Returns a list of users
    end

    def get_followers(server, user_pid) do
        GenServer.call(server, {:get_followers, user_pid})  #Returns a list of user followers
    end

    def get_username(server, user_pid) do
        GenServer.call(server, {:get_username, user_pid})  #Returns username
    end

    def get_tweets(server) do
        GenServer.call(server, {:get_tweets})  #Returns a list of user tweets
    end

    def get_user_details(server, user_pid) do
        GenServer.call(server, {:get_user_details, user_pid})
    end

    def get_state(server) do
        GenServer.call(server, :get_state)
    end

     def print_user(server, user_pid) do
        GenServer.call(server, {:print_user, user_pid})
    end
end

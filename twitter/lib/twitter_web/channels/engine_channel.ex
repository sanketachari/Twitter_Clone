defmodule TwitterWeb.EngineChannel do
  use TwitterWeb, :channel
  alias TwitterWeb.Server

  def join("engine", payload, socket) do
    id = Map.get(payload, "id")
    Server.add_user(id, "user"<> id, socket)
    {:ok, socket}
  end

  def handle_in("add_follower", payload, socket) do
    id = Map.get(payload, "id")
    follower_id = Map.get(payload, "follower")
    Server.add_follower(id, follower_id)
    :timer.sleep(1000)
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("get_usernames", payload, socket) do
    Server.get_usernames(socket)
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("get_tweets", payload, socket) do
    Server.get_tweets(socket)
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("subscribe_to_tweet", payload, socket) do
    id = Map.get(payload, "id")
    tweetId = Map.get(payload, "tweetId")
    Server.subscribe_to_tweet(id, tweetId)
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("send_tweet", payload, socket) do
    user = Map.get(payload, "id")
    tweet = Map.get(payload, "tweet")
    hashtags = Map.get(payload, "hashtags")
    mentions = Map.get(payload, "mentions")
    isRetweet = Map.get(payload, "isRetweet")
    Server.send_tweet(user, tweet, hashtags, mentions, isRetweet)
    :timer.sleep(1000)
    {:reply, {:ok, payload}, socket}
  end
end

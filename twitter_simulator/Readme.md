### Instructions to RUN:

1) Make sure epmd daemon is running. Run epmd -daemon
2) Run following commands from the directory which has mix.exs
	 mix escript.build
     ./project4 numNodes
3) numNodes has to be between 10 to 10000
	
4) After printing of user details is completed, enter ‘ctrl + c’ to stop the execution. 

### Working: 

1.	Simulation of Twitter Engine.
2.	Tweet, Retweet, Subscribe to tweets, hashtag, mention, live connection
3.	Query hashtags, mentions

### Largest Simulation: 

10,000 active users each tweeting at least 1 tweet
Time Required:   3min 15.730s

5,000 active users each tweeting at least 1 tweet
Time Required:   43.764s

100 active users each tweeting at least 1 tweet:
Time Required: 0.467s


### Sample Outputs: 

Example 1: Considering 100 live users 


Sankets-MacBook-Pro:project4 sanket$ ./project4 100

Number of users present: 100

Total tweets till now: 100

Total tweets with hashtag #DOS : 15
Tweets (Showing Max 10):
["Another tweet, study #DOS and do #projects @user86 @user97",
 "Another tweet, study #DOS and do #projects @user30 @user14",
 "Another tweet, study #DOS and do #projects @user95 @user28",
 "Another tweet, study #DOS and do #projects @user22 @user63",
 "Another tweet, study #DOS and do #projects @user7 @user54",
 "Another tweet, study #DOS and do #projects @user80 @user44",
 "Another tweet, study #DOS and do #projects @user78 @user89",
 "Another tweet, study #DOS and do #projects @user50 @user70",
 "Another tweet, study #DOS and do #projects @user15 @user62",
 "Another tweet, study #DOS and do #projects @user9 @user33"]

Total tweets with mention @user1: 1
Tweets (Showing Max 10):
["This is #mytweet some tweet #sometweet @user1 @user21"]



Printing user1 details:
%{"followers" => [#PID<0.125.0>, #PID<0.175.0>, #PID<0.164.0>, #PID<0.124.0>,
   #PID<0.167.0>, #PID<0.107.0>, #PID<0.156.0>, #PID<0.133.0>, #PID<0.137.0>],
  "notifications" => %{#PID<0.82.0> => ["Another tweet, study #DOS and do #projects @user31 @user59"],
    #PID<0.94.0> => ["Some random tweet #randomtweet #newtweet @user55 @user51"],
    #PID<0.117.0> => ["Some random tweet #randomtweet #newtweet @user92 @user94"],
    #PID<0.125.0> => ["This is #mytweet some tweet #sometweet @user86 @user21"],
    #PID<0.157.0> => ["Another tweet, study #DOS and do #projects @user13 @user35"],
    #PID<0.165.0> => ["Another tweet, study #DOS and do #projects @user77 @user79"],
    #PID<0.175.0> => ["This is #mytweet some tweet #sometweet @user79 @user26"]},
  "retweets" => ["This is #mytweet some tweet #sometweet @user65 @user52"],
  "subscribed" => [], "tweets" => [], "username" => "user1"}



### Implementation Details:

1.	We have used Gen Server for twitter engine. This server is the single process which will keep the track of each & every user, tweet, subscription, retweet, follower, hashtag and mention.
2.	This gen server acts as a backend for the twitter simulation. 
Gen server’s state is as following

State of Engine: 
%{ "users" => %{pid1 => true/false, pid2 => true/false,....}, 
     "usernames" => %{"usernam1" => pid1, "usernam2" => pid2,....}
     "tweets" => %{"tweetId1" => {tweet1, pid1}, "tweetId2" => {tweet2, pid2}....}
     "user_details" => %{ pid => 
                                                %{  "username" => "Unique name"
                                                    "tweets" => [], 
                                                    "retweets" => [],
                                                    "followers" =>[], 
                                                    "notifications" => %{source_pid => [tweet1, ...]},
                                                    "subscribed" => [tweetId1, tweetId2, ....]
                                                 }
                                       }
    "hashtags" =>  %{ "hashtag1" => %{pid => [tweet1, tweet2, ...]}, ...}
    "mentions" =>  %{ "mention1" => %{"username1" => [tweet1, tweet2, ...]}, ...}            
 }

In this state table, we maintain collection of hashtags, mentions, total tweets, users, usernames and each user’s details. Each user has status true or false which indicates online or offline status.

3.	Initially we create total number of users which is taken from the command line argument. After this we add followers for each user randomly.

4.	We have randomly kept all the users’ status as online or offline. In either case of tweet or retweet, we update the state table of twitter engine.

5.	Also, each user can subscribe to a random tweet. And this subscription is also random based on Enum.random([true, false])

6.	Then each user can send tweet and retweet randomly. We have taken 3 sample tweets as follows: 

      tweet1 = "Some random tweet #randomtweet #newtweet @randomuser1 @randomuser2
      tweet2 = "This is #mytweet some tweet #sometweet @randomuser1 @randomuser2
      tweet3 = "Another tweet, study #DOS and do #projects @randomuser1 @randomuser2

Note that, we have total 6 hashtags: #randomtweet, #newtweet, #mytweet, #sometweet, #DOS, #projects

And 2 mentions:
@randomuser1, @randomuser2

These mentions are usernames of 2 users which are selected randomly.

In this simulation, we have considered above 3 tweets with hashtags and mentions. Out of these 3 tweets 1 tweet will be selected randomly and that tweet is broadcasted to the followers. Retweet is also based on the same logic.

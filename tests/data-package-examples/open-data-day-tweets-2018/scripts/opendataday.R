# install and load R package for Twitter

install.packages(twitteR)
library(twitteR)

# Set up Twitter API and Access Tokens. Create this in dev.twitter.com

api_key <- "YOUR_API_KEY"
api_secret <- "YOUR_API_SECRET"
access_token <- "YOUR_ACCESS_TOKEN"
access_secret <- "YOUR_ACCESS_SECRET"

setup_twitter_oauth(api_key, api_secret, access_token, access_secret)

# read tweets from the two official open data day hashtags, #opendataday and #odd18

opendataday <- searchTwitteR("#opendataday", n = 18000)
odd18 <- searchTwitteR("#odd18", n = 18000)

# view list of tweets mined from the #opendataday and #odd18 hashtags
opendataday
odd18

# convert the mined list of tweets from either hashtag to a dataframe

opendataday_df <- twListToDF(opendataday)
odd18_df <- twListToDF(odd18)

# combine dataframes from the two hashtags using the row bind function

alltweets_df <- rbind(opendataday_df, odd18_df)

# write your scraped data to a csv file

write.csv(tweets_opendataday_df, file="data/opendataday_raw.csv")
write.csv(tweets_odd18_df, file="data/odd18_raw.csv")
write.csv(alltweets_df, file="data/allopendatadaytweets.csv")

# analysis 1: how many open data day attendees tweeted from android phones?


library(dplyr)

android_tweets <- filter(alltweets_df, grepl("Twitter for Android", statusSource))
tally(android_tweets)


# analysis 2: which tweets mention GitHub resources?

# install and load dplyr library for data analysis

install.packages(dplyr)
library(dplyr)

# filter out tweets with the github url in them, then read tweets for context

github_resources <- filter(alltweets_df, grepl("github.com", statusSource))
tally(github_resources)

# analysis 3: where in the world did people send open data day tweets from?

# convert latitude and longitude variables to numeric data types (char by default)

alltweets_df$latitude <- as.numeric(alltweets_df$latitude)
alltweets_df$longitude <- as.numeric(alltweets_df$longitude)

# install and load the leaflet library

install.packages(leaflet)
library(leaflet)

# create simple map using the leaflet library to show where tweets are from

map <- leaflet() %>%
  addTiles() %>%
  addCircles(data = alltweets_df, lat = ~ latitude, lng = ~ longitude)

# view map

map

# before sharing, strip down tweets data to comply with Twitter's terms of use. Final dataset has tweet IDs and retweet count

notretweets_df <- dplyr::filter(alltweets_df, grepl("FALSE", isRetweet))
subsetoftweets <- select(notretweets_df,id, retweetCount)
write.csv(subsetoftweets, file="data/subsetofopendatadaytweets.csv")

# install and load datapackage-r library

install.packages("devtools")
devtools::install_github("frictionlessdata/datapackage-r")
library(datapackage.r)

# load CSV file and infer schema and create a datapackage. Alternatively, use the UI at create.frictionlessdata.io

filepath = 'data/subsetoftweets.csv'
schema = tableschema.r::infer(filepath)

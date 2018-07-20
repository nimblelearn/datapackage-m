# Open Data Day 2018 Tweets 

[The 7th International Open Data Day](http://opendataday.org) was marked on March 3, 2018. On the day, people used the [#opendataday](https://twitter.com/hashtag/OpenDataDay) and [#odd18](https://twitter.com/hashtag/ODD18) hashtags to share insights from over 400 community events.

## Data

The data was obtained on March 7, 2018 from two hashtags on Twitter: [#opendataday](https://twitter.com/hashtag/OpenDataDay) and [#odd18](https://twitter.com/hashtag/ODD18). 

This data package contains a [stripped-down version](data/subsetofopendatadaytweets.csv) of the tweets data, in line with [Twitter's Developer Policy](https://developer.twitter.com/en/developer-terms/policy.html). Other resources included herein:
- a [datapackage.json](datapackage.json) file with schema and metadata
- an [R script](scripts/opendataday.R) used to mine Open Data Day tweets via the Twitter Search API
- a [simple map](docs/geotagged_tweets.png) generated from the analysis of tweets with geotagged information

## Preparation

To obtain / update the data, you'll need

- R v3.4.3 ([installation instructions](https://www.r-project.org))
- Twitter API and access tokens from [http://apps.twitter.com](http://apps.twitter.com)

Run [scripts/opendataday.R](scripts/opendataday.R) to obtain your own copy of the data and read the blog post detailing the data collection, analysis and publishing process for this data package [here](http://okfnlabs.org/blog/2018/03/08/open-data-day-tweets.html).

## License

The data is licensed under [Twitter's Developer Policy](https://developer.twitter.com/en/developer-terms/policy.html). Everything else is licensed under the [CC0 Public Domain Waiver](https://creativecommons.org/publicdomain/zero/1.0/).

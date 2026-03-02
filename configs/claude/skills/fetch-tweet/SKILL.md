---
name: fetch-tweet
description: Use when the user shares a tweet or X post URL (x.com, twitter.com) and wants its contents read. Fetches tweet data via the FxTwitter API without authentication.
---

# Fetch Tweet

## How to Fetch

Use the **FxTwitter API** — no authentication required.

```
https://api.fxtwitter.com/{username}/status/{tweet_id}
```

## Steps

1. Extract the tweet ID from any `x.com` or `twitter.com` URL
2. Build the FxTwitter URL: `https://api.fxtwitter.com/{username}/status/{tweet_id}`
3. Use `WebFetch` on the FxTwitter URL to retrieve the tweet
4. The response is clean JSON with full text, author info, engagement stats, and media

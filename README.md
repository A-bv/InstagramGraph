# InstagramGraph

Swift package for the Instagram Graph API flows used by PackTags.

## Tests

Run the regular unit tests without network or credentials:

```sh
swift test
```

Run live Meta Graph API checks with a token generated from Meta Graph API Explorer:

```sh
META_GRAPH_TOKEN="..." \
META_PAGE_ID="..." \
META_IG_BUSINESS_ID="..." \
META_TEST_HASHTAG="travel" \
swift test --filter MetaLiveTests
```

The live tests are skipped when the required environment variables are missing. Do not commit tokens or account secrets.


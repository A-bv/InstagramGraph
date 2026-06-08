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

Reproduce Meta's high-volume hashtag caption limit probe:

```sh
META_RUN_EXPENSIVE_CAPTION_PROBE=1 \
META_GRAPH_TOKEN="..." \
META_IG_BUSINESS_ID="..." \
META_TEST_HASHTAG="cars" \
swift test --filter MetaLiveTests/testExpensiveCaptionProbeAgainstMeta
```

This optional probe expects Meta to reject `top_media` with `fields=id,caption&limit=10`
using the "Please reduce the amount of data" error. It documents why the package
uses a conservative page size when requesting captions.

The live tests are skipped when the required environment variables are missing. Do not commit tokens or account secrets.

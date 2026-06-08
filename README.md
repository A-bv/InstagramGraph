# InstagramGraph

`InstagramGraph` is a Swift package for Instagram Graph API flows used by iOS apps.

It is written in Swift, targets iOS 15+, and is designed for apps that need to call Meta's Instagram Graph API without mixing endpoint construction, credential handling, networking, and response decoding directly into UI code.

The package currently covers:

- Instagram hashtag search with top media results.
- Instagram Business / Creator profile analytics data.
- Meta Graph API endpoint building and response decoding.
- Live integration tests that can be run against Meta with a token from Graph API Explorer.

## Why Use It

Meta's Instagram Graph API is powerful, but small API changes can break an app quickly: fields can become expensive, permissions can change, and endpoint responses can differ from the documentation.

This package keeps that logic isolated from the app:

- The iOS app can depend on a typed Swift API instead of raw Graph URLs.
- Meta-specific request details stay in one package.
- Live tests can detect API regressions independently from the app.
- Apps can choose product-level behavior, such as how many profile media items to fetch for analytics.

## Installation

Add the package with Swift Package Manager:

```text
https://github.com/A-bv/InstagramGraph
```

Then import it where needed:

```swift
import InstagramGraph
```

## Basic Usage

Create a service with the default settings-backed credential provider:

```swift
let graphService = InstagramGraphService()
```

Search hashtag media:

```swift
graphService.searchHashtag(searchedHashtag: "travel") { result in
    switch result {
    case .success(let media):
        print(media)
    case .failure(let error):
        print(error)
    }
}
```

Load profile data for analytics:

```swift
graphService.loadProfileForAnalytics { result in
    // Fetches profile media without forcing a package-level limit.
}
```

If your app wants to cap the number of profile media items, pass the limit explicitly:

```swift
graphService.loadProfileForAnalytics(mediaLimit: 12) { result in
    // Fetches up to 12 profile media items for analytics.
}
```

The package does not decide how many profile posts your app should display or analyze. That choice belongs to the app.

## Tests

### Unit Tests

Run the regular unit tests without network access or Meta credentials:

```sh
swift test
```

These tests validate endpoint construction, decoding, and repository behavior with local fixtures or fakes.

### Live Meta Graph API Tests

Live tests call the real Meta Graph API. They are useful when you want to verify that the package still matches Meta's current API behavior.

Open Meta's Graph API Explorer:

[https://developers.facebook.com/tools/explorer/](https://developers.facebook.com/tools/explorer/)

In the Explorer:

1. Select your Meta app.
2. Select a user or page token that has access to the connected Facebook Page and Instagram Business / Creator account.
3. Add the permissions needed by the endpoint you want to test, for example `instagram_basic`, `pages_show_list`, and any page/business permission required by your setup.
4. Click **Generate Access Token** in the access token panel.
5. Copy the generated token and pass it to the test command through environment variables.

Do not hardcode or commit tokens.

Run every live test:

```sh
META_GRAPH_TOKEN="..." \
META_PAGE_ID="..." \
META_IG_BUSINESS_ID="..." \
META_TEST_HASHTAG="travel" \
swift test --filter MetaLiveTests
```

Environment variables:

- `META_GRAPH_TOKEN`: access token copied from Meta Graph API Explorer.
- `META_PAGE_ID`: Facebook Page id returned by `/me/accounts`.
- `META_IG_BUSINESS_ID`: Instagram Business / Creator account id connected to the page.
- `META_TEST_HASHTAG`: public hashtag used for hashtag search tests, for example `travel` or `cars`.
- `META_GRAPH_VERSION`: optional Graph API version override. Defaults to the package production version.
- `META_MEDIA_LIMIT`: optional profile media limit used by `testAnalyticsProfileEndpointAgainstMeta`.

Run only the profile analytics live test:

```sh
META_GRAPH_TOKEN="..." \
META_IG_BUSINESS_ID="..." \
swift test --filter MetaLiveTests/testAnalyticsProfileEndpointAgainstMeta
```

Run the same profile analytics test with an explicit media limit:

```sh
META_GRAPH_TOKEN="..." \
META_IG_BUSINESS_ID="..." \
META_MEDIA_LIMIT=12 \
swift test --filter MetaLiveTests/testAnalyticsProfileEndpointAgainstMeta
```

Run only the hashtag live test:

```sh
META_GRAPH_TOKEN="..." \
META_IG_BUSINESS_ID="..." \
META_TEST_HASHTAG="cars" \
swift test --filter MetaLiveTests/testHashtagSearchAgainstMeta
```

### Optional Caption Volume Probe

This diagnostic test is not part of the normal live test workflow. It intentionally reproduces a Meta API failure observed when requesting too many `top_media` results with `caption`.

Run it only when you want to confirm whether Meta still rejects high-volume caption requests:

```sh
META_RUN_EXPENSIVE_CAPTION_PROBE=1 \
META_GRAPH_TOKEN="..." \
META_IG_BUSINESS_ID="..." \
META_TEST_HASHTAG="cars" \
swift test --filter MetaLiveTests/testExpensiveCaptionProbeAgainstMeta
```

The probe expects Meta to reject `top_media` with `fields=id,caption&limit=10` using a "Please reduce the amount of data" error. This documents why hashtag media requests use a conservative page size when captions are requested.

Live tests are skipped when required environment variables are missing.

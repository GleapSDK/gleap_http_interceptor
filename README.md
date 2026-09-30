# Gleap Flutter HTTP Interceptor

![Gleap Flutter SDK Intro](https://raw.githubusercontent.com/GleapSDK/Gleap-iOS-SDK/main/Resources/GleapHeaderImage.png)

Capture HTTP request and response logs with the [Gleap Flutter SDK](https://docs.gleap.ai/documentation/flutter/README). Attach network context to in-app bug reports so your team can investigate customer issues.

[Network logging documentation](https://docs.gleap.ai/documentation/flutter/network-logs) · [Gleap](https://www.gleap.ai)

## Docs & Examples

Checkout our [documentation](https://docs.gleap.ai/documentation/flutter/README) for full reference. Include the following dependency in your pubspec.yaml:

```dart
dependencies:
  gleap_http_interceptor: "^2.0.0"
```

**Flutter v2 Support**

If you are using Flutter < v3, please import the gleap_sdk as shown below:

```dart
dependencies:
  gleap_http_interceptor:
    git:
      url: https://github.com/GleapSDK/gleap_http_interceptor.git
      ref: flutter-v2

```

Version 2.0 requires `gleap_sdk` 19.0.0 or newer and [http_interceptor](https://pub.dev/packages/http_interceptor) 3.x (Dart 3.8 / Flutter 3.32 or newer).

```dart
Client client = InterceptedClient.build(interceptors: [
    GleapHttpInterceptor(),
]);

client.get(Uri.parse("https://example.com"));
```

Add the interceptor as the last one, so it logs the request as it is sent.

**What is logged**

Each request is logged with its full url, method, start time, duration, request and response headers and text bodies (capped at 150 KB; multipart requests as a summary of fields and file names). The interceptor never changes a request. Response bodies are observed while your app reads them (every chunk is passed on unchanged); binary and streaming bodies are replaced by a marker and not read at all. A request is logged once your app has read its response body.

Requests that fail without a response (no connection, timeout) are not logged, because http_interceptor does not pass errors to interceptors.

Gleap keeps the newest 30 requests. To keep sensitive data out of the logs, use `Gleap.setNetworkLogPropsToIgnore(propsToIgnore: ['password', 'token'])` (removes headers, JSON keys, form fields and query parameters with these names) and `Gleap.setNetworkLogsBlacklist(blacklist: ['/internal/'])` (skips requests whose url contains an entry). Authorization and cookie headers are always masked.
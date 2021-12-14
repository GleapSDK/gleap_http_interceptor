# Gleap Http Interceptor

![Gleap Flutter SDK Intro](https://raw.githubusercontent.com/GleapSDK/iOS-SDK/main/imgs/gleapheader.png)

A Http Interceptor for the [Gleap SDK](https://pub.dev/packages/gleap_sdk).

# Report and Fix Bugs the Easy Way

Gleap helps developers build the best software faster. It is your affordable in-app bug reporting tool for apps, websites and industrial applications.

Checkout our [website](https://gleap.io) to learn more about gleap.

## Docs & Examples

Checkout our [documentation](https://docs.gleap.io/docs/flutter-sdk) for full reference. Include the following dependency in your pubspec.yml:

```dart
dependencies:
  gleap_http_interceptor: "^1.0.4"
```

```dart
Client client = InterceptedClient.build(interceptors: [
    GleapHttpInterceptor(),
]);

client.get(Uri.parse("https://example.com"));
```
## 2.0.0
Breaking: requires `gleap_sdk` 18.2.0 or newer and `http_interceptor` 3.x (`GleapHttpInterceptor` implements `HttpInterceptor`), Dart 3.8 / Flutter 3.32. Version 1.x no longer compiled with current http_interceptor versions (`RequestData` / `ResponseData` were removed).
Requests are logged through `Gleap.logNetworkRequest`, so all interceptors share one list of the newest 30 requests instead of each instance overwriting the others, and the list is handed to the native SDK at most every 500 ms instead of on every request.
Requests are now logged with their start time and duration, the full url, the request headers and body (text bodies; multipart requests as a summary of fields and file names, never file contents; streamed requests as a marker) and the response status, reason phrase, headers and text body (capped at 150 KB).
Response bodies are observed while your app reads them: every chunk is passed on unchanged and at most 150 KB is copied. Binary and streaming bodies (server-sent events, ndjson, grpc) are not read at all.
Requests that fail without a response (no connection, timeout) are not logged, because http_interceptor does not pass errors to interceptors.
Removed the public `networkLogs` ring buffer field.

## 1.2.4
Removed upper bound

## 1.2.3
Updated the `http` dependency to support a wider range of versions 

## 1.2.2
Made network logs working for silent crash reports

## 1.2.0
Support Gleap widget v7

## 1.1.0
Added minimum Gleap SDK version

## 1.0.8
Updated Gleap SDK

## 1.0.7
Updated Gleap SDK

## 1.0.6
Updated Gleap SDK

## 1.0.5
Updated Gleap SDK

## 1.0.4
Updated Gleap SDK

## 1.0.3
Fixed Android issue, updated Gleap SDK

## 1.0.2
Updated Gleap SDK

## 1.0.1
Updated Gleap SDK

## 1.0.0
Initial release
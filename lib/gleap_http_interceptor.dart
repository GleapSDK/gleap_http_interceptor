library gleap_http_interceptor;

import 'package:gleap_sdk/gleap_sdk.dart';
import 'package:gleap_sdk/helpers/network_response_type_helper.dart';
import 'package:gleap_sdk/models/gleap_network_log_models/gleap_network_log_model/gleap_network_log_model.dart';
import 'package:gleap_sdk/models/gleap_network_log_models/gleap_network_request_model/gleap_network_request_model.dart';
import 'package:gleap_sdk/models/gleap_network_log_models/gleap_network_response_model/gleap_network_response_model.dart';
import 'package:gleap_sdk/models/ring_buffer_model/ring_buffer_model.dart';
import 'package:http_interceptor/http_interceptor.dart';

class GleapHttpInterceptor implements InterceptorContract {
  RingBuffer<GleapNetworkLog> networkLogs = RingBuffer<GleapNetworkLog>(20);

  GleapHttpInterceptor() {
    Gleap.registerListener(
      actionName: 'feedbackFlowStarted',
      callbackHandler: (_) {
        Gleap.attachNetworkLogs(networkLogs: networkLogs.toList());
      },
    );
  }

  @override
  Future<RequestData> interceptRequest({required RequestData data}) async {
    return data;
  }

  @override
  Future<ResponseData> interceptResponse({required ResponseData data}) async {
    final GleapNetworkLog gleapNetworkLog = GleapNetworkLog(
      type:
          data.method != null ? data.method.toString().split('.').last : 'GET',
      url: data.url,
      date: DateTime.now(),
      request: GleapNetworkRequest(
        headers: data.request?.headers,
        payload: data.request?.body,
      ),
      response: GleapNetworkResponse(
        status: data.statusCode,
        responseText: NetworkResponseTypeHelper.getType(data: data.body),
      ),
    );
    networkLogs.add(gleapNetworkLog);

    return data;
  }
}

import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laoo/core/api/api_client.dart';
import 'package:laoo/core/network/http_service.dart';

void main() {
  test('AI test can wait for a slow local model response', () async {
    final httpClient = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return http.Response(jsonEncode({'intent': 'repair.create_own'}), 200);
    });
    final api = ApiClient(httpService: HttpService(client: httpClient));
    await expectLater(api.post('/api/assistant/intent-test',
        body: {'text': 'คอมไม่ติด'}, authenticated: false,
        timeout: const Duration(milliseconds: 20)), throwsA(isA<TimeoutException>()));
    final value = await api.post('/api/assistant/intent-test',
        body: {'text': 'คอมไม่ติด'}, authenticated: false,
        timeout: const Duration(milliseconds: 300));
    expect(value['intent'], 'repair.create_own');
    api.dispose();
  });
}

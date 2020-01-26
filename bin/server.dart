import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crdt/crdt.dart';
import 'package:crdt/src/hive_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

const _hostname = 'localhost';

void main(List<String> args) async {
  var parser = ArgParser()..addOption('port', abbr: 'p');
  var result = parser.parse(args);

  var portStr = result['port'] ?? Platform.environment['PORT'] ?? '8080';
  var port = int.tryParse(portStr);

  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    exitCode = 64;
    return;
  }

  await Server().serve(port);
}

class Server {
  Crdt crdt;

  Future<void> serve(int port) async {
    var home = Platform.environment['HOME'];
    var store = await HiveStore.create('$home/.crdt-server', 'server');
    crdt = Crdt(store);

    var router = Router()
      ..get('/', _getCrdtHandler)
      ..post('/', _postCrdtHandler)
      ..get('/<.*>', _getRecordHandler)
      ..post('/<.*>', _postRecordHandler)
      ..delete('/<.*>', _deleteRecordHandler);

    var server = await io.serve(router.handler, _hostname, port);
    print('Serving at http://${server.address.host}:${server.port}');
  }

  Response _getCrdtHandler(Request request) => _crdtResponse();

  Future<Response> _postCrdtHandler(Request request) async {
    var map =
        (json.decode(await request.readAsString()) as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, Record.fromMap(value)));
    try {
      crdt.merge(map);
      return _crdtResponse();
    } on ClockDriftException catch (e) {
      return _errorResponse(e);
    }
  }

  Future<Response> _getRecordHandler(Request request) async {
    var key = request.url.path;
    var record = crdt[key];
    if (record == null) return Response.notFound('Not found: $key');
    var body = jsonEncode(record);
    return Response.ok(body);
  }

  Future<Response> _postRecordHandler(Request request) async {
    var key = request.url.path;
    var map = json.decode(await request.readAsString());
    try {
      crdt[key] = map['value'];
      return _crdtResponse();
    } on ClockDriftException catch (e) {
      return _errorResponse(e);
    }
  }

  Future<Response> _deleteRecordHandler(Request request) async {
    var key = request.url.path;
    crdt.delete(key);
    return _crdtResponse();
  }

  Response _crdtResponse() {
    var body = json.encode(crdt.map);
    return Response.ok(body);
  }

  Response _errorResponse(Exception e) => Response(412, body: '$e');
}

import 'package:crdt/crdt.dart';

void main() {
  var crdt = MapCrdt('node_id');

  // Insert a record
  crdt.put('a', 1);
  // Read the record
  print('Record: ${crdt.get('a')}');

  // Export the CRDT as Json
  final json = crdt.toJson();
  // Send to remote node
  final remoteJson = sendToRemote(json);
  // Merge remote CRDT with local
  crdt.mergeJson(remoteJson);
  // Verify updated record
  print('Record after merging: ${crdt.get('a')}');
}

// Mock sending the CRDT to a remote node and getting an updated one back
String sendToRemote(String json) {
  final hlc = Hlc.now('another_nodeId');
  return '{"a":{"hlc":"$hlc","value":2}}';
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ServerClockService {
  ServerClockService._();

  static final ServerClockService instance = ServerClockService._();

  Duration _offset = Duration.zero;
  DateTime? _lastSyncedAt;
  Future<void>? _syncing;

  DateTime now() => DateTime.now().add(_offset);

  bool get hasFreshSync =>
      _lastSyncedAt != null &&
      DateTime.now().difference(_lastSyncedAt!) < const Duration(minutes: 10);

  Future<void> ensureSynced({bool force = false}) {
    if (!force && hasFreshSync) {
      return Future<void>.value();
    }
    final active = _syncing;
    if (active != null) {
      return active;
    }
    final completer = Completer<void>();
    _syncing = completer.future;
    _sync(force: force).then(completer.complete).catchError((Object error, _) {
      completer.complete();
      debugPrint('[ServerClockService] Sync failed: $error');
    }).whenComplete(() {
      _syncing = null;
    });
    return completer.future;
  }

  Future<void> _sync({bool force = false}) async {
    if (!force && hasFreshSync) {
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final doc = firestore.collection('app_meta').doc('server_clock');
    final clientBefore = DateTime.now();
    await doc.set(
      {'syncedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    final snapshot = await doc.get(const GetOptions(source: Source.server));
    final clientAfter = DateTime.now();
    final serverTimestamp = snapshot.data()?['syncedAt'];
    if (serverTimestamp is! Timestamp) {
      return;
    }

    final midpoint =
        clientBefore.add(clientAfter.difference(clientBefore) ~/ 2);
    _offset = serverTimestamp.toDate().difference(midpoint);
    _lastSyncedAt = DateTime.now();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fire_context.dart';

class FireContextNotifier extends StateNotifier<FireContext?> {
  FireContextNotifier() : super(null);

  void setFire(FireContext ctx) => state = ctx;
  void clearFire() => state = null;
}

final fireContextProvider =
    StateNotifierProvider<FireContextNotifier, FireContext?>(
  (ref) => FireContextNotifier(),
);

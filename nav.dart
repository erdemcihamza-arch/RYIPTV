import 'package:flutter/material.dart';

import 'detail_page.dart';
import 'models.dart';
import 'player_page.dart';
import 'store.dart';

Future<void> playItem(BuildContext context, Item it) {
  Store.addRecent(it);
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerPage(
        title: it.name,
        url: it.url,
        isLive: it.kind == Kind.live,
      ),
    ),
  );
}

Future<void> openItem(BuildContext context, Item it) {
  if (it.kind == Kind.live) return playItem(context, it);
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => DetailPage(item: it)),
  );
}

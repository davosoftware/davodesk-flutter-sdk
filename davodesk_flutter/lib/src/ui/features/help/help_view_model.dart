import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../client.dart';
import '../../../domain/models.dart';

final _log = Logger('DavoDesk');

/// What a help page shows while it reads, and if the read fails.
class const Loading<T>({final T? value, final bool failed = false}) {
  /// Creates a [Loading].
  this;

  /// Whether the read is still on its way.
  bool get waiting => value == null && !failed;
}

/// Reads one thing for a page, and reads it again on Start again.
class ReadViewModel<T extends Object> extends ChangeNotifier {
  /// Creates the view model; [_read] fetches the page's data.
  ReadViewModel(this._read);

  final Future<T> Function() _read;
  Loading<T> _state = const Loading();

  /// What the page shows now.
  Loading<T> get state => _state;

  /// Reads it.
  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      _state = Loading(value: await _read());
    } on Object catch (error) {
      _log.fine('A help page could not load: $error');
      _state = const Loading(failed: true);
    }
    notifyListeners();
  }
}

/// Help's state: the brand's collections, or what a search found.
class HelpViewModel extends ReadViewModel<List<CategoryNode>> {
  /// Creates Help's view model over [_client].
  HelpViewModel(this._client) : super(_client.categories);

  final DavoDeskClient _client;
  List<ArticleHit>? _hits;
  bool _searching = false;

  /// What a search found; null while the collections show.
  List<ArticleHit>? get hits => _hits;

  /// Whether a search is on its way.
  bool get searching => _searching;

  /// Searches the help centre; an empty [query] shows the collections again.
  Future<void> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      _hits = null;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    try {
      _hits = await _client.search(text);
    } on Object catch (error) {
      _log.fine('The search failed: $error');
      _hits = const [];
    }
    _searching = false;
    notifyListeners();
  }
}

/// An article's state, and the customer's vote on it.
class ArticleViewModel extends ReadViewModel<PublicArticle> {
  /// Creates the view model for the article [id] over [_client].
  ArticleViewModel(this._client, String id)
    : _id = id,
      super(() async {
        final article = await _client.article(id);
        if (article == null) throw StateError('No article $id');
        return article;
      });

  final DavoDeskClient _client;
  final String _id;
  bool _voted = false;

  /// Whether the customer said whether it helped.
  bool get voted => _voted;

  /// Says whether the article helped.
  Future<void> vote({required bool helpful}) async {
    try {
      await _client.vote(_id, helpful: helpful);
    } on Object catch (error) {
      _log.fine('The vote did not go: $error');
    }
    _voted = true;
    notifyListeners();
  }
}

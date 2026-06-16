import 'dart:math' as math;
import 'db_service.dart';

/// On-device Naive Bayes learner that improves category predictions as the
/// user corrects Eva's suggestions. Stored in eva_vocab / eva_cat_totals tables.
///
/// Blending logic:
///   - If total training docs < 5: rules win unconditionally (Eva is untrained).
///   - Otherwise: compute NB log-score per category. Eva wins only when its
///     top pick leads the runner-up by >= 1.0 in log-space (≈ e^1 ≈ 2.7× more
///     probable). Below that margin the rules are trusted (baseCategory returned).
class EvaService {
  EvaService._();
  static final instance = EvaService._();

  // Canonical category keys — duplicated here to avoid circular import with
  // LocalAnalysisService (which imports EvaService to wire predictions).
  static const _kCategories = [
    'passwords', 'contacts', 'shopping', 'receipts', 'finance', 'work',
    'health', 'travel', 'ideas', 'addresses', 'pets', 'food', 'education',
    'tech', 'vehicle', 'home', 'appointments', 'bills', 'personal', 'other',
  ];

  static const _kStopwords = {
    // Greek
    'και', 'για', 'της', 'του', 'τον', 'την', 'τας', 'τους', 'τις', 'τα',
    'τη', 'τι', 'να', 'με', 'σε', 'εν', 'απο', 'στο', 'στη', 'στα',
    // English
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'are', 'was',
    'not', 'have', 'has', 'had', 'you', 'can', 'will', 'but', 'its',
  };

  String _normalize(String text) {
    const accents = {
      'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
      'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ', 'ς': 'σ',
    };
    var out = text.toLowerCase();
    accents.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  Set<String> _tokenize(String text) {
    final norm = _normalize(text);
    return norm
        .split(RegExp(r'[^a-zα-ω0-9]'))
        .where((t) => t.length >= 3 && !_kStopwords.contains(t))
        .toSet();
  }

  /// Returns Eva's predicted category, or [baseCategory] when Eva is
  /// untrained / uncertain (so base rule always wins in those cases).
  Future<String> predict(
    String text, {
    required String baseCategory,
    required int baseScore,
  }) async {
    try {
      final db = await DbService.instance.database;

      final totalsRows = await db.query('eva_cat_totals');
      if (totalsRows.isEmpty) return baseCategory;

      final int totalDocs =
          totalsRows.fold(0, (sum, r) => sum + (r['doc_count'] as int));
      if (totalDocs < 2) return baseCategory; // not enough training data yet

      final catTotals = <String, int>{};
      for (final r in totalsRows) {
        catTotals[r['category'] as String] = r['doc_count'] as int;
      }

      final vocabRows = await db.query('eva_vocab');
      if (vocabRows.isEmpty) return baseCategory;

      // word -> {category -> count}
      final vocab = <String, Map<String, int>>{};
      for (final r in vocabRows) {
        final word = r['word'] as String;
        final cat = r['category'] as String;
        (vocab[word] ??= {})[cat] = r['count'] as int;
      }

      // total word count per category (denominator for Laplace smoothing)
      final catWordTotals = <String, int>{};
      for (final r in vocabRows) {
        final cat = r['category'] as String;
        catWordTotals[cat] =
            (catWordTotals[cat] ?? 0) + (r['count'] as int);
      }

      final vocabSize = vocab.length;
      final tokens = _tokenize(text);
      if (tokens.isEmpty) return baseCategory;

      // Multinomial Naive Bayes log-score per category.
      // score(cat) = log P(cat) + Σ log P(token | cat)
      // P(token | cat) uses Laplace smoothing:
      //   (count(token, cat) + 1) / (total_words_in_cat + vocab_size + 1)
      final scores = <String, double>{};
      for (final cat in _kCategories) {
        final docCount = catTotals[cat] ?? 0;
        if (docCount == 0) {
          scores[cat] = double.negativeInfinity;
          continue;
        }
        var logScore = math.log(docCount / totalDocs);
        final catTotal = catWordTotals[cat] ?? 0;
        for (final token in tokens) {
          final wordCount = vocab[token]?[cat] ?? 0;
          logScore +=
              math.log((wordCount + 1) / (catTotal + vocabSize + 1));
        }
        scores[cat] = logScore;
      }

      // Find best and runner-up log-scores.
      String best = baseCategory;
      double bestScore = double.negativeInfinity;
      double secondScore = double.negativeInfinity;
      scores.forEach((cat, sc) {
        if (sc > bestScore) {
          secondScore = bestScore;
          bestScore = sc;
          best = cat;
        } else if (sc > secondScore) {
          secondScore = sc;
        }
      });

      if (bestScore == double.negativeInfinity) return baseCategory;

      // Eva overrides base rules only when confident: log-margin >= 1.0.
      final margin = bestScore - secondScore;
      // If base rules already found a clear keyword match, trust base
      // unless Eva is very well-trained AND very confident.
      if (baseScore >= 1) {
        if (totalDocs < 8 || margin < 2.0) return baseCategory;
        return best;
      }
      if (margin < 0.5) return baseCategory;

      return best;
    } catch (_) {
      return baseCategory;
    }
  }

  /// Records the user's chosen category for the given text.
  /// Increments per-word counts in eva_vocab and doc count in eva_cat_totals.
  Future<void> train(String text, String category) async {
    try {
      final db = await DbService.instance.database;
      final tokens = _tokenize(text);
      if (tokens.isEmpty) return;

      // Use INSERT OR IGNORE + UPDATE pairs for SQLite <3.24 compatibility.
      final batch = db.batch();
      for (final token in tokens) {
        batch.rawInsert(
          'INSERT OR IGNORE INTO eva_vocab(word, category, count) VALUES(?, ?, 0)',
          [token, category],
        );
        batch.rawUpdate(
          'UPDATE eva_vocab SET count = count + 1 WHERE word = ? AND category = ?',
          [token, category],
        );
      }
      batch.rawInsert(
        'INSERT OR IGNORE INTO eva_cat_totals(category, doc_count) VALUES(?, 0)',
        [category],
      );
      batch.rawUpdate(
        'UPDATE eva_cat_totals SET doc_count = doc_count + 1 WHERE category = ?',
        [category],
      );
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// True once at least one training example has been recorded.
  Future<bool> hasLearned() async {
    try {
      final db = await DbService.instance.database;
      final rows = await db.query('eva_cat_totals', limit: 1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Wipes everything Eva has learned (both vocabulary and category totals).
  /// Does NOT touch the user's notes — only the learned model.
  Future<void> reset() async {
    try {
      final db = await DbService.instance.database;
      await db.delete('eva_vocab');
      await db.delete('eva_cat_totals');
    } catch (_) {}
  }
}

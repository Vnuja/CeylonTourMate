import 'package:firebase_database/firebase_database.dart';

/// Simple value holder for a destination's aggregate rating.
class RatingSummary {
  final double average;
  final int count;
  const RatingSummary({required this.average, required this.count});
}

/// A single user's rating + comment for a destination, as shown in the
/// public reviews list.
class ReviewEntry {
  final String uid;
  final String destination;
  final int rating;
  final String comment;
  final String? displayName;
  final int updatedAt;

  const ReviewEntry({
    required this.uid,
    required this.destination,
    required this.rating,
    required this.comment,
    required this.updatedAt,
    this.displayName,
  });

  factory ReviewEntry.fromMap(String uid, Map<dynamic, dynamic> data) {
    return ReviewEntry(
      uid: uid,
      destination: data['destination']?.toString() ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment']?.toString() ?? '',
      displayName: data['displayName']?.toString(),
      updatedAt: (data['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Stores and retrieves per-user destination feedback (star ratings +
/// comments), and turns that history into a short text summary that can be
/// fed back into the AI recommendation prompt so future recommendations
/// improve based on what the traveller actually liked.
///
/// It also maintains:
/// - A live *aggregate* rating per destination (sum + count across all
///   users) under `destination_ratings/{key}`, so the "overall rating"
///   badge can reflect real submitted ratings.
/// - A public reverse index of ratings + comments per destination under
///   `destination_reviews/{key}/{uid}`, so a reviews list can be shown
///   without having to scan every user's private feedback tree.
class FeedbackService {
  final DatabaseReference _feedbackRef =
      FirebaseDatabase.instance.ref('user_feedback');
  final DatabaseReference _aggregateRef =
      FirebaseDatabase.instance.ref('destination_ratings');
  final DatabaseReference _reviewsRef =
      FirebaseDatabase.instance.ref('destination_reviews');

  /// Saves/updates a rating (1-5 stars) + optional comment for a destination
  /// for the given user. Atomically updates that destination's aggregate
  /// rating, and publishes the review (rating + comment) to the public
  /// reviews index so other users can see it.
  Future<void> submitRating({
    required String uid,
    required String destination,
    required int rating,
    String? comment,
    String? displayName,
  }) async {
    final key = _sanitizeKey(destination);
    final now = DateTime.now().millisecondsSinceEpoch;
    final trimmedComment = (comment ?? '').trim();

    // Read any previous rating this user gave, so the aggregate can be
    // adjusted correctly rather than just added on top (avoids double
    // counting if the user changes their rating).
    final previousSnapshot = await _feedbackRef.child(uid).child(key).get();
    int? previousRating;
    if (previousSnapshot.exists) {
      final data = Map<dynamic, dynamic>.from(previousSnapshot.value as Map);
      previousRating = (data['rating'] as num?)?.toInt();
    }

    final payload = {
      'destination': destination,
      'rating': rating,
      'comment': trimmedComment,
      if (displayName != null) 'displayName': displayName,
      'updatedAt': now,
    };

    // Private per-user record (used for personalising future AI recs).
    // This is the one write that must succeed for submitRating() to be
    // considered successful — everything below is best-effort.
    await _feedbackRef.child(uid).child(key).set(payload);

    // Public reviews index (used for the "Reviews" list on the detail page).
    // Wrapped so a rules/permission problem on this path can never make the
    // whole submitRating() call fail after the private record already saved.
    try {
      await _reviewsRef.child(key).child(uid).set(payload);
    } catch (e) {
      // ignore: avoid_print
      print('FeedbackService: public review write failed: $e');
    }

    // The aggregate rating is a nice-to-have for the live "overall rating"
    // badge — it must never make the whole submitRating() call fail if the
    // review itself already saved. Common causes if this throws:
    // missing/incorrect Firebase rule on `destination_ratings`, or a
    // transient transaction-retry failure.
    try {
      await _aggregateRef.child(key).runTransaction((current) {
        final data = current == null
            ? {'destination': destination, 'sum': 0, 'count': 0}
            : Map<String, dynamic>.from(current as Map);
        var sum = (data['sum'] as num? ?? 0).toInt();
        var count = (data['count'] as num? ?? 0).toInt();

        if (previousRating != null) {
          // Replace the old contribution with the new one.
          sum = sum - previousRating + rating;
        } else {
          sum += rating;
          count += 1;
        }
        data['destination'] = destination;
        data['sum'] = sum;
        data['count'] = count;
        return Transaction.success(data);
      });
    } catch (e) {
      // ignore: avoid_print
      print('FeedbackService: aggregate rating update failed: $e');
    }
  }

  /// Returns the current user's rating for a destination, or null if none.
  Future<int?> getRating({
    required String uid,
    required String destination,
  }) async {
    final key = _sanitizeKey(destination);
    final snapshot = await _feedbackRef.child(uid).child(key).get();
    if (!snapshot.exists) return null;
    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return (data['rating'] as num?)?.toInt();
  }

  /// Returns the current user's full feedback (rating + comment) for a
  /// destination, or null if they haven't rated it yet.
  Future<ReviewEntry?> getUserFeedback({
    required String uid,
    required String destination,
  }) async {
    final key = _sanitizeKey(destination);
    final snapshot = await _feedbackRef.child(uid).child(key).get();
    if (!snapshot.exists) return null;
    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return ReviewEntry.fromMap(uid, data);
  }

  /// One-off fetch of a destination's live average rating and rating count.
  Future<RatingSummary> getAverageRating(String destination) async {
    final key = _sanitizeKey(destination);
    final snapshot = await _aggregateRef.child(key).get();
    if (!snapshot.exists) return const RatingSummary(average: 0.0, count: 0);
    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final sum = (data['sum'] as num? ?? 0).toDouble();
    final count = (data['count'] as num? ?? 0).toInt();
    if (count == 0) return const RatingSummary(average: 0.0, count: 0);
    return RatingSummary(average: sum / count, count: count);
  }

  /// Live stream of a destination's average rating — use this to make the
  /// UI update immediately (for this user and anyone else viewing the page)
  /// whenever a new rating is submitted, without needing a manual refresh.
  Stream<RatingSummary> watchAverageRating(String destination) {
    final key = _sanitizeKey(destination);
    return _aggregateRef.child(key).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return const RatingSummary(average: 0.0, count: 0);
      final data = Map<dynamic, dynamic>.from(value as Map);
      final sum = (data['sum'] as num? ?? 0).toDouble();
      final count = (data['count'] as num? ?? 0).toInt();
      if (count == 0) return const RatingSummary(average: 0.0, count: 0);
      return RatingSummary(average: sum / count, count: count);
    });
  }

  /// Live stream of all reviews (rating + comment) for a destination, newest
  /// first — powers the "Reviews" list on the destination detail page.
  Stream<List<ReviewEntry>> watchReviews(String destination) {
    final key = _sanitizeKey(destination);
    return _reviewsRef.child(key).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <ReviewEntry>[];
      final map = Map<dynamic, dynamic>.from(value as Map);
      final reviews = map.entries
          .map(
            (e) => ReviewEntry.fromMap(
              e.key.toString(),
              Map<dynamic, dynamic>.from(e.value as Map),
            ),
          )
          .toList();
      reviews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return reviews;
    });
  }

  /// Fetches all feedback a user has ever given.
  Future<Map<String, dynamic>> getAllFeedback(String uid) async {
    final snapshot = await _feedbackRef.child(uid).get();
    if (!snapshot.exists) return {};
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Builds a short, human-readable summary of the user's past feedback,
  /// split into liked (4-5★) and disliked (1-2★) destinations, ready to be
  /// dropped straight into an LLM prompt for personalisation.
  Future<String> buildFeedbackSummary(String uid) async {
    final all = await getAllFeedback(uid);
    if (all.isEmpty) return '';

    final liked = <String>[];
    final disliked = <String>[];

    for (final entry in all.values) {
      final data = Map<String, dynamic>.from(entry as Map);
      final destination = data['destination']?.toString() ?? '';
      final rating = (data['rating'] as num?)?.toInt() ?? 0;
      final comment = data['comment']?.toString().trim() ?? '';
      if (destination.isEmpty || rating == 0) continue;
      final noteSuffix = comment.isNotEmpty
          ? ' — "${comment.length > 80 ? '${comment.substring(0, 80)}...' : comment}"'
          : '';
      if (rating >= 4) {
        liked.add('$destination ($rating★)$noteSuffix');
      } else if (rating <= 2) {
        disliked.add('$destination ($rating★)$noteSuffix');
      }
    }

    if (liked.isEmpty && disliked.isEmpty) return '';

    final buffer = StringBuffer();
    if (liked.isNotEmpty) {
      buffer.writeln('- Rated highly by this traveller: ${liked.join(', ')}');
    }
    if (disliked.isNotEmpty) {
      buffer.writeln('- Rated poorly by this traveller: ${disliked.join(', ')}');
    }
    return buffer.toString();
  }

  String _sanitizeKey(String destination) =>
      destination.trim().toLowerCase().replaceAll(RegExp(r'[.#$\[\]/\s]+'), '_');
}

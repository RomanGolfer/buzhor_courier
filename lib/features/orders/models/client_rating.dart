part of 'order_item.dart';

class ClientRating {
  final int rating;
  final DateTime? ratedAt;

  const ClientRating({required this.rating, this.ratedAt})
    : assert(rating >= 1 && rating <= 5);

  static ClientRating? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final rawRating = (json['rating'] as num?)?.toInt();
    if (rawRating == null) return null;
    return ClientRating(
      rating: rawRating.clamp(1, 5).toInt(),
      ratedAt: _optionalDateTime(json['ratedAt'] ?? json['rated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'rating': rating,
    'ratedAt': ratedAt?.toIso8601String(),
  };
}

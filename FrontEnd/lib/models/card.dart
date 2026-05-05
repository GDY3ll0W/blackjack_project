class Card {
  final String suit;
  final String rank;

  Card(this.suit, this.rank);

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(json['suit'], json['rank']);
  }

  Map<String, dynamic> toJson() {
    return {
      'suit': suit,
      'rank': rank,
    };
  }
}

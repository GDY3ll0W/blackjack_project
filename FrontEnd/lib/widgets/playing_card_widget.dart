import 'package:flutter/material.dart';

class PlayingCardWidget extends StatelessWidget {
  final String imageUrl;
  final String? rank;
  final String? suit;
  final bool hidden;

  const PlayingCardWidget({
    Key? key,
    required this.imageUrl,
    this.rank,
    this.suit,
    this.hidden = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(2, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: hidden ? Colors.blue[900] : Colors.white,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hidden) Text(rank ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  if (!hidden) Text(suit != null ? suit![0] : '', style: const TextStyle(color: Colors.black)),
                  if (hidden) const Icon(Icons.casino, color: Colors.white),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
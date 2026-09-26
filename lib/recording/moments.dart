class RoundMark {
  const RoundMark({
    required this.cardId,
    required this.prompt,
    required this.clue,
    required this.correct,
    required this.tMs,
  });

  final String cardId;
  final String prompt;
  final String clue;
  final bool correct;
  final int tMs;

  Map<String, Object?> toJson() => {
    'cardId': cardId,
    'prompt': prompt,
    'clue': clue,
    'correct': correct,
    'tMs': tMs,
  };

  static RoundMark fromJson(Map<String, Object?> json) {
    return RoundMark(
      cardId: json['cardId']! as String,
      prompt: json['prompt']! as String,
      clue: json['clue']! as String,
      correct: json['correct']! as bool,
      tMs: json['tMs']! as int,
    );
  }
}

Duration jumpTarget(int tMs) {
  final ms = tMs - 1000;
  return Duration(milliseconds: ms < 0 ? 0 : ms);
}

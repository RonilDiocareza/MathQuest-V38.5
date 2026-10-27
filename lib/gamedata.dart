// Minimal stubs for game data (replace with real data source)

int getTotalLitterTrivia() => 5;
int getTotalBirds() => 3;

Map<String, Object>? getBirdData(int i) {
  final birds = [
    {
      'name': 'Bird A',
      'asset': 'assets/images/numbers/bird_a.png',
      'map_asset': 'assets/images/numbers/bird_a_map.png',
      'accepted_answers': ['A'],
      'trivia': 'A trivia',
    },
    {
      'name': 'Bird B',
      'asset': 'assets/images/numbers/bird_b.png',
      'map_asset': 'assets/images/numbers/bird_b_map.png',
      'accepted_answers': ['B'],
      'trivia': 'B trivia',
    },
    {
      'name': 'Bird C',
      'asset': 'assets/images/numbers/bird_c.png',
      'map_asset': 'assets/images/numbers/bird_c_map.png',
      'accepted_answers': ['C'],
      'trivia': 'C trivia',
    },
  ];
  if (i < 0 || i >= birds.length) return null;
  return birds[i];
}

Map<String, Object>? getLitterData(int i) {
  final list = [
    {
      'question': 'What is litter?',
      'choices': ['Trash', 'Tree', 'Bird'],
      'correct_answer': 0,
    }
  ];
  if (i < 0 || i >= list.length) return null;
  return list[i];
}

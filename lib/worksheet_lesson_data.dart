class WorksheetLesson {
  final int number;
  final String title;
  final String moduleId;
  final String semester;
  final String topic;
  final String objective;
  final String explanation;
  final String example;
  final String solution;
  final String practice;
  final String question;
  final List<String> choices;
  final int correctAnswerIndex;

  const WorksheetLesson({
    required this.number,
    required this.title,
    required this.moduleId,
    required this.semester,
    required this.topic,
    required this.objective,
    required this.explanation,
    required this.example,
    required this.solution,
    required this.practice,
    required this.question,
    required this.choices,
    required this.correctAnswerIndex,
  });

  String get correctAnswer => choices[correctAnswerIndex];
}

const List<String> worksheetTitles = [
  'Adding Similar Fractions',
  'Subtracting Similar Fractions',
  'Adding and Subtracting Mixed Numbers',
  'Adding and Subtracting Mixed Numbers',
  'Adding and Subtracting Similar Fractions',
  'Adding and Subtracting Dissimilar Fractions',
  'Adding and Subtracting Dissimilar Fractions',
  'Word Problems on Adding and Subtracting Fractions',
  'Multiplying Fractions',
  'Multiplying Mixed Numbers',
  'Multiplying Mixed Numbers',
  'Dividing Fractions',
  'Dividing Mixed Numbers',
  'Adding Decimals',
  'Adding Decimals',
  'Subtracting Decimals',
  'Subtracting Decimals',
  'Adding and Subtracting Decimals (Word Phrases)',
  'Multiplying Decimals',
  'Multiplying Decimals',
  'Dividing Decimals',
  'Dividing Whole Numbers by Decimals',
  'Division by 0.1, 0.01, and 0.001',
  'Worksheet 24',
  'Division by 10, 100, and 1,000',
  'Division by 10, 100, and 1,000',
  'Solid Figures',
  'Cubes',
  'Triangular Prisms',
  'Pyramids',
  'Cylinders',
  'Cones',
  'Spheres',
  'Differentiating Solid and Plane Figures',
  'Differentiating Speed, Distance, Time',
  'Calculating Speed, Distance, Time',
  'Calculating Speed, Distance, Time',
  'Area of Composite Figures',
  'Area of Composite Figures',
  'Area of Composite Figures',
  'Surface Area of a Rectangular Prism',
  'Surface Area of a Triangular Prism',
  'Surface Area of a Cube and a Square Pyramid',
  'Surface Area of a Cube and Square Pyramid',
  'Surface Area of a Cylinder',
  'Surface Area of a Cone and Other Solid Figures',
  'Surface Area of a Sphere and Other Solid Figures',
  'Listing Outcomes',
  'Listing Outcomes',
  'Listing Outcomes',
  'Listing Outcomes',
  'Adding Two Positive Integers; Adding Two Positive Similar Fractions',
  'Adding Two Negative Integers; Adding Two Negative Similar Fractions',
  'Adding a Positive and a Negative Integer; Adding a Positive and Negative Fraction',
  'Adding a Positive and a Negative Integer',
  'Subtracting Two Positive Integers',
  'Subtracting Two Negative Integers',
  'Subtracting a Positive Integer by a Negative Integer',
  'Subtracting a Negative Integer by a Positive Integer; Subtracting a Negative Fraction by a Positive Fraction',
  'Subtracting Integers',
  'Multiplying Two Positive Integers; Multiplying Two Positive Fractions',
  'Multiplying Two Negative Integers; Multiplying Two Negative Fractions',
  'Multiplying Two Integers with Different Signs; Multiplying Fractions with Different Signs',
  'Multiplying Integers',
  'Division of Two Positive Integers; Division of Two Negative Integers',
  'Division of Two Integers with Different Signs',
  'Dividing Integers',
];

const List<String> worksheetModuleIds = [
  'fraction-add-subtract',
  'fraction-multiply-divide',
  'decimal-operations',
  'solid-figures',
  'speed-distance-time',
  'area-surface-area',
  'listing-outcomes',
  'integer-operations',
];

const List<String> worksheetModuleNames = [
  'Adding and Subtracting Fractions',
  'Multiplying and Dividing Fractions',
  'Decimal Operations',
  'Solid and Plane Figures',
  'Speed, Distance, and Time',
  'Area and Surface Area',
  'Listing Outcomes',
  'Integer Operations',
];

const List<String> worksheetModuleSemesters = [
  'Tri-Sem 1 · Fraction Operations',
  'Tri-Sem 1 · Fraction Operations',
  'Tri-Sem 1 · Decimal Operations',
  'Tri-Sem 2 · Figures and Measurement',
  'Tri-Sem 2 · Figures and Measurement',
  'Tri-Sem 2 · Figures and Measurement',
  'Tri-Sem 2 · Outcomes',
  'Tri-Sem 3 · Integer Operations',
];

class GameModeTopicRange {
  final int firstLevel;
  final int lastLevel;
  final String moduleId;

  const GameModeTopicRange({
    required this.firstLevel,
    required this.lastLevel,
    required this.moduleId,
  });
}

const List<GameModeTopicRange> gameModeTopicRanges = [
  GameModeTopicRange(
    firstLevel: 1,
    lastLevel: 8,
    moduleId: 'fraction-add-subtract',
  ),
  GameModeTopicRange(
    firstLevel: 9,
    lastLevel: 13,
    moduleId: 'fraction-multiply-divide',
  ),
  GameModeTopicRange(
    firstLevel: 14,
    lastLevel: 20,
    moduleId: 'decimal-operations',
  ),
  GameModeTopicRange(
    firstLevel: 21,
    lastLevel: 25,
    moduleId: 'solid-figures',
  ),
  GameModeTopicRange(
    firstLevel: 26,
    lastLevel: 30,
    moduleId: 'speed-distance-time',
  ),
  GameModeTopicRange(
    firstLevel: 31,
    lastLevel: 35,
    moduleId: 'area-surface-area',
  ),
  GameModeTopicRange(
    firstLevel: 36,
    lastLevel: 40,
    moduleId: 'listing-outcomes',
  ),
  GameModeTopicRange(
    firstLevel: 41,
    lastLevel: 60,
    moduleId: 'integer-operations',
  ),
];

final List<int> gameModeModuleStartLevels = List.unmodifiable(
  gameModeTopicRanges.map((range) => range.firstLevel),
);
final List<int> gameModeModuleEndLevels = List.unmodifiable(
  gameModeTopicRanges.map((range) => range.lastLevel),
);

int gameModeModuleIndexForLevel(int level) {
  if (level < 1 || level > 60) {
    throw RangeError.range(level, 1, 60, 'level');
  }
  return gameModeTopicRanges.indexWhere(
    (range) => level >= range.firstLevel && level <= range.lastLevel,
  );
}

const List<int> _moduleEnds = [8, 13, 26, 34, 37, 47, 51, 67];

int worksheetModuleIndex(int worksheetNumber) {
  for (var index = 0; index < _moduleEnds.length; index++) {
    if (worksheetNumber <= _moduleEnds[index]) return index;
  }
  throw RangeError.range(worksheetNumber, 1, worksheetTitles.length);
}

String _fraction(int numerator, int denominator) {
  var a = numerator.abs();
  var b = denominator.abs();
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  final divisor = a == 0 ? 1 : a;
  final sign = numerator * denominator < 0 ? '-' : '';
  final reducedNumerator = numerator.abs() ~/ divisor;
  final reducedDenominator = denominator.abs() ~/ divisor;
  return reducedDenominator == 1
      ? '$sign$reducedNumerator'
      : '$sign$reducedNumerator/$reducedDenominator';
}

String _decimal(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

final List<WorksheetLesson> worksheetLessons = List.unmodifiable(
  List.generate(
    worksheetTitles.length,
    (index) => _createLesson(index + 1),
    growable: false,
  ),
);

WorksheetLesson _createLesson(int number) {
  final moduleIndex = worksheetModuleIndex(number);
  final title = worksheetTitles[number - 1];
  final n = number;
  late String objective;
  late String explanation;
  late String example;
  late String solution;
  late String practice;
  late String question;
  late List<String> choices;
  late int answerIndex;

  if (number <= 8) {
    objective = 'Add or subtract fractions and mixed numbers.';
    explanation =
        'For fractions with the same denominator, add or subtract the numerators and keep the denominator. For unlike denominators, first write equivalent fractions with a common denominator. Convert mixed numbers when needed, then simplify.';
    final denominator = number <= 5 ? 8 : 12;
    final firstNumerator = number % (denominator - 1) + 1;
    final secondNumerator = number % (denominator - firstNumerator) + 1;
    final isSubtract = (number.isEven && number != 8) || number == 7;
    final resultDenominator = number >= 6 ? denominator * 2 : denominator;
    final shownFirst = '$firstNumerator/$denominator';
    final shownSecond = number >= 6
        ? '$secondNumerator/${denominator * 2}'
        : '$secondNumerator/$denominator';
    final normalizedFirst = number >= 6 ? firstNumerator * 2 : firstNumerator;
    final actualNumerator = isSubtract
        ? normalizedFirst - secondNumerator
        : normalizedFirst + secondNumerator;
    final answer = _fraction(actualNumerator, resultDenominator);
    example = '$shownFirst ${isSubtract ? '−' : '+'} $shownSecond';
    solution =
        'Use a common denominator, combine the numerators, and simplify: $answer.';
    practice =
        'Practice: $shownFirst ${isSubtract ? '+' : '−'} $shownSecond. Check by using the same common-denominator rule.';
    question = number == 8
        ? 'A recipe uses $shownFirst cup of flour in the morning and $shownSecond cup in the afternoon. How much flour is used altogether?'
        : 'Calculate $shownFirst ${isSubtract ? '−' : '+'} $shownSecond.';
    choices = [
      answer,
      _fraction(actualNumerator + 1, resultDenominator),
      _fraction(actualNumerator - 1, resultDenominator),
    ];
    answerIndex = 0;
    if (number == 3) {
      example = '1 1/2 + 2 1/4';
      solution =
          'Convert to improper fractions: 3/2 + 9/4 = 6/4 + 9/4 = 15/4 = 3 3/4.';
      practice = 'Practice: 2 1/3 + 1 1/3 = 3 2/3.';
      question = 'Calculate 1 1/2 + 2 1/4.';
      choices = ['3 3/4', '3 1/2', '2 3/4'];
    } else if (number == 4) {
      example = '4 1/2 − 1 3/4';
      solution =
          'Convert to improper fractions: 9/2 − 7/4 = 18/4 − 7/4 = 11/4 = 2 3/4.';
      practice = 'Practice: 3 1/2 − 1 1/2 = 2.';
      question = 'Calculate 4 1/2 − 1 3/4.';
      choices = ['2 3/4', '3 1/4', '2 1/4'];
    }
  } else if (number <= 13) {
    objective = 'Multiply or divide fractions and mixed numbers.';
    explanation =
        'For multiplication, multiply the numerators and multiply the denominators. Convert mixed numbers to improper fractions first. To divide by a fraction, multiply by its reciprocal. Simplify the result.';
    final a = n % 5 + 1;
    final b = n % 4 + 2;
    final denominator = 6;
    final rightDenominator = n % 5 + 2;
    final isDivision = number >= 12;
    final answer = isDivision
        ? _fraction(a * rightDenominator, denominator * b)
        : _fraction(a * b, denominator * 4);
    example = isDivision ? '$a/6 ÷ $b/$rightDenominator' : '$a/6 × $b/4';
    solution = isDivision
        ? 'Multiply by the reciprocal of the second fraction, then simplify: $answer.'
        : 'Multiply the numerators and denominators, then simplify: $answer.';
    practice =
        'Practice: $example. Write mixed numbers as improper fractions before operating.';
    question = 'Calculate $example.';
    choices = [
      answer,
      _fraction(a + b, denominator + 4),
      _fraction(a * b + 1, denominator * 4),
    ];
    answerIndex = 0;
    if (number == 10) {
      example = '1 1/2 × 2';
      solution = 'Convert 1 1/2 to 3/2: 3/2 × 2 = 3.';
      practice = 'Practice: 1 1/4 × 2 = 2 1/2.';
      question = 'Calculate 1 1/2 × 2.';
      choices = ['3', '2 1/2', '4'];
    } else if (number == 11) {
      example = '2 1/4 × 1 1/3';
      solution = 'Convert to improper fractions: 9/4 × 4/3 = 3.';
      practice = 'Practice: 1 1/2 × 2 = 3.';
      question = 'Calculate 2 1/4 × 1 1/3.';
      choices = ['3', '2 3/4', '4'];
    } else if (number == 13) {
      example = '1 1/2 ÷ 3/4';
      solution =
          'Convert 1 1/2 to 3/2, then multiply by the reciprocal: 3/2 × 4/3 = 2.';
      practice = 'Practice: 1 1/2 ÷ 1/2 = 3.';
      question = 'Calculate 1 1/2 ÷ 3/4.';
      choices = ['2', '1 1/2', '3'];
    }
  } else if (number <= 26) {
    objective = 'Add, subtract, multiply, or divide decimals.';
    explanation =
        'For addition and subtraction, line up decimal points. For multiplication, multiply as whole numbers and place the decimal using the total decimal places. For division, make the divisor a whole number by moving both decimal points equally. Dividing by 10, 100, or 1,000 moves the decimal left.';
    if (number <= 18) {
      final first = n * 13 + 145;
      final second = n * 7 + 85;
      final subtract = number >= 16;
      final answerCents = subtract ? first - second : first + second;
      final calculation =
          '${_decimal(first)} ${subtract ? '−' : '+'} ${_decimal(second)}';
      final answer = _decimal(answerCents);
      example = number == 18
          ? 'An item costing \$${_decimal(first)} is discounted by \$${_decimal(second)}.'
          : calculation;
      solution =
          'Line up the decimal points and calculate: $calculation = $answer.';
      practice =
          'Practice: $calculation. Estimate first, then check the decimal placement.';
      question = number == 18
          ? 'An item costs \$${_decimal(first)} and is discounted by \$${_decimal(second)}. What is the sale price?'
          : 'Calculate $calculation.';
      choices = [
        answer,
        _decimal(answerCents + 10),
        _decimal(answerCents - 10)
      ];
      answerIndex = 0;
    } else if (number <= 20) {
      final first = number == 19 ? 120 : 240;
      final second = number == 19 ? 50 : 150;
      final answerCents = first * second ~/ 100;
      example = '${_decimal(first)} × ${_decimal(second)}';
      solution =
          'Multiply as whole numbers and place two decimal places in the product: ${_decimal(answerCents)}.';
      practice = 'Practice: 1.2 × 0.5 = 0.60.';
      question = 'Calculate $example.';
      choices = [
        _decimal(answerCents),
        _decimal(answerCents + 10),
        _decimal(answerCents - 10),
      ];
      answerIndex = 0;
    } else if (number <= 22) {
      final dividend = number == 21 ? 64 : 6;
      final divisor = number == 21 ? 8 : 2;
      final decimalDivisor = number == 21 ? '0.8' : '0.2';
      final dividendText = number == 21 ? '6.4' : '$dividend';
      final answer = number == 21 ? '8' : '${dividend * 10 ~/ divisor}';
      example = '$dividendText ÷ $decimalDivisor';
      solution =
          'Make the divisor a whole number by moving both decimal points equally, then divide: $answer.';
      practice = 'Practice: 4.8 ÷ 0.6 = 8.';
      question = 'Calculate $example.';
      choices = [
        answer,
        number == 21 ? '0.8' : '${dividend ~/ divisor}',
        number == 21 ? '80' : '${dividend * 10}',
      ];
      answerIndex = 0;
    } else if (number <= 24) {
      final divisor = number == 23 ? '0.1' : '0.6';
      final dividend = number == 23 ? '4.56' : '5.4';
      final answer = number == 23 ? '45.6' : '9';
      example = '$dividend ÷ $divisor';
      solution = number == 23
          ? 'Dividing by 0.1 is the same as multiplying by 10: $dividend × 10 = $answer.'
          : 'Move both decimal points one place right: 54 ÷ 6 = $answer.';
      practice = 'Practice: 3.6 ÷ 0.1 = 36.';
      question = 'Calculate $example.';
      choices = [
        answer,
        number == 23 ? '4.56' : '0.9',
        number == 23 ? '456' : '90'
      ];
      answerIndex = 0;
    } else {
      final divisor = number == 25 ? 10 : 100;
      final dividend = number == 25 ? 250 : 36;
      final answer = _decimal(dividend * 100 ~/ divisor);
      example = '$dividend ÷ $divisor';
      solution =
          'Dividing by $divisor moves the decimal point left ${number == 25 ? 'one' : 'two'} place(s): $answer.';
      practice = 'Practice: 450 ÷ 10 = 45.';
      question = 'Calculate $example.';
      choices = number == 25 ? [answer, '2500', '2.5'] : [answer, '36', '3.6'];
      answerIndex = 0;
    }
  } else if (number <= 34) {
    objective = 'Identify and describe plane and solid figures.';
    explanation =
        'Plane figures are flat and have length and width. Solid figures have length, width, and height. Cubes and prisms have flat faces; cylinders, cones, and spheres have curved surfaces.';
    final shapes = [
      'cube',
      'triangular prism',
      'pyramid',
      'cylinder',
      'cone',
      'sphere'
    ];
    final shape = shapes[(number - 28) % shapes.length];
    example = 'A $shape is a three-dimensional solid.';
    solution = 'It is a solid figure because it has length, width, and height.';
    practice =
        'Practice: Is a circle a plane figure or a solid figure? Answer: plane figure.';
    question = 'Which is a three-dimensional figure: a circle or a $shape?';
    choices = [shape, 'circle', 'line segment'];
    answerIndex = 0;
  } else if (number <= 37) {
    objective = 'Use the relationships among speed, distance, and time.';
    explanation =
        'Speed = distance ÷ time. Distance = speed × time. Time = distance ÷ speed. Keep units consistent and include the correct unit in your answer.';
    final answer = number == 35 ? 'speed' : '${(n + 2) * 5} km';
    example = number == 35
        ? 'A car travels 120 km in 2 hours.'
        : 'A vehicle travels at 5 km/h for ${n + 2} hours.';
    solution = number == 35
        ? 'Speed = 120 ÷ 2 = 60 km/h.'
        : 'Distance = speed × time = 5 × ${n + 2} = $answer.';
    practice =
        'Practice: A cyclist travels 24 km in 3 hours. Find the speed. Answer: 8 km/h.';
    question = number == 35
        ? 'Which quantity is found by dividing distance by time?'
        : 'A vehicle travels at 5 km/h for ${n + 2} hours. How far does it travel?';
    choices = number == 35
        ? ['speed', 'distance', 'time']
        : [answer, '${n + 2} km', '${(n + 2) + 5} km'];
    answerIndex = 0;
  } else if (number <= 47) {
    objective = 'Find area or surface area using the appropriate formula.';
    explanation =
        'Area measures the surface inside a plane figure. Break a composite figure into familiar shapes and add their areas. Surface area is the total area of all outside faces. Use matching square units.';
    late String answer;
    if (number <= 40) {
      const firstArea = 3 * 4;
      const secondArea = 2 * 5;
      answer = '${firstArea + secondArea} square units';
      example =
          'A composite shape is made from a 3-by-4 rectangle and a 2-by-5 rectangle.';
      solution =
          'Add the areas of the two rectangles: (3 × 4) + (2 × 5) = $answer.';
      question =
          'What is the combined area of a 3-by-4 rectangle and a 2-by-5 rectangle?';
      choices = [answer, '20 square units', '12 square units'];
    } else if (number == 41) {
      answer = '52 square units';
      example = 'A rectangular prism is 2 units by 3 units by 4 units.';
      solution =
          'Surface area = 2(lw + lh + wh) = 2(6 + 8 + 12) = 52 square units.';
      question = 'Find the surface area of a 2-by-3-by-4 rectangular prism.';
      choices = [answer, '24 square units', '48 square units'];
    } else if (number == 42) {
      example =
          'A triangular prism has a 3-4-5 triangle base and length 2 units.';
      solution =
          'Surface area = perimeter of base × length + 2 × base area = 12 × 2 + 2 × 6 = 36 square units.';
      answer = '36 square units';
      question =
          'Find the surface area of a triangular prism with a 3-4-5 base and length 2.';
      choices = [answer, '24 square units', '30 square units'];
    } else if (number <= 44) {
      final isCube = number == 43;
      answer = isCube ? '96 square units' : '56 square units';
      example = isCube
          ? 'A cube has side length 4 units.'
          : 'A square pyramid has base side 4 units and slant height 5 units.';
      solution = isCube
          ? 'Surface area = 6s² = 6 × 4² = 96 square units.'
          : 'Surface area = base area + 4 triangular faces = 4² + 4(4 × 5 ÷ 2) = 56 square units.';
      question = isCube
          ? 'Find the surface area of a cube with side length 4.'
          : 'Find the surface area of a square pyramid with base side 4 and slant height 5.';
      choices = [
        answer,
        isCube ? '64 square units' : '40 square units',
        '80 square units'
      ];
    } else if (number == 45) {
      answer = '62.8 square units';
      example =
          'A cylinder has radius 2 units and height 3 units. Use π = 3.14.';
      solution =
          'Surface area = 2πr² + 2πrh = 25.12 + 37.68 = 62.8 square units.';
      question =
          'Find the surface area of a cylinder with radius 2 and height 3. Use π = 3.14.';
      choices = [answer, '37.68 square units', '50.24 square units'];
    } else if (number == 46) {
      answer = '75.36 square units';
      example =
          'A cone has radius 3 units and slant height 5 units. Use π = 3.14.';
      solution =
          'Surface area = πr² + πrl = 28.26 + 47.1 = 75.36 square units.';
      question =
          'Find the surface area of a cone with radius 3 and slant height 5. Use π = 3.14.';
      choices = [answer, '47.1 square units', '28.26 square units'];
    } else {
      answer = '50.24 square units';
      example = 'A sphere has radius 2 units. Use π = 3.14.';
      solution = 'Surface area = 4πr² = 4 × 3.14 × 2² = 50.24 square units.';
      question =
          'Find the surface area of a sphere with radius 2. Use π = 3.14.';
      choices = [answer, '25.12 square units', '12.56 square units'];
    }
    practice =
        'Practice: Find the area of a 3-by-4 rectangle. Answer: 12 square units.';
    answerIndex = choices.indexOf(answer);
  } else if (number <= 51) {
    objective = 'List all possible outcomes systematically.';
    explanation =
        'An outcome is one possible result. List outcomes in an organized way, such as a table or tree diagram, so none are missed or counted twice. For independent choices, multiply the number of options for each choice to find the total.';
    final first = n % 3 + 2;
    final second = n % 4 + 2;
    final total = first * second;
    example =
        'There are $first choices for one item and $second choices for another.';
    solution = 'The total number of combinations is $first × $second = $total.';
    practice =
        'Practice: 2 shirts and 3 pairs of pants make 2 × 3 = 6 outfits.';
    question =
        'There are $first choices for one item and $second choices for another. How many combinations are possible?';
    choices = ['$total', '${total + 1}', '${total + 2}'];
    answerIndex = 0;
  } else {
    final offset = number - 52;
    objective = 'Add, subtract, multiply, or divide integers.';
    explanation =
        'For addition and subtraction, use number-line direction and sign rules; subtracting a number is adding its opposite. For multiplication and division, same signs give a positive result and different signs give a negative result. Apply these sign rules to fractions too; use a common denominator before adding or subtracting fractions.';
    var a = offset + 5;
    var b = offset + 3;
    final operation = number <= 55
        ? '+'
        : number <= 60
            ? '−'
            : number <= 64
                ? '×'
                : '÷';
    if (number >= 65) {
      a *= b;
    }
    final first = switch (number) {
      53 || 57 || 59 || 62 || 67 => -a,
      _ => a,
    };
    final second = switch (number) {
      53 || 57 || 62 || 67 => -b,
      54 || 55 || 58 || 63 || 66 => -b,
      _ => b,
    };
    final result = switch (operation) {
      '+' => first + second,
      '−' => first - second,
      '×' => first * second,
      _ => first ~/ second,
    };
    final signedFirst = first < 0 ? '($first)' : '$first';
    final signedSecond = second < 0 ? '($second)' : '$second';
    example = '$signedFirst $operation $signedSecond';
    solution = '$example = $result.';
    final fractionPractice = switch (number) {
      52 => 'Also: 1/5 + 2/5 = 3/5.',
      53 => 'Also: (−1/5) + (−2/5) = −3/5.',
      54 => 'Also: 1/5 + (−2/5) = −1/5.',
      56 => 'Also: 4/5 − 2/5 = 2/5.',
      57 => 'Also: (−4/5) − (−2/5) = −2/5.',
      58 => 'Also: 4/5 − (−2/5) = 6/5.',
      59 => 'Also: (−4/5) − 2/5 = −6/5.',
      60 => 'Also: 1/2 − 1/4 = 1/4.',
      61 => 'Also: 1/2 × 1/3 = 1/6.',
      62 => 'Also: (−1/2) × (−1/3) = 1/6.',
      63 => 'Also: (−1/2) × 1/3 = −1/6.',
      64 => 'Also: (−2/3) × 3/4 = −1/2.',
      65 => 'Also: 1/2 ÷ 1/4 = 2.',
      66 => 'Also: (−1/2) ÷ 1/4 = −2.',
      67 => 'Also: (−1/2) ÷ (−1/4) = 2.',
      _ => 'Also apply the same sign rule to a fraction operation.',
    };
    practice = 'Practice: (−8) + 3 = −5. '
        'Identify the signs before calculating. $fractionPractice';
    question = 'Calculate $example.';
    choices = ['$result', '${result + 2}', '${result - 2}'];
    answerIndex = 0;
  }

  return WorksheetLesson(
    number: number,
    title: title.startsWith('Worksheet') ? title : 'Worksheet $number: $title',
    moduleId: worksheetModuleIds[moduleIndex],
    semester: worksheetModuleSemesters[moduleIndex],
    topic: worksheetModuleNames[moduleIndex],
    objective: objective,
    explanation: explanation,
    example: example,
    solution: solution,
    practice: practice,
    question: question,
    choices: choices,
    correctAnswerIndex: answerIndex,
  );
}

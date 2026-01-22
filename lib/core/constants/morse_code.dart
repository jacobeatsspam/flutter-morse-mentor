/// Complete morse code mapping following International Morse Code standard
/// Used by ham radio operators worldwide
class MorseCode {
  /// Standard timing units (in milliseconds at 20 WPM)
  /// These are calculated based on the PARIS standard
  static const int dotDuration = 60; // 1 unit
  static const int dashDuration = 180; // 3 units
  static const int symbolGap = 60; // 1 unit (between dots/dashes)
  static const int letterGap = 180; // 3 units (between letters)
  static const int wordGap = 420; // 7 units (between words)

  /// Letters A-Z
  static const Map<String, String> letters = {
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    'F': '..-.',
    'G': '--.',
    'H': '....',
    'I': '..',
    'J': '.---',
    'K': '-.-',
    'L': '.-..',
    'M': '--',
    'N': '-.',
    'O': '---',
    'P': '.--.',
    'Q': '--.-',
    'R': '.-.',
    'S': '...',
    'T': '-',
    'U': '..-',
    'V': '...-',
    'W': '.--',
    'X': '-..-',
    'Y': '-.--',
    'Z': '--..',
  };

  /// Numbers 0-9
  static const Map<String, String> numbers = {
    '0': '-----',
    '1': '.----',
    '2': '..---',
    '3': '...--',
    '4': '....-',
    '5': '.....',
    '6': '-....',
    '7': '--...',
    '8': '---..',
    '9': '----.',
  };

  /// Common punctuation
  static const Map<String, String> punctuation = {
    '.': '.-.-.-',
    ',': '--..--',
    '?': '..--..',
    "'": '.----.',
    '!': '-.-.--',
    '/': '-..-.',
    '(': '-.--.',
    ')': '-.--.-',
    '&': '.-...',
    ':': '---...',
    ';': '-.-.-.',
    '=': '-...-',
    '+': '.-.-.',
    '-': '-....-',
    '_': '..--.-',
    '"': '.-..-.',
    '\$': '...-..-',
    '@': '.--.-.',
  };

  /// Prosigns (procedural signals) used in ham radio
  static const Map<String, String> prosigns = {
    '<AR>': '.-.-.',    // End of message
    '<AS>': '.-...',    // Wait
    '<BK>': '-...-.-',  // Break
    '<BT>': '-...-',    // New paragraph (double dash)
    '<CL>': '-.-..-..',  // Closing station
    '<CT>': '-.-.-',    // Attention / Start copying
    '<DO>': '-..---',   // Change to wabun code
    '<KN>': '-.--.',    // Invitation to specific station to transmit
    '<SK>': '...-.-',   // End of contact
    '<SN>': '...-.',    // Understood (also VE)
    '<SOS>': '...---...', // Distress signal
  };

  /// Q-codes commonly used in ham radio
  static const Map<String, String> qCodes = {
    'QRA': 'What is the name of your station?',
    'QRG': 'What is my exact frequency?',
    'QRH': 'Does my frequency vary?',
    'QRI': 'How is the tone of my transmission?',
    'QRK': 'What is the readability of my signals?',
    'QRL': 'Are you busy?',
    'QRM': 'Is my transmission being interfered with?',
    'QRN': 'Are you troubled by static?',
    'QRO': 'Shall I increase power?',
    'QRP': 'Shall I decrease power?',
    'QRQ': 'Shall I send faster?',
    'QRS': 'Shall I send more slowly?',
    'QRT': 'Shall I stop sending?',
    'QRU': 'Have you anything for me?',
    'QRV': 'Are you ready?',
    'QRX': 'When will you call me again?',
    'QRZ': 'Who is calling me?',
    'QSA': 'What is the strength of my signals?',
    'QSB': 'Are my signals fading?',
    'QSD': 'Is my keying defective?',
    'QSL': 'Can you acknowledge receipt?',
    'QSO': 'Can you communicate with...?',
    'QSP': 'Will you relay to...?',
    'QST': 'General call to all stations',
    'QSY': 'Shall I change to another frequency?',
    'QTH': 'What is your location?',
  };

  /// Get the complete character to morse mapping
  static Map<String, String> get allCharacters => {
        ...letters,
        ...numbers,
        ...punctuation,
      };

  /// Reverse mapping from morse to character
  static Map<String, String> get morseToChar {
    final Map<String, String> reversed = {};
    allCharacters.forEach((char, morse) {
      reversed[morse] = char;
    });
    return reversed;
  }

  /// Get morse code for a character (case-insensitive)
  static String? charToMorse(String char) {
    return allCharacters[char.toUpperCase()];
  }

  /// Get character from morse code
  static String? morseToCharacter(String morse) {
    return morseToChar[morse];
  }

  /// Convert text to morse code string
  static String textToMorse(String text) {
    return text
        .toUpperCase()
        .split('')
        .map((char) {
          if (char == ' ') return '/';
          return allCharacters[char] ?? '';
        })
        .where((m) => m.isNotEmpty)
        .join(' ');
  }

  /// Convert morse code string back to text
  static String morseToText(String morse) {
    return morse
        .split(' / ')
        .map((word) {
          return word.split(' ').map((m) => morseToChar[m] ?? '').join();
        })
        .join(' ');
  }

  /// Calculate timing based on words per minute (WPM)
  /// Uses the PARIS standard (50 units per word)
  static int getDotDuration(int wpm) {
    return (1200 / wpm).round();
  }

  static int getDashDuration(int wpm) {
    return getDotDuration(wpm) * 3;
  }

  static int getSymbolGap(int wpm) {
    return getDotDuration(wpm);
  }

  static int getLetterGap(int wpm) {
    return getDotDuration(wpm) * 3;
  }

  static int getWordGap(int wpm) {
    return getDotDuration(wpm) * 7;
  }
}

/// Character learning data with mnemonics and difficulty
class MorseCharacter {
  final String character;
  final String morse;
  final String mnemonic;
  final int difficulty; // 1-5, used for progressive learning

  const MorseCharacter({
    required this.character,
    required this.morse,
    required this.mnemonic,
    required this.difficulty,
  });
}

/// Learning order optimized for beginners (Koch method inspired)
const List<MorseCharacter> learningOrder = [
  // Level 1 - Simple patterns
  MorseCharacter(character: 'E', morse: '.', mnemonic: 'Egg - one dot', difficulty: 1),
  MorseCharacter(character: 'T', morse: '-', mnemonic: 'Tall - one dash', difficulty: 1),
  MorseCharacter(character: 'A', morse: '.-', mnemonic: 'A-part (dot dash)', difficulty: 1),
  MorseCharacter(character: 'N', morse: '-.', mnemonic: 'Not (dash dot)', difficulty: 1),
  MorseCharacter(character: 'I', morse: '..', mnemonic: 'It (two dots)', difficulty: 1),
  MorseCharacter(character: 'M', morse: '--', mnemonic: 'Mom (two dashes)', difficulty: 1),
  
  // Level 2 - Building patterns
  MorseCharacter(character: 'S', morse: '...', mnemonic: 'SOS starts with 3 dots', difficulty: 2),
  MorseCharacter(character: 'O', morse: '---', mnemonic: 'O-O-O three dashes', difficulty: 2),
  MorseCharacter(character: 'R', morse: '.-.', mnemonic: 'roaR (dit-dah-dit)', difficulty: 2),
  MorseCharacter(character: 'W', morse: '.--', mnemonic: 'Wide (dit-dah-dah)', difficulty: 2),
  MorseCharacter(character: 'D', morse: '-..', mnemonic: 'Dog (dah-dit-dit)', difficulty: 2),
  MorseCharacter(character: 'K', morse: '-.-', mnemonic: 'King (dah-dit-dah)', difficulty: 2),
  MorseCharacter(character: 'G', morse: '--.', mnemonic: 'Go (dah-dah-dit)', difficulty: 2),
  MorseCharacter(character: 'U', morse: '..-', mnemonic: 'Up (dit-dit-dah)', difficulty: 2),
  
  // Level 3 - Four element patterns
  MorseCharacter(character: 'H', morse: '....', mnemonic: 'Ha-ha-ha-ha (4 dots)', difficulty: 3),
  MorseCharacter(character: 'B', morse: '-...', mnemonic: 'Boom (dah-dit-dit-dit)', difficulty: 3),
  MorseCharacter(character: 'C', morse: '-.-.', mnemonic: 'Cat-Cat (dah-dit-dah-dit)', difficulty: 3),
  MorseCharacter(character: 'F', morse: '..-.', mnemonic: 'Flip (dit-dit-dah-dit)', difficulty: 3),
  MorseCharacter(character: 'L', morse: '.-..', mnemonic: 'Light (dit-dah-dit-dit)', difficulty: 3),
  MorseCharacter(character: 'P', morse: '.--.', mnemonic: 'Pop (dit-dah-dah-dit)', difficulty: 3),
  MorseCharacter(character: 'V', morse: '...-', mnemonic: 'Victory V (dit-dit-dit-dah)', difficulty: 3),
  MorseCharacter(character: 'X', morse: '-..-', mnemonic: 'X-ray (dah-dit-dit-dah)', difficulty: 3),
  
  // Level 4 - Complex patterns
  MorseCharacter(character: 'J', morse: '.---', mnemonic: 'Jump (dit-dah-dah-dah)', difficulty: 4),
  MorseCharacter(character: 'Q', morse: '--.-', mnemonic: 'Queen (dah-dah-dit-dah)', difficulty: 4),
  MorseCharacter(character: 'Y', morse: '-.--', mnemonic: 'Yes! (dah-dit-dah-dah)', difficulty: 4),
  MorseCharacter(character: 'Z', morse: '--..', mnemonic: 'Zoom (dah-dah-dit-dit)', difficulty: 4),
  
  // Level 5 - Numbers
  MorseCharacter(character: '1', morse: '.----', mnemonic: 'One leads with 1 dot', difficulty: 5),
  MorseCharacter(character: '2', morse: '..---', mnemonic: 'Two leads with 2 dots', difficulty: 5),
  MorseCharacter(character: '3', morse: '...--', mnemonic: 'Three leads with 3 dots', difficulty: 5),
  MorseCharacter(character: '4', morse: '....-', mnemonic: 'Four leads with 4 dots', difficulty: 5),
  MorseCharacter(character: '5', morse: '.....', mnemonic: 'Five = 5 dots', difficulty: 5),
  MorseCharacter(character: '6', morse: '-....', mnemonic: 'Six starts with dash', difficulty: 5),
  MorseCharacter(character: '7', morse: '--...', mnemonic: 'Seven has 2 dashes', difficulty: 5),
  MorseCharacter(character: '8', morse: '---..', mnemonic: 'Eight has 3 dashes', difficulty: 5),
  MorseCharacter(character: '9', morse: '----.', mnemonic: 'Nine has 4 dashes', difficulty: 5),
  MorseCharacter(character: '0', morse: '-----', mnemonic: 'Zero = 5 dashes', difficulty: 5),
];

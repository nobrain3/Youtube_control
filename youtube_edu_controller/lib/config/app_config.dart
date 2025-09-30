class AppConfig {
  static const String appName = 'YouTube Edu Controller';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'https://api.youtubedu.com';
  static const String youtubeApiKey = 'YOUR_YOUTUBE_API_KEY';
  static const String openaiApiKey = 'YOUR_OPENAI_API_KEY';

  // App Settings
  static const int defaultStudyInterval = 15; // minutes
  static const int minStudyInterval = 5;
  static const int maxStudyInterval = 60;
  static const int maxRetryAttempts = 3;

  // Grade Levels
  static const Map<int, String> gradeLevels = {
    1: 'Elementary 1',
    2: 'Elementary 2',
    3: 'Elementary 3',
    4: 'Elementary 4',
    5: 'Elementary 5',
    6: 'Elementary 6',
    7: 'Middle 1',
    8: 'Middle 2',
    9: 'Middle 3',
    10: 'High 1',
    11: 'High 2',
    12: 'High 3',
  };

  // Subjects
  static const List<String> subjects = [
    'Korean',
    'English',
    'Mathematics',
    'Science',
    'Social Studies',
    'History',
  ];

  // Points System
  static const int pointsPerCorrectAnswer = 10;
  static const int bonusPointsForStreak = 5;
  static const int penaltyPointsForWrongAnswer = 0;
}
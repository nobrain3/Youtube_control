import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/study_session_model.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('LocalStorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // User 관련 메서드
  Future<void> saveUser(User user) async {
    final userJson = json.encode(user.toJson());
    await prefs.setString('current_user', userJson);
  }

  User? getCurrentUser() {
    final userJson = prefs.getString('current_user');
    if (userJson == null) return null;

    try {
      final userMap = json.decode(userJson) as Map<String, dynamic>;
      return User.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await prefs.remove('current_user');
  }

  // Study Sessions 관련 메서드
  Future<void> saveStudySession(StudySession session) async {
    final sessions = await getStudySessions();
    sessions.add(session);

    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await prefs.setString('study_sessions', json.encode(sessionsJson));
  }

  Future<List<StudySession>> getStudySessions() async {
    final sessionsJson = prefs.getString('study_sessions');
    if (sessionsJson == null) return [];

    try {
      final sessionsList = json.decode(sessionsJson) as List<dynamic>;
      return sessionsList
          .map((s) => StudySession.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<StudySession>> getStudySessionsByUserId(String userId) async {
    final sessions = await getStudySessions();
    return sessions.where((s) => s.userId == userId).toList();
  }

  Future<void> updateStudySession(StudySession session) async {
    final sessions = await getStudySessions();
    final index = sessions.indexWhere((s) => s.id == session.id);

    if (index != -1) {
      sessions[index] = session;
      final sessionsJson = sessions.map((s) => s.toJson()).toList();
      await prefs.setString('study_sessions', json.encode(sessionsJson));
    }
  }

  // Study Statistics 관련 메서드
  Future<Map<String, dynamic>> getStudyStatistics(String userId) async {
    final sessions = await getStudySessionsByUserId(userId);

    if (sessions.isEmpty) {
      return {
        'totalWatchTime': 0,
        'totalQuestions': 0,
        'correctAnswers': 0,
        'accuracy': 0.0,
        'streakDays': 0,
        'totalPoints': 0,
      };
    }

    final totalWatchTime = sessions.fold<int>(
      0,
      (sum, session) => sum + (session.sessionDuration?.inMinutes ?? 0),
    );

    final totalQuestions = sessions.fold<int>(
      0,
      (sum, session) => sum + session.questionsAnswered,
    );

    final correctAnswers = sessions.fold<int>(
      0,
      (sum, session) => sum + session.correctAnswers,
    );

    final totalPoints = sessions.fold<int>(
      0,
      (sum, session) => sum + session.pointsEarned,
    );

    final accuracy = totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;
    final streakDays = _calculateStreakDays(sessions);

    return {
      'totalWatchTime': totalWatchTime,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'accuracy': accuracy,
      'streakDays': streakDays,
      'totalPoints': totalPoints,
    };
  }

  int _calculateStreakDays(List<StudySession> sessions) {
    if (sessions.isEmpty) return 0;

    // 날짜별로 세션 그룹화
    final sessionsByDate = <String, List<StudySession>>{};
    for (final session in sessions) {
      final dateKey = _formatDateKey(session.startTime);
      sessionsByDate.putIfAbsent(dateKey, () => []).add(session);
    }

    // 연속 학습 일수 계산
    final sortedDates = sessionsByDate.keys.toList()..sort();
    if (sortedDates.isEmpty) return 0;

    int streak = 1;
    DateTime currentDate = DateTime.parse(sortedDates.last);

    for (int i = sortedDates.length - 2; i >= 0; i--) {
      final previousDate = DateTime.parse(sortedDates[i]);
      final difference = currentDate.difference(previousDate).inDays;

      if (difference == 1) {
        streak++;
        currentDate = previousDate;
      } else {
        break;
      }
    }

    return streak;
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Settings 관련 메서드
  Future<void> setStudyInterval(int minutes) async {
    await prefs.setInt('study_interval', minutes);
  }

  int getStudyInterval() {
    return prefs.getInt('study_interval') ?? 15; // 기본값: 15분
  }

  Future<void> setPreferredSubjects(List<String> subjects) async {
    await prefs.setStringList('preferred_subjects', subjects);
  }

  List<String> getPreferredSubjects() {
    return prefs.getStringList('preferred_subjects') ?? ['Mathematics'];
  }

  Future<void> setUserGrade(int grade) async {
    await prefs.setInt('user_grade', grade);
  }

  int getUserGrade() {
    return prefs.getInt('user_grade') ?? 3; // 기본값: 3학년
  }

  Future<void> setDifficultyLevel(int level) async {
    await prefs.setInt('difficulty_level', level);
  }

  int getDifficultyLevel() {
    return prefs.getInt('difficulty_level') ?? 2; // 기본값: 중간
  }

  // Watch History 관련 메서드
  // 빠른 중복 체크를 위한 캐시
  Set<String>? _watchedVideoIds;

  Future<void> addToWatchHistory(Map<String, dynamic> videoData) async {
    final videoId = videoData['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return;

    final history = getWatchHistory();

    // 캐시 초기화 (필요시)
    _watchedVideoIds ??= history.map((item) => item['videoId'] as String).toSet();

    // O(1) 중복 체크
    final isDuplicate = _watchedVideoIds!.contains(videoId);

    if (isDuplicate) {
      // 기존 항목 제거 (위치 업데이트용)
      history.removeWhere((item) => item['videoId'] == videoId);
    } else {
      // 새 비디오 ID 캐시에 추가
      _watchedVideoIds!.add(videoId);
    }

    // 새 항목을 맨 앞에 추가
    history.insert(0, {
      ...videoData,
      'watchedAt': DateTime.now().toIso8601String(),
    });

    // 최대 100개까지만 보관
    if (history.length > 100) {
      // 제거되는 항목들의 ID를 캐시에서도 제거
      for (int i = 100; i < history.length; i++) {
        final removedId = history[i]['videoId'] as String?;
        if (removedId != null) {
          _watchedVideoIds!.remove(removedId);
        }
      }
      history.removeRange(100, history.length);
    }

    await prefs.setString('watch_history', json.encode(history));
  }

  List<Map<String, dynamic>> getWatchHistory() {
    final historyJson = prefs.getString('watch_history');
    if (historyJson == null) return [];

    try {
      final historyList = json.decode(historyJson) as List<dynamic>;
      return historyList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearWatchHistory() async {
    await prefs.remove('watch_history');
  }

  // App 설정 관련
  Future<void> setFirstLaunch(bool isFirst) async {
    await prefs.setBool('is_first_launch', isFirst);
  }

  bool isFirstLaunch() {
    return prefs.getBool('is_first_launch') ?? true;
  }

  Future<void> setThemeMode(String mode) async {
    await prefs.setString('theme_mode', mode);
  }

  String getThemeMode() {
    return prefs.getString('theme_mode') ?? 'system';
  }

  // 데이터 내보내기/가져오기
  Future<Map<String, dynamic>> exportAllData() async {
    final user = getCurrentUser();
    final sessions = await getStudySessions();
    final history = getWatchHistory();

    return {
      'user': user?.toJson(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'history': history,
      'settings': {
        'studyInterval': getStudyInterval(),
        'preferredSubjects': getPreferredSubjects(),
        'userGrade': getUserGrade(),
        'difficultyLevel': getDifficultyLevel(),
        'themeMode': getThemeMode(),
      },
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    try {
      // User 데이터 가져오기
      if (data['user'] != null) {
        final user = User.fromJson(data['user']);
        await saveUser(user);
      }

      // Sessions 데이터 가져오기
      if (data['sessions'] != null) {
        final sessions = (data['sessions'] as List)
            .map((s) => StudySession.fromJson(s))
            .toList();
        for (final session in sessions) {
          await saveStudySession(session);
        }
      }

      // History 데이터 가져오기
      if (data['history'] != null) {
        await prefs.setString('watch_history', json.encode(data['history']));
      }

      // Settings 데이터 가져오기
      if (data['settings'] != null) {
        final settings = data['settings'] as Map<String, dynamic>;

        if (settings['studyInterval'] != null) {
          await setStudyInterval(settings['studyInterval']);
        }
        if (settings['preferredSubjects'] != null) {
          await setPreferredSubjects(
            List<String>.from(settings['preferredSubjects'])
          );
        }
        if (settings['userGrade'] != null) {
          await setUserGrade(settings['userGrade']);
        }
        if (settings['difficultyLevel'] != null) {
          await setDifficultyLevel(settings['difficultyLevel']);
        }
        if (settings['themeMode'] != null) {
          await setThemeMode(settings['themeMode']);
        }
      }
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  // 데이터 초기화
  Future<void> clearAllData() async {
    await prefs.clear();
  }
}
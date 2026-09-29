import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';

class AppDownloadService {
  AppDownloadService._();
  static final AppDownloadService instance = AppDownloadService._();

  static const String _keyAndroidUrl = 'mobile_download_android_url';
  static const String _keyIosUrl = 'mobile_download_ios_url';
  static const String _keyIpaUrl = 'mobile_download_ipa_url';

  // URL padrão de APK hospedado no Supabase Storage do próprio projeto (bucket anexos-tarefas)
  static String get defaultAndroidUrl {
    final base = SupabaseConfig.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/storage/v1/object/public/anexos-tarefas/downloads/taskflow.apk';
  }

  // URL padrão de IPA hospedado no Supabase Storage do próprio projeto (bucket anexos-tarefas)
  static String get defaultIpaUrl {
    final base = SupabaseConfig.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/storage/v1/object/public/anexos-tarefas/downloads/taskflow.ipa';
  }

  // URL padrão de instalação iOS (TestFlight Público Oficial)
  static const String defaultIosUrl = 'https://testflight.apple.com/join/6AGWTTYj';

  Future<String> getAndroidUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyAndroidUrl);
      if (saved == null || saved.contains('/storage/v1/object/public/downloads/taskflow.apk')) {
        return defaultAndroidUrl;
      }
      return saved;
    } catch (_) {
      return defaultAndroidUrl;
    }
  }

  Future<String> getIpaUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyIpaUrl) ?? defaultIpaUrl;
    } catch (_) {
      return defaultIpaUrl;
    }
  }

  Future<String> getIosUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyIosUrl) ?? defaultIosUrl;
    } catch (_) {
      return defaultIosUrl;
    }
  }

  Future<void> setUrls({String? androidUrl, String? ipaUrl, String? iosUrl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (androidUrl != null && androidUrl.trim().isNotEmpty) {
        await prefs.setString(_keyAndroidUrl, androidUrl.trim());
      }
      if (ipaUrl != null && ipaUrl.trim().isNotEmpty) {
        await prefs.setString(_keyIpaUrl, ipaUrl.trim());
      }
      if (iosUrl != null && iosUrl.trim().isNotEmpty) {
        await prefs.setString(_keyIosUrl, iosUrl.trim());
      }
    } catch (e) {
      // Ignora erro de persistência
    }
  }

  Future<bool> downloadAndroid() async {
    final url = await getAndroidUrl();
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> downloadIpa() async {
    final url = await getIpaUrl();
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openIosInstall() async {
    final url = await getIosUrl();
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

import 'failure.dart';

/// Default Indonesian message for any [Failure] variant.
///
/// Screens that handle a specific `apiCode` (for example `otp_invalid` with
/// its attempts left) show their own copy instead.
extension FailureMessage on Failure {
  /// The fallback display message for this failure.
  String get displayMessage => switch (this) {
    NetworkFailure() => 'Tidak ada koneksi internet. Periksa jaringanmu.',
    TimeoutFailure() => 'Koneksi lambat. Coba lagi sebentar.',
    BadRequestFailure() => 'Permintaan tidak dapat diproses.',
    UnauthorizedFailure() => 'Sesi berakhir. Silakan masuk lagi.',
    ForbiddenFailure() => 'Kamu tidak punya akses untuk tindakan ini.',
    NotFoundFailure() => 'Data tidak ditemukan.',
    ConflictFailure() => 'Tindakan ini tidak bisa dilakukan sekarang.',
    ValidationFailure() => 'Periksa lagi isian yang ditandai.',
    TooManyRequestsFailure() => 'Terlalu banyak percobaan. Tunggu sebentar.',
    ServerFailure() => 'Terjadi gangguan di server. Coba lagi nanti.',
    CacheFailure() => 'Gagal membaca data di perangkat.',
    UnknownFailure() => 'Terjadi kesalahan. Coba lagi.',
  };
}

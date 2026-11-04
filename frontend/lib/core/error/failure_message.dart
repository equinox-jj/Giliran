import '../utils/enums/api_error_code.dart';
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
    BadRequestFailure(code: ApiErrorCode.fileTooLarge) => 'Foto lebih dari 5 MB. Pilih foto lain.',
    BadRequestFailure(code: ApiErrorCode.unsupportedMediaType) => 'Format tidak didukung. Pakai JPG atau PNG.',
    BadRequestFailure() => 'Permintaan tidak dapat diproses.',
    UnauthorizedFailure() => 'Sesi berakhir. Silakan masuk lagi.',
    ForbiddenFailure() => 'Kamu tidak punya akses untuk tindakan ini.',
    NotFoundFailure() => 'Data tidak ditemukan.',
    ConflictFailure(code: ApiErrorCode.drawTooEarly) => 'Belum waktunya mengocok periode ini.',
    ConflictFailure(code: ApiErrorCode.drawAlreadyDone) => 'Periode ini sudah dikocok.',
    ConflictFailure(code: ApiErrorCode.paymentsIncomplete) => 'Belum semua anggota sudah bayar.',
    ConflictFailure(code: ApiErrorCode.periodNotOpen) => 'Periode ini belum dibuka.',
    ConflictFailure(code: ApiErrorCode.payoutAlreadyRecorded) => 'Penyerahan sudah dicatat pengurus lain.',
    ConflictFailure() => 'Tindakan ini tidak bisa dilakukan sekarang.',
    ValidationFailure() => 'Periksa lagi isian yang ditandai.',
    TooManyRequestsFailure() => 'Terlalu banyak percobaan. Tunggu sebentar.',
    ServerFailure() => 'Terjadi gangguan di server. Coba lagi nanti.',
    CacheFailure() => 'Gagal membaca data di perangkat.',
    UnknownFailure() => 'Terjadi kesalahan. Coba lagi.',
  };
}

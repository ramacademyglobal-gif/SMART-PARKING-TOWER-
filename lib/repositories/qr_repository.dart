import 'package:multiparking_tower/models/qr_code_model.dart';

abstract class QrRepository {
  Future<QrCodeModel?> getCurrentQr();

  Future<QrCodeModel> refreshQr();
}

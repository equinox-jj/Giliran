import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/settings/domain/entities/user_settings.dart';
import 'package:giliran/features/settings/domain/usecases/update_settings_usecase.dart';

import '../../../../helpers/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late UpdateSettingsUseCase useCase;

  setUp(() {
    repository = FakeSettingsRepository();
    useCase = UpdateSettingsUseCase(repository);
  });

  test('sends the patch and returns the saved settings', () async {
    // Arrange
    const patch = UserSettingsPatch(notifyGroupActivity: true);

    // Act
    final result = await useCase(patch);

    // Assert
    expect(repository.patches, [patch]);
    expect(result.toNullable()?.notifyGroupActivity, isTrue);
  });

  test('does not send an empty patch', () async {
    // Arrange
    const patch = UserSettingsPatch();

    // Act
    final result = await useCase(patch);

    // Assert
    expect(repository.patches, isEmpty);
    expect(result.isRight(), isTrue);
  });
}

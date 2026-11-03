import '../../domain/entity/profile.dart';
import '../../domain/entity/session.dart';
import '../datasource/model/profile_model.dart';
import '../datasource/model/session_model.dart';

extension SessionModelMapper on SessionModel {
  Session toEntity() => Session(
    id: id,
    deviceName: deviceName,
    devicePlatform: devicePlatform,
    lastActiveAt: lastActiveAt,
    createdAt: createdAt,
    isCurrent: isCurrent,
  );
}

extension ProfileModelMapper on ProfileModel {
  Profile toEntity() {
    return Profile(
      data: data?.toEntity(),
    );
  }
}

extension ProfileDataModelMapper on ProfileDataModel {
  ProfileData toEntity() {
    return ProfileData(
      id: id,
      email: email,
      phone: phone,
      name: name,
      avatarUrl: avatarUrl,
      pinSet: pinSet,
      createdAt: createdAt,
    );
  }
}

extension ProfileEntityMapper on Profile {
  ProfileModel toModel() {
    return ProfileModel(
      data: data?.toModel(),
    );
  }
}

extension ProfileDataEntityMapper on ProfileData {
  ProfileDataModel toModel() {
    return ProfileDataModel(
      id: id,
      email: email,
      phone: phone,
      name: name,
      avatarUrl: avatarUrl,
      pinSet: pinSet,
      createdAt: createdAt,
    );
  }
}

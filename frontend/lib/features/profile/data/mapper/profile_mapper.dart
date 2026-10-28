import '../../domain/entity/profile.dart';
import '../datasource/model/profile_model.dart';

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

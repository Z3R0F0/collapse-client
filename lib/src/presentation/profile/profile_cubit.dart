import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/profile/profile_repository.dart';

import 'profile_state.dart';

export 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this.repository, this.userId)
    : _accountGeneration = repository.accountGeneration,
      super(const ProfileState());
  final ProfileRepository repository;
  final String userId;
  final int _accountGeneration;
  bool get _active =>
      !isClosed && repository.accountGeneration == _accountGeneration;
  int _generation = 0;
  Future<void> load() async {
    if (!_active) return;
    final generation = ++_generation;
    emit(
      ProfileState(
        profile: state.profile,
        members: state.members,
        loading: true,
      ),
    );
    try {
      final profile = await repository.get(userId, refresh: true);
      if (!_active || generation != _generation) return;
      emit(ProfileState(profile: profile, members: state.members));
      if (profile.isGroup) {
        final members = await repository.members(userId);
        if (_active && generation == _generation) {
          emit(ProfileState(profile: profile, members: members));
        }
      }
    } catch (error) {
      if (_active && generation == _generation) {
        emit(
          ProfileState(
            profile: state.profile,
            members: state.members,
            error: error,
          ),
        );
      }
    }
  }

  Future<void> save(
    String name,
    String about, {
    Uint8List? photo,
    String? photoName,
    String? photoMime,
  }) async {
    if (!_active) return;
    final generation = ++_generation;
    emit(ProfileState(profile: state.profile, loading: true));
    try {
      final profile = await repository.update(
        name: name,
        about: about,
        photo: photo,
        photoName: photoName,
        photoMime: photoMime,
      );
      if (_active && generation == _generation) {
        emit(ProfileState(profile: profile));
      }
    } catch (error) {
      if (_active && generation == _generation) {
        emit(ProfileState(profile: state.profile, error: error));
      }
    }
  }

  Future<void> invite(String memberId) async {
    if (!_active) return;
    await repository.addMember(userId, memberId);
    if (_active) await load();
  }
}

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/profile/profile_repository.dart';

import 'contacts_state.dart';

export 'contacts_state.dart';

class ContactsCubit extends Cubit<ContactsState> {
  ContactsCubit(this.repository) : super(const ContactsState());
  final ProfileRepository repository;
  Timer? _debounce;
  int _generation = 0;
  void search(String query) {
    _debounce?.cancel();
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      emit(const ContactsState());
      return;
    }
    emit(ContactsState(loading: true, query: query.trim()));
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await repository.search(query);
        if (!isClosed && generation == _generation) {
          emit(ContactsState(contacts: results, query: query.trim()));
        }
      } catch (error) {
        if (!isClosed && generation == _generation) {
          emit(ContactsState(error: error, query: query.trim()));
        }
      }
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

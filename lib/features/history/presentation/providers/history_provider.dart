import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

enum HistoryFilterKind { all, monthly, annual, currentMonth }

extension HistoryFilterKindX on HistoryFilterKind {
  String get label => switch (this) {
        HistoryFilterKind.all => 'All',
        HistoryFilterKind.monthly => 'Monthly',
        HistoryFilterKind.annual => 'Annual',
        HistoryFilterKind.currentMonth => 'This month',
      };

  /// Backend filter token when the repository can apply it server-side.
  String? get apiFilter => switch (this) {
        HistoryFilterKind.all => null,
        HistoryFilterKind.monthly => 'monthly',
        HistoryFilterKind.annual => 'annual',
        HistoryFilterKind.currentMonth => null,
      };
}

class HistoryQuery extends Equatable {
  const HistoryQuery({
    this.search = '',
    this.filter = HistoryFilterKind.all,
  });

  final String search;
  final HistoryFilterKind filter;

  HistoryQuery copyWith({
    String? search,
    HistoryFilterKind? filter,
  }) {
    return HistoryQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [search, filter];
}

class HistoryQueryController extends Notifier<HistoryQuery> {
  @override
  HistoryQuery build() => const HistoryQuery();

  void setSearch(String search) => state = state.copyWith(search: search);

  void setFilter(HistoryFilterKind filter) =>
      state = state.copyWith(filter: filter);

  void reset() => state = const HistoryQuery();
}

final historyQueryProvider =
    NotifierProvider<HistoryQueryController, HistoryQuery>(
  HistoryQueryController.new,
);

final parkingHistoryListProvider =
    FutureProvider<List<ParkingHistoryModel>>((ref) async {
  final query = ref.watch(historyQueryProvider);
  final results = await ref.watch(parkingRepositoryProvider).getHistory(
        search: query.search.trim().isEmpty ? null : query.search.trim(),
        filter: query.filter.apiFilter,
      );

  if (query.filter != HistoryFilterKind.currentMonth) {
    return results;
  }

  final now = DateTime.now();
  return results
      .where(
        (item) =>
            item.entryAt.year == now.year && item.entryAt.month == now.month,
      )
      .toList();
});

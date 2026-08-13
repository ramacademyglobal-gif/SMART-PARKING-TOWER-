import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/app_text_field.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/features/staff/presentation/screens/staff_home_screen.dart';
import 'package:multiparking_tower/models/staff_models.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

class StaffSessionsScreen extends ConsumerStatefulWidget {
  const StaffSessionsScreen({super.key});

  @override
  ConsumerState<StaffSessionsScreen> createState() =>
      _StaffSessionsScreenState();
}

class _StaffSessionsScreenState extends ConsumerState<StaffSessionsScreen> {
  final _searchController = TextEditingController();
  String _status = 'parked';
  int? _floor; // null = all floors; set to avoid dumping unrelated floors
  List<StaffSessionModel> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(staffRepositoryProvider).listSessions(
            status: _status,
            floor: _floor,
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Parking sessions'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search plate / slot / driver',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'parked', label: Text('Parked')),
                ButtonSegment(value: 'completed', label: Text('Completed')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
                _load();
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All floors'),
                    selected: _floor == null,
                    onSelected: (_) {
                      setState(() => _floor = null);
                      _load();
                    },
                  ),
                ),
                for (var f = 1; f <= 11; f++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('F$f'),
                      selected: _floor == f,
                      onSelected: (_) {
                        setState(() => _floor = f);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const TowerLoadingPanel(
        title: 'Loading sessions',
        subtitle: 'Fetching gate activity…',
        onDark: false,
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_rows.isEmpty) {
      return const EmptyState(
        icon: Icons.local_parking_outlined,
        title: 'No sessions',
        subtitle: 'Nothing matches this filter right now.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = _rows[index];
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.vehicleNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: session.isWalkIn
                          ? AppColors.peachSoft
                          : AppColors.tealDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      session.isWalkIn ? 'Walk-in' : 'App',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(session.slotLabel),
              Text(
                'In ${Formatters.dateTime(session.entryAt)}'
                '${session.exitAt != null ? ' · Out ${Formatters.dateTime(session.exitAt!)}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (session.needsPayment) ...[
                const SizedBox(height: 8),
                Text(
                  'Due ${Formatters.currency(session.amountRupees ?? 0, decimals: false)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
              if (session.isParked) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        final closed = await ref
                            .read(staffRepositoryProvider)
                            .checkout(session.id);
                        ref.invalidate(staffOverviewProvider);
                        ref.invalidate(staffParkedSessionsProvider);
                        await _load();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              closed.needsPayment
                                  ? 'Checkout done · ${Formatters.currency(closed.amountRupees ?? 0, decimals: false)} due'
                                  : 'Checkout done',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(describeError(error)),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Checkout'),
                  ),
                ),
              ] else if (session.needsPayment) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(staffRepositoryProvider)
                          .collectPayment(session.id);
                      ref.invalidate(staffOverviewProvider);
                      await _load();
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Mark paid'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

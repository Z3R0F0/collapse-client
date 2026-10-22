part of 'message_search_screen.dart';

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state, this.onSelect});
  final MessageSearchState state;
  final ValueChanged<SearchHit>? onSelect;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MessageSearchCubit>();
    final page = state.page;
    final hits = page?.hits ?? const <SearchHit>[];
    return Column(
      children: [
        if (state.busy) const LinearProgressIndicator(),
        if (state.query.trim().isEmpty)
          Padding(
            padding: EdgeInsets.all(context.collapseTheme.gap),
            child: Text(context.l10n.searchScope),
          )
        else if (page != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.collapseTheme.gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !page.cacheIndexed
                      ? context.l10n.indexingMessages
                      : page.historyComplete
                      ? context.l10n.searchComplete
                      : context.l10n.searchPartial,
                ),
                if (page.canLoadHistory)
                  TextButton(
                    onPressed: state.busy ? null : cubit.loadHistory,
                    child: Text(context.l10n.loadOlderMessages),
                  ),
              ],
            ),
          ),
        if (state.error)
          TextButton.icon(
            onPressed: () => cubit.search(state.query, immediate: true),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retry),
          ),
        Expanded(
          child: hits.isEmpty
              ? Center(
                  child: Text(
                    state.query.trim().isEmpty || state.busy
                        ? ''
                        : context.l10n.noMessageMatches,
                  ),
                )
              : ListView.builder(
                  key: ValueKey((state.query, hits.first.id)),
                  itemCount: hits.length,
                  itemBuilder: (context, index) {
                    final hit = hits[index];
                    final local = hit.createdAt.toLocal();
                    final material = MaterialLocalizations.of(context);
                    final timestamp =
                        '${material.formatCompactDate(local)} '
                        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
                    return ListTile(
                      key: ValueKey(hit.id),
                      title: Text(
                        hit.snippet,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(timestamp),
                      trailing: hit.seq < 0
                          ? Tooltip(
                              message: context.l10n.queued,
                              child: const Icon(Icons.schedule, size: 16),
                            )
                          : null,
                      onTap: () => onSelect != null
                          ? onSelect!(hit)
                          : Navigator.of(context).pop(hit),
                    );
                  },
                ),
        ),
        if (state.canPrevious || page?.nextCursor != null)
          Padding(
            padding: EdgeInsets.all(context.collapseTheme.gap),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: context.collapseTheme.gap,
              children: [
                TextButton.icon(
                  onPressed: !state.busy && state.canPrevious
                      ? cubit.previous
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(context.l10n.newerResults),
                ),
                TextButton.icon(
                  onPressed: !state.busy && page?.nextCursor != null
                      ? cubit.next
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(context.l10n.olderResults),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

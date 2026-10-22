import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme.dart';
import '../../../domain/chat/search_models.dart';
import 'message_search_cubit.dart';

part 'search_results.dart';

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({
    super.key,
    this.query = '',
    this.onQuery,
    this.onSelect,
    this.onBack,
  });
  final String query;
  final ValueChanged<String>? onQuery;
  final ValueChanged<SearchHit>? onSelect;
  final VoidCallback? onBack;

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  late final _input = TextEditingController(text: widget.query);
  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) {
      context.read<MessageSearchCubit>().search(widget.query, immediate: true);
    }
  }

  @override
  void didUpdateWidget(MessageSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _input.text) {
      _input.text = widget.query;
      context.read<MessageSearchCubit>().search(widget.query, immediate: true);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MessageSearchCubit>();
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: Text(context.l10n.searchMessages),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => cubit.search(cubit.state.query, immediate: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.collapseTheme.gap),
            child: TextField(
              controller: _input,
              autofocus: true,
              maxLength: 256,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              textInputAction: TextInputAction.search,
              onChanged: (query) {
                cubit.search(query);
                widget.onQuery?.call(query);
              },
              onSubmitted: (query) => cubit.search(query, immediate: true),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.searchWords,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<MessageSearchCubit, MessageSearchState>(
              builder: (context, state) =>
                  _SearchResults(state: state, onSelect: widget.onSelect),
            ),
          ),
        ],
      ),
    );
  }
}

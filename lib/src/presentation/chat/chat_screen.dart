import 'dart:async';
import 'package:clock/clock.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/theme.dart';
import '../../../dependency_injection.dart';
import '../../../widgets/view_activity.dart';
import '../../data/chat/chats_repository.dart';
import '../../data/media/media_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/chat/chat_models.dart';
import '../../domain/chat/media_models.dart';
import '../navigation/app_navigation.dart';
import 'attachment_bytes.dart';
import 'attachment_mime.dart';
import 'image_dimensions.dart';
import 'video_metadata.dart';
import 'chat_cubit.dart';
import 'drafty_content.dart';
import 'message_arrival.dart';
import 'message_list.dart';
import 'search/message_search_cubit.dart';
import 'search/message_search_screen.dart';
import 'window_policy.dart';

part 'chat_view.dart';
part 'chat_bubble.dart';
part 'chat_scroll.dart';
part 'chat_receipts.dart';
part 'chat_composer.dart';
part 'chat_attachments.dart';
part 'chat_recording.dart';
part 'chat_actions.dart';
part 'chat_motion.dart';
part 'chat_navigation.dart';
part 'chat_draft.dart';
part 'chat_submit.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.topicId,
    required this.userId,
    required this.title,
    required this.onProfile,
    this.onBack,
    this.onSearch,
    this.onMessageTarget,
    this.onClearTarget,
    this.targetSeq,
    this.targetId,
  });
  final String topicId;
  final String userId;
  final String title;
  final VoidCallback onProfile;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final void Function(int seq, String? id)? onMessageTarget;
  final VoidCallback? onClearTarget;
  final int? targetSeq;
  final String? targetId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = chat.InMemoryChatController();
  final _scroll = FlutterListViewController();
  final _input = TextEditingController();
  final _viewport = GlobalKey();
  final _composer = GlobalKey();
  final _keys = <String, GlobalKey>{};
  final _arrivals = <String, DateTime>{};
  final _recorder = AudioRecorder();
  ChatState? _next;
  ChatState _renderState = const ChatState(loading: true);
  ({String id, int epoch, int revision})? _pendingRebase;
  bool _updating = false;
  bool _presented = false;
  Future<void> _rendered = Future.value();
  int _jumpGeneration = 0;
  bool _jumping = false;
  String? _highlightedId;
  Timer? _highlightTimer;
  bool _appActive = true;
  bool _viewActive = true;
  (int?, String?)? _linkedTarget;
  bool _recording = false;
  bool _recordingPending = false;
  int _recordingOperation = 0;
  int _draftRevision = 0;
  bool _suppressDraftSave = false;
  bool _following = true;
  DateTime? _recordingStarted;
  Timer? _recordingLimit;
  Timer? _draftTimer;
  ChatMessage? _reply;
  List<ChatMessage> _shown = const [];
  int? _initialRead;
  int _lastVisibleRead = 0;
  late final ChatCubit _cubit;
  late final ChatsRepository _repository;
  late final int _draftSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _cubit = context.read<ChatCubit>();
    _repository = context.read<ChatsRepository>();
    _linkedTarget = (widget.targetSeq, widget.targetId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _changed(_cubit.state);
    });
    _initDraft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        ViewActivity.isActiveOf(context);
    if (_viewActive && !current && (_draftTimer?.isActive ?? false)) {
      _saveDraft();
    }
    if (_viewActive && !current) _cancelRecording();
    _viewActive = current;
    if (!current || MediaQuery.disableAnimationsOf(context)) {
      _arrivals.clear();
    }
    // A retained list need not repaint its visibility detectors on route return.
    if (current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleNow());
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = (widget.targetSeq, widget.targetId);
    if (target == (oldWidget.targetSeq, oldWidget.targetId) ||
        target == _linkedTarget) {
      return;
    }
    final latest = target == (null, null);
    // Latest/send-from-history already issued their navigation before clearing
    // the URL. Their null sentinel consumes that echo without a second open.
    final alreadyNavigated = latest && _linkedTarget == null;
    _linkedTarget = target;
    if (alreadyNavigated) return;
    if (latest) {
      _jumpGeneration++;
      _jumping = false;
      _highlightTimer?.cancel();
      _highlightedId = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _linkedTarget == target &&
          (widget.targetSeq, widget.targetId) == target) {
        unawaited(
          latest
              ? _cubit.jumpToLatest()
              : _jumpTo(target.$1 ?? 0, id: target.$2),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    // A first-use permission dialog may briefly be inactive. Keep its pending
    // intent, but discard capture on backgrounding or active-recording blur.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive && _recording)) {
      _cancelRecording();
    }
    if (!_appActive && (_draftTimer?.isActive ?? false)) _saveDraft();
    if (!_appActive && _arrivals.isNotEmpty) setState(_arrivals.clear);
    if (_appActive) {
      _markVisibleNow();
      WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleNow());
    }
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => _buildView(context);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelRecording(updateUi: false);
    if (_draftTimer?.isActive ?? false) _saveDraft();
    _highlightTimer?.cancel();
    _jumpGeneration++;
    _recorder.dispose();
    _scroll.dispose();
    _input.dispose();
    _controller.dispose();
    super.dispose();
  }
}

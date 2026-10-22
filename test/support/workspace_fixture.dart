import 'package:collapse/core/theme.dart';
import 'package:collapse/src/presentation/app/workspace_layout.dart';
import 'package:collapse/widgets/view_activity.dart';
import 'package:flutter/material.dart';

class WorkspaceFixture extends StatefulWidget {
  const WorkspaceFixture({super.key});

  @override
  State<WorkspaceFixture> createState() => WorkspaceFixtureState();
}

class WorkspaceFixtureState extends State<WorkspaceFixture> {
  final masterKey = GlobalKey<PaneProbeState>();
  final detailKey = GlobalKey<PaneProbeState>();
  final changedWidths = <double>[];
  double width = 1120, sidebar = 320, textScale = 1;
  bool hasDetail = true, compact = false, active = true;

  void change(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: appTheme(Brightness.dark),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 700,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: ViewActivity(
              active: active,
              child: WorkspaceLayout(
                masterBuilder: (_, value) {
                  compact = value;
                  return PaneProbe(key: masterKey, name: 'master');
                },
                detail: PaneProbe(key: detailKey, name: 'detail'),
                hasDetail: hasDetail,
                sidebarWidth: sidebar,
                onSidebarWidthChanged: (value) => change(() {
                  sidebar = value;
                  changedWidths.add(value);
                }),
                resizeLabel: 'Resize sidebar',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PaneProbe extends StatefulWidget {
  const PaneProbe({super.key, required this.name});

  final String name;

  @override
  State<PaneProbe> createState() => PaneProbeState();
}

class PaneProbeState extends State<PaneProbe> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final focus = FocusNode();
  final ownedState = Object();
  bool active = true, ticking = true, disposed = false;
  Size size = Size.zero;

  @override
  Widget build(BuildContext context) {
    active = ViewActivity.isActiveOf(context);
    ticking = TickerMode.valuesOf(context).enabled;
    return LayoutBuilder(
      builder: (_, constraints) {
        size = constraints.biggest;
        return Column(
          children: [
            TextField(
              key: ValueKey('${widget.name}-input'),
              controller: input,
              focusNode: focus,
              decoration: InputDecoration(hintText: '${widget.name} draft'),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: 50,
                itemExtent: 48,
                itemBuilder: (_, index) => SizedBox(
                  height: 48,
                  child: Text('${widget.name} $index', maxLines: 1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    disposed = true;
    input.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }
}

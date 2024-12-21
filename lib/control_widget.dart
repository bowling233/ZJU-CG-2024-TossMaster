import 'package:flutter/material.dart';

enum Mode { editScene, game, editLight }

class ControlWidget extends StatefulWidget {
  const ControlWidget({super.key});
  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  Mode _mode = Mode.editScene;

  Widget get _modeWidget {
    switch (_mode) {
      case Mode.editScene:
        return const EditSceneWidget();
      case Mode.game:
        return const GameModeWidget();
      case Mode.editLight:
        return const EditLightWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(
      children: <Widget>[
        _modeWidget,
        const Spacer(),
        SegmentedButton<Mode>(
          segments: const <ButtonSegment<Mode>>[
            ButtonSegment<Mode>(
              value: Mode.editScene,
              label: Text('场景编辑'),
              icon: Icon(Icons.edit),
            ),
            ButtonSegment<Mode>(
              value: Mode.editLight,
              label: Text('光照编辑'),
              icon: Icon(Icons.lightbulb),
            ),
            ButtonSegment<Mode>(
              value: Mode.game,
              label: Text('游戏'),
              icon: Icon(Icons.gamepad),
            ),
          ],
          selected: <Mode>{_mode},
          onSelectionChanged: (Set<Mode> newSelection) {
            setState(() {
              _mode = newSelection.first;
            });
          },
        )
      ],
    ));
  }
}

class EditSceneWidget extends StatelessWidget {
  const EditSceneWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          onPressed: () {},
          label: const Text('选择模型'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.lightbulb),
          onPressed: () {},
          label: const Text('光照调整'),
        ),
      ],
    );
  }
}

class GameModeWidget extends StatelessWidget {
  const GameModeWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}

class EditLightWidget extends StatelessWidget {
  const EditLightWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}

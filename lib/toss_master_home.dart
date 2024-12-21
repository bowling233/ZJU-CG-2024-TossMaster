import 'package:flutter/material.dart';
import 'opengl_test.dart';
import 'control_widget.dart';
import 'opengl_model.dart';
import 'package:file_picker/file_picker.dart';
import 'toss_master_state.dart';
import 'package:provider/provider.dart';

class TossMasterHome extends StatefulWidget {
  const TossMasterHome({super.key, required this.title});

  final String title;

  @override
  State<TossMasterHome> createState() => _TossMasterHomeState();
}

class _TossMasterHomeState extends State<TossMasterHome> {
  List<ImportedModel> models = [];
  int currentModelIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  // 用于选择模型的对话框
  Future<void> _modelsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AlertDialog Title'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('等待替换为模型显示'),
              ],
            ),
          ),
          actions: <Widget>[
            // 取消按钮
            TextButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // 添加模型按钮
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () async {
                FilePickerResult? result =
                    await FilePicker.platform.pickFiles();
                if (result == null) {
                  return;
                }
                final file = result.files.single;
                final path = file.path;
                if (path == null) {
                  return;
                }
                debugPrint("selected file: $path");
                final model = ImportedModel(path);

                models.add(model);
                setState(() {});
              },
            ),
            // 确定选中按钮
            TextButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ChangeNotifierProvider(
          create: (context) => TossMasterState(),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              OpenGLScene(),
              ControlWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

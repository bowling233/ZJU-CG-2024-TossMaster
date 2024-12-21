import 'dart:collection';

import 'package:flutter/material.dart';
import 'opengl_model.dart';
import 'package:vector_math/vector_math.dart' as vm;

class TossMasterState extends ChangeNotifier {
  // 相机数据
  vm.Vector3 cameraPos = vm.Vector3(0, 0, 12.0);
  vm.Vector3 cameraFront = vm.Vector3(0, 0, -1.0);
  vm.Vector3 cameraUp = vm.Vector3(0, 1.0, 0);
  // 光照数据（TODO）
  // 模型库
  final List<ImportedModel> _importedModels = [];
  UnmodifiableListView<ImportedModel> get importedModels =>
      UnmodifiableListView(_importedModels);
  int currentImportedModelIndex = 0;
  void addImportedModel(ImportedModel model) {
    _importedModels.add(model);
    notifyListeners();
  }

  void removeImportedModel(int index) {
    _importedModels.removeAt(index);
    notifyListeners();
  }

  void changeImportedModel(int index, ImportedModel model) {
    _importedModels[index] = model;
    notifyListeners();
  }

  void setCurrentImportedModelIndex(int index) {
    currentImportedModelIndex = index;
    notifyListeners();
  }

  // 物体库
  final List<SceneModel> _sceneModels = [];
  UnmodifiableListView<SceneModel> get sceneModels =>
      UnmodifiableListView(_sceneModels);
  int currentSceneModelIndex = 0;
  void addSceneModel(SceneModel model) {
    _sceneModels.add(model);
    notifyListeners();
  }

  void removeSceneModel(int index) {
    _sceneModels.removeAt(index);
    notifyListeners();
  }

  void changeSceneModel(int index, SceneModel model) {
    _sceneModels[index] = model;
    notifyListeners();
  }

  void setCurrentSceneModelIndex(int index) {
    currentSceneModelIndex = index;
    notifyListeners();
  }
}

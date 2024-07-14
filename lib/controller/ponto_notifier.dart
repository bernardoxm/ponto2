import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ponto/Service/auth_Login_Service.dart';
import 'package:ponto/Service/auth_user_Service.dart';
import 'package:ponto/Service/ponto_Service.dart';
// Adicione a importação do UserService
import 'package:ponto/controller/image_select.dart';
import 'package:ponto/controller/local_auth.dart';
import 'package:ponto/model/employerRep.dart';
import 'package:ponto/model/usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PontoNotifier extends ChangeNotifier {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _isLoadingImage = false;
  bool _isLoadingUser = true; // Estado de carregamento do usuário
  DateFormat? _formatterDay;
  File? _image;
  late ImageSelectController _imageSelectController;
  final LocalAuthController _authController = LocalAuthController();
  late Usuario _usuario = Usuario(
    fullName: '',
    email: '',
    profileID: '',
  );
  late Employerrep _employer = Employerrep(employerID: '');

  late BuildContext _context;
  DateTime? _expiryDate;

  List<DateTime?> pontos = List.filled(4, null);

  PontoNotifier(this._context) {
    _imageSelectController = ImageSelectController();
    pontoExpiry();
    _initImage();
    _loadPointsLocally();
    _initUsuario(); // Carregar usuário da API ou localmente
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _now = DateTime.now();
      notifyListeners();
    });
  }

  ImageProvider? imageProvider;
  bool isLoading = true;

  void _initImage() async {
    await _imageSelectController.initSharedPreferences();
    File? savedImage = await _imageSelectController.getSavedImage();
    if (savedImage != null) {
      _image = savedImage;
      imageProvider = FileImage(savedImage);
      isLoading = false;
      notifyListeners();
    } else {
      imageProvider = const AssetImage("lib/assets/image/defaultprofile.png");
      isLoading = false;
    }
  }

  void _initUsuario() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? fullName = prefs.getString('userFullName');
    String? email = prefs.getString('userEmail');
    String? profileID = prefs.getString('profileID');
    String? employerID = prefs.getString('employerID');

    if (fullName != null &&
        email != null &&
        profileID != null &&
        employerID != null) {
      _usuario = Usuario(
        fullName: fullName,
        email: email,
        profileID: profileID,
      );
      _employer = Employerrep(employerID: employerID);
      _isLoadingUser = false;
      notifyListeners();
    } else {
      final userService = UserService();
      final token = AuthService.accessToken;
      final idUser = AuthService.userId;

      if (token != null && idUser != null) {
        _usuario = (await userService.fetchUser(token, idUser))!;
        _saveUserToPrefs(_usuario);
      } else {
        _usuario = Usuario(
          fullName: 'ERRO GET USER',
          email: 'ERRO GET USER',
          profileID: 'ERRO GET ID',
        );
      }

      _isLoadingUser = false;
      notifyListeners();
    }
  }

  Future<void> _saveUserToPrefs(Usuario usuario) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userFullName', usuario.fullName);
    await prefs.setString('userEmail', usuario.email);
  }

  DateTime? lastPontoTime;

  File? get image => _image;
  DateTime get now => _now;
  Usuario get usuario => _usuario;
  bool get isLoadingImage => _isLoadingImage;
  bool get isLoadingUser =>
      _isLoadingUser; // Getter para o estado de carregamento do usuário

  Future<void> pickImage(BuildContext context) async {
    _isLoadingImage = true;
    notifyListeners();

    File? pickedImage = await _imageSelectController.pickImage(context);

    if (pickedImage != null) {
      _image = pickedImage;
    }

    _isLoadingImage = false;
    notifyListeners();
  }

  void registrarPonto(int index, BuildContext context) {
    if (pontos.where((element) => element != null).length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você já marcou os 4 pontos hoje.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (pontos[index] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este ponto já foi marcado.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (lastPontoTime != null &&
        now.difference(lastPontoTime!).inMinutes < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Você precisa esperar pelo menos 10 minutos para marcar o próximo ponto.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    pontos[index] = DateTime.now();
    lastPontoTime = now;
    notifyListeners();

    _savePointsLocally();
  }

  bool pontoExpiry() {
    final validadePonto = _expiryDate?.isAfter(DateTime.now()) ?? false;
    return validadePonto;
  }

  void limparPontos() {
    pontos = List.filled(4, null);
    _savePointsLocally();
    notifyListeners();
  }

  Future<void> _savePointsLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> pontosJson = pontos
        .map((point) => point != null ? point.toIso8601String() : '')
        .toList();
    await prefs.setStringList('pontos', pontosJson);
  }

  Future<void> _loadPointsLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? pontosJson = prefs.getStringList('pontos');
    pontos = pontosJson
            ?.map((point) => point.isNotEmpty ? DateTime.parse(point) : null)
            .toList() ??
        List.filled(4, null);
    notifyListeners();
  }

  Future<bool> checkApiAvailability() async {
    try {
      final response = await http.get(Uri.parse(ApiPontoService.baseUrl));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (e) {
      print('Exception checking API availability: $e');
    }
    return false;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

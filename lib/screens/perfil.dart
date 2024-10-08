import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:ponto/Service/auth_Login_Service.dart';
import 'package:ponto/Service/auth_user_Service.dart';
import 'package:ponto/controller/image_select.dart';
import 'package:ponto/model/usuario.dart';
import 'package:ponto/utils/navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({Key? key}) : super(key: key);

  @override
  PerfilPageState createState() => PerfilPageState();
}

class PerfilPageState extends State<PerfilPage> {
  File? image;
  late ImageSelectController _imageSelectController;
  ImageProvider? _imageProvider;
  bool _isLoading = true;
  static bool isValidVoltar = false;
  late Usuario _usuario = Usuario(
    fullName: '',
    email: '',
    profileID: '',
  );

  @override
  void initState() {
    super.initState();
    _imageSelectController = ImageSelectController();
    _initImage();
    _initUsuario();
  }
//inicia a imagem setada ou nao pelo usuario. Caso ja exista o SharedPreferences ira obtela. 
  Future<void> _initImage() async {
    await _imageSelectController.initSharedPreferences();
    File? savedImage = await _imageSelectController.getSavedImage();
    if (savedImage != null) {
      setState(() {
        image = savedImage;
        _imageProvider = FileImage(savedImage);
        _isLoading = false;
      });
    } else {
      setState(() {
        _imageProvider =
            const AssetImage("lib/assets/image/defaultprofile.png");
        _isLoading = false;
      });
    }
  }
// iniciar um usuario logado.
  Future<void> _initUsuario() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? fullName = prefs.getString('userFullName');
    String? email = prefs.getString('userEmail');
    String? profileID = prefs.getString('profileid');
   

    if (fullName != null && email != null && profileID != null) {
      setState(() {
        _usuario = Usuario(
          fullName: fullName,
          email: email,
          profileID: profileID,
        );
        _isLoading = false;
      });
    } else {
      final userService = UserService();
      final token = AuthService.accessToken;
      final idUser = AuthService.userId;

      if (token != null && idUser != null) {
        Usuario? usuario = await userService.fetchUser(token, idUser);
        if (usuario != null) {
          setState(() {
            _usuario = usuario;
            _isLoading = false;
          });
          await _saveUserToPrefs(usuario);
        } else {
          setState(() {
            _usuario = Usuario(
              fullName: 'ERRO GET USER',
              email: 'ERRO GET USER',
              profileID: 'ERRO GET ID',
            );
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _usuario = Usuario(
            fullName: 'ERRO GET USER',
            email: 'ERRO GET USER',
            profileID: 'ERRO GET ID',
          );
          _isLoading = false;
        });
      }
    }
  }
//salvar perfil usuario
  Future<void> _saveUserToPrefs(Usuario usuario) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userFullName', usuario.fullName);
    await prefs.setString('userEmail', usuario.email);
    await prefs.setString('profileid', usuario.profileID);
  }

  @override
  Widget build(BuildContext context) {
    final double widthbox = MediaQuery.of(context).size.width * 0.9;
    final double fontSizeall = MediaQuery.of(context).size.width * 0.04;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 57, 146, 247),
                    Color.fromARGB(255, 0, 191, 99),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),boxShadow: [
                     BoxShadow(
                      color: Color.fromARGB(96, 52, 52, 52),
                      
                      blurRadius: 5,
                    ),
                  ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.1,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: GestureDetector(
                      onTap: () async {
                        File? pickedImage =
                            await _imageSelectController.pickImage(context);
            
                        if (pickedImage != null) {
                          setState(() {
                            image = pickedImage;
                            _imageProvider = FileImage(pickedImage);
                          });
                        }
                      },
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : CircleAvatar(
                              key: UniqueKey(),
                              radius: 75,
                              backgroundColor: Colors.transparent,
                              backgroundImage: _imageProvider,
                              foregroundColor:
                                  const Color.fromARGB(0, 255, 255, 255),
                            ),
                    ),
                  ),// lista de todas as informacoes do usuario
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _isLoading? Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        "lib/assets/image/logo.png",
                        fit: BoxFit.cover,
                        height: 50,
                        width: 50,
                      ),
                      const SizedBox(
                        width: 70,
                        height: 70,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 0, 191, 99)),
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ) :ListView.separated(
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile( 
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoText('Nome', _usuario.fullName),
                              _buildInfoText('Email', _usuario.email),
                            ],
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(20),
                      separatorBuilder: (_, __) => const Divider(),
                      itemCount: 1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.03,
            ),
            if (PerfilPageState.isValidVoltar)
              Container(
                width: widthbox,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 0, 191, 99),
                  border: Border.all(
                    color: Color.fromARGB(255, 0, 191, 99),
                    width: 0.1,
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(20),
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      PerfilPageState.isValidVoltar = false;
                    });
                    Get.to(NavigatorBarMenu()); // Voltar à tela anterior
                  },
                  child: Text(
                    'Voltar',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: fontSizeall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fade(duration: const Duration(milliseconds: 400));
  }
// biuld listview
  Widget _buildInfoText(String label, String value) {
    double fontSizeall = MediaQuery.of(context).size.width * 0.045;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text('$label: $value',
            style: TextStyle(fontSize: fontSizeall, color: Colors.white)),
        const Divider(),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Certifique-se que este arquivo existe (gerado pelo flutterfire configure)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TaninoWineApp());
}

class TaninoWineApp extends StatelessWidget {
  const TaninoWineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaninoWine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF800020),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF800020), 
          brightness: Brightness.dark,
          primary: const Color(0xFF800020)
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

// ==========================================
// SERVIÇO DE SESSÃO
// ==========================================
class SessionService {
  static bool isAdmin = false; 
}

// ==========================================
// SERVIÇO DE VINHOS (FIREBASE + LOGICA LOCAL)
// ==========================================
class WineService {
  // Conexão com a coleção 'wines' no Firestore
  static final CollectionReference winesCollection = FirebaseFirestore.instance.collection('wines');

  static Future<void> addWine(Map<String, dynamic> newWine) async {
    newWine['reviews'] = []; // Garante lista vazia
    await winesCollection.add(newWine);
  }

  static Future<void> removeWine(String docId) async {
    await winesCollection.doc(docId).delete();
  }

  static Future<void> addReview(String docId, Map<String, dynamic> review) async {
    await winesCollection.doc(docId).update({
      'reviews': FieldValue.arrayUnion([review])
    });
  }

  // Mapa de Bandeiras Inteligente
  static final Map<String, String> _flagMap = {
    "brasil": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Flag_of_Brazil.svg/256px-Flag_of_Brazil.svg.png",
    "brazil": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Flag_of_Brazil.svg/256px-Flag_of_Brazil.svg.png",
    "portugal": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Flag_of_Portugal.svg/255px-Flag_of_Portugal.svg.png",
    "argentina": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Flag_of_Argentina.svg/200px-Flag_of_Argentina.svg.png",
    "chile": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Flag_of_Chile.svg/256px-Flag_of_Chile.svg.png",
    "eua": "https://upload.wikimedia.org/wikipedia/en/thumb/a/a4/Flag_of_the_United_States.svg/256px-Flag_of_the_United_States.svg.png",
    "usa": "https://upload.wikimedia.org/wikipedia/en/thumb/a/a4/Flag_of_the_United_States.svg/256px-Flag_of_the_United_States.svg.png",
    "frança": "https://upload.wikimedia.org/wikipedia/en/thumb/c/c3/Flag_of_France.svg/250px-Flag_of_France.svg.png",
    "france": "https://upload.wikimedia.org/wikipedia/en/thumb/c/c3/Flag_of_France.svg/250px-Flag_of_France.svg.png",
    "itália": "https://upload.wikimedia.org/wikipedia/en/thumb/0/03/Flag_of_Italy.svg/255px-Flag_of_Italy.svg.png",
    "italy": "https://upload.wikimedia.org/wikipedia/en/thumb/0/03/Flag_of_Italy.svg/255px-Flag_of_Italy.svg.png",
    "espanha": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Spain.svg/256px-Flag_of_Spain.svg.png",
  };

  static String getFlagUrl(String countryName) {
    String key = countryName.toLowerCase().trim();
    return _flagMap[key] ?? "https://cdn-icons-png.flaticon.com/512/921/921490.png";
  }
}

// ==========================================
// SERVIÇO DE CARRINHO (AGORA SALVA PEDIDOS NA NUVEM ☁️)
// ==========================================
class CartService {
  static List<Map<String, dynamic>> items = [];

  static void addItem(Map<String, dynamic> wine) {
    final index = items.indexWhere((element) => element['name'] == wine['name']);
    if (index >= 0) {
      items[index]['qty']++;
    } else {
      // Criamos uma cópia limpa dos dados para salvar no pedido
      Map<String, dynamic> newItem = {
        'name': wine['name'],
        'price': wine['price'],
        'image': wine['image'],
        'qty': 1
      };
      items.add(newItem);
    }
  }

  static void removeItem(Map<String, dynamic> item) {
    if (item['qty'] > 1) {
      item['qty']--;
    } else {
      items.remove(item);
    }
  }

  static double getTotal() {
    double total = 0;
    for (var item in items) {
      String priceString = item['price'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (priceString.isNotEmpty) {
        total += double.parse(priceString) * item['qty'];
      }
    }
    return total;
  }

  static void clearCart() {
    items.clear();
  }

  // --- NOVA FUNÇÃO: SALVAR PEDIDO NO FIREBASE ---
  static Future<void> saveOrder() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || items.isEmpty) return;

    await FirebaseFirestore.instance.collection('orders').add({
      'userId': user.uid, // Para sabermos de quem é o pedido
      'userEmail': user.email,
      'total': getTotal(),
      'date': FieldValue.serverTimestamp(), // Hora exata do servidor
      'status': 'Em preparação', // Status inicial
      'items': items, // A lista de vinhos
    });
    
    clearCart(); // Limpa o carrinho DEPOIS de salvar
  }
}

// ==========================================
// TELA 1: WELCOME SCREEN
// ==========================================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_welcome.jpg'), fit: BoxFit.cover)), child: Container(color: Colors.black.withOpacity(0.4))),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(flex: 2),
                RichText(text: TextSpan(style: GoogleFonts.montserrat(fontSize: 45, color: Colors.white), children: [TextSpan(text: 'Tanino', style: const TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)), const TextSpan(text: 'Wine', style: TextStyle(fontWeight: FontWeight.w300))])),
                const Spacer(flex: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.9)])),
                  child: Column(
                    children: [
                      Text("Crie ou acesse sua conta:", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [_SocialButton(icon: FontAwesomeIcons.google, color: Colors.white, iconColor: Colors.red), const SizedBox(width: 20), _SocialButton(icon: FontAwesomeIcons.facebookF, color: const Color(0xFF3b5998), iconColor: Colors.white), const SizedBox(width: 20), _SocialButton(icon: Icons.email, color: const Color(0xFF800020), iconColor: Colors.white, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())))]),
                      const SizedBox(height: 30),
                      SizedBox(width: double.infinity, height: 50, child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), backgroundColor: Colors.white.withOpacity(0.05)), child: Text("CRIAR MINHA CONTA", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                      const SizedBox(height: 15),
                      TextButton(onPressed: () {
                         SessionService.isAdmin = false;
                         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CatalogScreen()), (route) => false);
                      }, child: Text("Entrar como visitante", style: GoogleFonts.poppins(color: Colors.white70, decoration: TextDecoration.underline, decorationColor: Colors.white70)))
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// TELA 2: LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _doLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _userController.text.trim(), password: _passController.text.trim());
      // Admin check
      if (_userController.text.trim() == "luffy@tanino.com") {
        SessionService.isAdmin = true;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bem-vindo, Chefe Luffy! 🍷"), backgroundColor: Color(0xFF800020)));
      } else {
        SessionService.isAdmin = false;
      }
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CatalogScreen()), (route) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Erro ao logar"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, resizeToAvoidBottomInset: false,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
      body: Stack(
        children: [
          Container(height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_login.jpg'), fit: BoxFit.cover)), child: Container(color: Colors.black.withOpacity(0.5))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 25),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.2))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Login", style: GoogleFonts.greatVibes(fontSize: 55, color: Colors.white)),
                        const SizedBox(height: 5), Text("Faça login para acessar o catálogo", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 40),
                        _GlassInput(label: "E-mail", controller: _userController, icon: Icons.email_outlined), const SizedBox(height: 20),
                        _GlassInput(label: "Senha", isPassword: true, controller: _passController), const SizedBox(height: 30),
                        SizedBox(width: double.infinity, height: 55, child: OutlinedButton(onPressed: _isLoading ? null : _doLogin, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("ENTRAR", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
                        const SizedBox(height: 20), Text("Esqueci minha Senha.", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, decoration: TextDecoration.underline)),
                        const SizedBox(height: 10), GestureDetector(onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignupScreen())), child: Text("Criar conta", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TELA 3: SIGNUP SCREEN
// ==========================================
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _agreedToTerms = false;
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: DateTime(2005), firstDate: DateTime(1900), lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF800020), onPrimary: Colors.white, surface: Color(0xFF2C2C2C)), dialogBackgroundColor: const Color(0xFF1E1E1E)), child: child!);
      }
    );
    if (picked != null) {
      setState(() {
        String day = picked.day.toString().padLeft(2, '0');
        String month = picked.month.toString().padLeft(2, '0');
        _dobController.text = "$day/$month/${picked.year}";
      });
    }
  }

  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _dobController.text.isEmpty || _passController.text.isEmpty) return;
    if (_passController.text != _confirmPassController.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senhas não conferem"))); return; }
    if (!_agreedToTerms) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aceite os termos"))); return; }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passController.text.trim());
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      if (_emailController.text.trim() == "luffy@tanino.com") SessionService.isAdmin = true; else SessionService.isAdmin = false;
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CatalogScreen()), (route) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Erro ao cadastrar"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
      body: Stack(
        children: [
          Container(height: MediaQuery.of(context).size.height, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_signup.jpg'), fit: BoxFit.cover)), child: Container(color: Colors.black.withOpacity(0.7))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80),
              child: ClipRRect(borderRadius: BorderRadius.circular(25), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.2))), child: Column(children: [Text("Criar conta", style: GoogleFonts.greatVibes(fontSize: 45, color: Colors.white)), const SizedBox(height: 30), _GlassInput(label: "Nome Completo", controller: _nameController), const SizedBox(height: 15), _GlassInput(label: "Data de Nascimento", icon: Icons.calendar_today, controller: _dobController, readOnly: true, onTap: () => _selectDate(context)), const SizedBox(height: 15), _GlassInput(label: "E-mail", controller: _emailController, icon: Icons.email_outlined), const SizedBox(height: 15), _GlassInput(label: "Senha", isPassword: true, controller: _passController), const SizedBox(height: 15), _GlassInput(label: "Confirmar Senha", isPassword: true, controller: _confirmPassController), const SizedBox(height: 20), Row(children: [Theme(data: ThemeData(unselectedWidgetColor: Colors.white70), child: Checkbox(value: _agreedToTerms, activeColor: const Color(0xFF800020), onChanged: (bool? value) { setState(() { _agreedToTerms = value ?? false; }); })), Expanded(child: Text("Li e concordo que sou maior de 18 anos e aceito os termos de uso.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70))) ]), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _handleSignup, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("REGISTRAR-SE", style: GoogleFonts.poppins(color: Colors.white70))))])))),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TELA 4: CATALOG SCREEN (VERSÃO FINAL COM MODAL DE FILTROS)
// ==========================================

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  // 1. Variáveis de Estado
  String searchQuery = "";
  String _selectedCategory = "Todos";
  String _selectedGrape = "Todas";   // Variável de Uva
  String _selectedCountry = "Todos"; // Variável de País

  // --- LISTAS DE OPÇÕES ---
  final List<String> _grapeOptions = [
    "Todas", "Cabernet Sauvignon", "Merlot", "Malbec", 
    "Pinot Noir", "Chardonnay", "Sauvignon Blanc", "Syrah", "Carménère", "Tannat"
  ];

  final List<String> _countryOptions = [
    "Todos", "Brasil", "Argentina", "Chile", 
    "França", "Itália", "Portugal", "Espanha", "EUA"
  ];

  // --- FUNÇÃO DO MODAL DE FILTROS (A "Aba" que abre) ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true, // Permite ocupar mais espaço se precisar
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        // StatefulBuilder é necessário para os Dropdowns mudarem visualmente dentro do Modal
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(context).viewInsets.bottom + 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Filtrar Vinhos", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          // Limpar Filtros
                          setModalState(() {
                             _selectedCategory = "Todos";
                             _selectedGrape = "Todas";
                             _selectedCountry = "Todos";
                          });
                        }, 
                        child: const Text("Limpar", style: TextStyle(color: Colors.white54))
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. SELEÇÃO DE CATEGORIA (Chips)
                  Text("Categoria (Tipo)", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 14)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ["Todos", "Tinto", "Branco", "Rosé", "Espumante"].map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF800020),
                            backgroundColor: Colors.white10,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                            onSelected: (selected) {
                              setModalState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. SELEÇÃO DE UVA (Dropdown)
                  Text("Uva", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 14)),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                    child: DropdownButton<String>(
                      value: _selectedGrape,
                      dropdownColor: const Color(0xFF2C2C2C),
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                      style: const TextStyle(color: Colors.white),
                      items: _grapeOptions.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => setModalState(() => _selectedGrape = newValue!),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. SELEÇÃO DE PAÍS (Dropdown)
                  Text("País de Origem", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 14)),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                    child: DropdownButton<String>(
                      value: _selectedCountry,
                      dropdownColor: const Color(0xFF2C2C2C),
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                      style: const TextStyle(color: Colors.white),
                      items: _countryOptions.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => setModalState(() => _selectedCountry = newValue!),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // BOTÃO APLICAR
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber, 
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      onPressed: () {
                        setState(() {}); // Atualiza a tela principal com os novos filtros
                        Navigator.pop(context); // Fecha o modal
                      },
                      child: const Text("APLICAR FILTROS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteWine(String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Excluir Vinho?", style: GoogleFonts.poppins(color: Colors.white)),
        content: Text("Excluir $name do catálogo permanentemente?", style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              WineService.removeWine(docId); 
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vinho removido do Banco de Dados!")));
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // --- APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("TaninoWine", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w300)),
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => Scaffold.of(context).openDrawer())),
        actions: [
          // ÍCONE DE FILTRO (NOVO)
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.amber), // Ícone de sliders
            tooltip: "Filtrar",
            onPressed: _showFilterModal, // Abre a aba de filtros
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
            ),
          )
        ],
      ),
      // --- DRAWER ---
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF800020)),
            child: Center(child: Text("Menu", style: GoogleFonts.greatVibes(fontSize: 30, color: Colors.white))),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.person, color: Colors.white, size: 28),
            title: Text("Minha Conta", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("Ver perfil e histórico", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          const Divider(color: Colors.white24, height: 30),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                hintText: "Pesquisar nome...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          )
        ]),
      ),
      // --- CORPO DA TELA ---
      body: Stack(
        children: [
          Container(height: MediaQuery.of(context).size.height, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_home.jpg'), fit: BoxFit.cover, opacity: 0.3))),
          Column(
            children: [
              // BARRA DE FILTROS ATIVOS (Aparece só se filtrar algo)
              if(_selectedCategory != "Todos" || _selectedGrape != "Todas" || _selectedCountry != "Todos")
                Container(
                  width: double.infinity,
                  color: const Color(0xFF800020).withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "$_selectedCategory • $_selectedGrape • $_selectedCountry",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                           _selectedCategory = "Todos"; _selectedGrape = "Todas"; _selectedCountry = "Todos";
                        }),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      )
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Destaques da Adega", style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                    if (SessionService.isAdmin)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)), child: const Text("MODO ADMIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)))
                  ],
                ),
              ),
              
              // LISTAGEM COM FILTROS AVANÇADOS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: WineService.winesCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Erro ao carregar", style: TextStyle(color: Colors.white)));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF800020)));

                    final data = snapshot.requireData;
                    
                    final wines = data.docs.where((doc) {
                      final wineData = doc.data() as Map<String, dynamic>;
                      
                      // 1. Filtro de Nome (Busca)
                      final matchesName = wineData['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
                      
                      // 2. Filtro de Categoria
                      final matchesCategory = _selectedCategory == "Todos" || (wineData['type'] ?? "").toString() == _selectedCategory;

                      // 3. Filtro de Uva (Verifica campo 'grapes' no banco)
                      final matchesGrape = _selectedGrape == "Todas" || ((wineData['grapes'] ?? wineData['grape'] ?? "")).toString() == _selectedGrape;

                      // 4. Filtro de País (Verifica dentro de 'origin')
                      final matchesCountry = _selectedCountry == "Todos" || (wineData['origin'] ?? "").toString().contains(_selectedCountry);

                      return matchesName && matchesCategory && matchesGrape && matchesCountry;
                    }).toList();

                    if (wines.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.filter_list_off, size: 50, color: Colors.white54),
                            const SizedBox(height: 10),
                            Text("Nenhum vinho encontrado.", style: GoogleFonts.poppins(color: Colors.white54)),
                            TextButton(
                              onPressed: (){ 
                                setState(() { _selectedCategory="Todos"; _selectedGrape="Todas"; _selectedCountry="Todos"; }); 
                              }, 
                              child: const Text("Limpar Filtros", style: TextStyle(color: Colors.amber))
                            )
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 100),
                      itemCount: wines.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, 
                        childAspectRatio: 0.60, 
                        crossAxisSpacing: 15, 
                        mainAxisSpacing: 15
                      ),
                      itemBuilder: (context, index) {
                        final doc = wines[index];
                        final wine = doc.data() as Map<String, dynamic>;
                        wine['id'] = doc.id;
                        
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(wine: wine))),
                              child: _WineCard(wine: wine)
                            ),
                            if (SessionService.isAdmin)
                              Positioned(
                                top: 5, right: 5, 
                                child: GestureDetector(
                                  onTap: () => _deleteWine(doc.id, wine['name']),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.delete, size: 16, color: Colors.white)
                                  )
                                )
                              )
                          ]
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (SessionService.isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: FloatingActionButton.extended(
                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAddWineScreen())); },
                backgroundColor: Colors.amber,
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text("Adicionar Vinho", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
              )
            ),
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
              border: Border.all(color: Colors.white10)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.home, color: Colors.white, size: 28),
                Container(width: 1, height: 25, color: Colors.white24),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                  child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28)
                )
              ]
            )
          ),
        ],
      ),
    );
  }
}

// O CARD DE VINHO (Pode manter o mesmo, mas incluí aqui para garantir que não falta nada)
class _WineCard extends StatelessWidget {
  final Map<String, dynamic> wine;
  const _WineCard({required this.wine});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Hero(
                tag: wine['name'],
                child: Image.network(wine['image'], fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.wine_bar, size: 50, color: Colors.grey))
              )
            )
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wine['name'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text("${wine['origin']} • ${wine['year']}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11))
                    ]
                  ),
                  Text(wine['price'], style: GoogleFonts.poppins(color: Colors.amber[700], fontWeight: FontWeight.bold, fontSize: 16))
                ]
              )
            )
          )
        ]
      ),
    );
  }
}

// ==========================================
// TELA NOVA: ADMIN ADD WINE (COM CAMPO DE UVA)
// ==========================================
class AdminAddWineScreen extends StatefulWidget {
  const AdminAddWineScreen({super.key});
  @override
  State<AdminAddWineScreen> createState() => _AdminAddWineScreenState();
}

class _AdminAddWineScreenState extends State<AdminAddWineScreen> {
  final _nameCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _grapeCtrl = TextEditingController(); // Novo Controlador para Uva
  bool _isLoading = false;
  
  Future<void> _saveWine() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nome e Preço são obrigatórios!")));
      return;
    }
    setState(() => _isLoading = true);

    String origin = _originCtrl.text.isEmpty ? "Desconhecido" : _originCtrl.text;
    String flagUrl = WineService.getFlagUrl(origin);

    Map<String, dynamic> newWine = {
      "name": _nameCtrl.text,
      "origin": origin,
      "year": _yearCtrl.text.isEmpty ? "NV" : _yearCtrl.text,
      "price": "R\$ ${_priceCtrl.text}",
      "image": _imageCtrl.text.isEmpty ? "https://cdn-icons-png.flaticon.com/512/2405/2405451.png" : _imageCtrl.text,
      "flag": flagUrl,
      "type": "Tinto",
      "grapes": _grapeCtrl.text.isEmpty ? "Variadas" : _grapeCtrl.text,
      "desc": _descCtrl.text.isEmpty ? "Sem descrição." : _descCtrl.text,
    };

    await WineService.addWine(newWine);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vinho salvo na nuvem! ☁️"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Adicionar Vinho"), backgroundColor: const Color(0xFF1E1E1E)),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.add_business, size: 50, color: Colors.amber),
            const SizedBox(height: 20), Text("Novo Produto (Nuvem)", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            _GlassInput(label: "Nome do Vinho", controller: _nameCtrl), const SizedBox(height: 15),
            _GlassInput(label: "Preço (Ex: 150.00)", controller: _priceCtrl, keyboardType: TextInputType.number), const SizedBox(height: 15),
            Row(children: [Expanded(child: _GlassInput(label: "Ano", controller: _yearCtrl, keyboardType: TextInputType.number)), const SizedBox(width: 15), Expanded(child: _GlassInput(label: "País (Ex: Brasil, França)", controller: _originCtrl))]), const SizedBox(height: 15),
            _GlassInput(label: "Tipo de Uva (Ex: Malbec, Merlot)", controller: _grapeCtrl), const SizedBox(height: 15),
            _GlassInput(label: "URL da Imagem (Link)", controller: _imageCtrl, icon: Icons.link), const SizedBox(height: 15),
            Container(height: 100, decoration: BoxDecoration(color: const Color(0xFF1E1E1E).withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: TextField(controller: _descCtrl, maxLines: 5, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Descrição do vinho...", hintStyle: GoogleFonts.greatVibes(color: Colors.white54, fontSize: 22), border: InputBorder.none, contentPadding: const EdgeInsets.all(15)))),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isLoading ? null : _saveWine, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text("SALVAR NO CATÁLOGO", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold))))
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TELA 5: PRODUCT DETAIL
// ==========================================
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> wine;
  const ProductDetailScreen({super.key, required this.wine});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Stream<DocumentSnapshot>? _wineStream;

  @override
  void initState() {
    super.initState();
    if (widget.wine['id'] != null) {
      _wineStream = WineService.winesCollection.doc(widget.wine['id']).snapshots();
    }
  }

  void _openWriteReview() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _ReviewInputModal(onSubmit: (int stars, String comment) async {
        if (widget.wine['id'] != null) {
          await WineService.addReview(widget.wine['id'], {
            "name": "Você", "stars": stars, "comment": comment, "date": "Agora mesmo"
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avaliação enviada!"), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Vinho não sincronizado."), backgroundColor: Colors.red));
        }
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _wineStream,
      builder: (context, snapshot) {
        Map<String, dynamic> currentData = widget.wine;
        if (snapshot.hasData && snapshot.data!.exists) {
          currentData = snapshot.data!.data() as Map<String, dynamic>;
        }
        List<dynamic> reviews = currentData['reviews'] ?? [];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)), centerTitle: true, title: Text("TaninoWine", style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.w300)), actions: [IconButton(icon: const Icon(Icons.shopping_cart, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())))]),
          body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: Column(children: [Expanded(flex: 5, child: Stack(children: [Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Hero(tag: widget.wine['name'], child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.amber, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]), child: Image.network(currentData['image'], fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.wine_bar, size: 100)))))), Positioned(right: 20, top: 20, child: Column(children: [_InfoBadge(image: currentData['flag']?.toString(), label: currentData['origin'].toString()), const SizedBox(height: 15), const _InfoBadge(icon: Icons.wine_bar, label: "Tinto", color: Colors.purple), const SizedBox(height: 15), _InfoBadge(icon: Icons.grain, label: currentData['grapes']?.toString() ?? "Uvas", color: Colors.grey), const SizedBox(height: 15), const _InfoBadge(icon: Icons.local_drink, label: "750ml", color: Colors.black)]))])), Expanded(flex: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 25), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentData['name'], style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black, shadows: [Shadow(color: Colors.black38, offset: const Offset(2, 2), blurRadius: 4)])), const SizedBox(height: 15), Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), border: Border.all(color: Colors.grey.shade400, width: 1.5), borderRadius: BorderRadius.circular(15)), child: Text(currentData['desc'], textAlign: TextAlign.justify, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800], height: 1.6))), const SizedBox(height: 30), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Avaliações (${reviews.length})", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), GestureDetector(onTap: _openWriteReview, child: Text("+ Avaliar", style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF800020), fontWeight: FontWeight.bold)))]), const SizedBox(height: 15), if (reviews.isEmpty) Padding(padding: const EdgeInsets.all(20.0), child: Center(child: Text("Seja o primeiro a avaliar!", style: GoogleFonts.poppins(color: Colors.grey)))) else ...reviews.map((rev) => _ReviewCard(name: rev['name'] ?? "Anônimo", stars: rev['stars'] ?? 5, comment: rev['comment'] ?? "", date: rev['date'] ?? "")).toList(), const SizedBox(height: 30)])))), Container(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)), child: Text(currentData['price'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))), const SizedBox(width: 15), Expanded(child: OutlinedButton.icon(onPressed: () { CartService.addItem(currentData); ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF800020), content: Text("${currentData['name']} adicionado!", style: GoogleFonts.poppins(color: Colors.white)), duration: const Duration(seconds: 1))); }, icon: const Icon(Icons.add, color: Colors.black), label: const Icon(Icons.shopping_cart_outlined, color: Colors.black), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.black, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))))])) ]))),
        );
      },
    );
  }
}

class _ReviewInputModal extends StatefulWidget {
  final Function(int, String) onSubmit;
  const _ReviewInputModal({required this.onSubmit});
  @override
  State<_ReviewInputModal> createState() => _ReviewInputModalState();
}
class _ReviewInputModalState extends State<_ReviewInputModal> {
  int _rating = 5;
  final TextEditingController _commentCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Container(padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20), decoration: const BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.vertical(top: Radius.circular(25))), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 20), Text("O que achou do vinho?", style: GoogleFonts.greatVibes(fontSize: 30, color: Colors.white)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) { return IconButton(onPressed: () => setState(() => _rating = index + 1), icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 35)); })), const SizedBox(height: 20), Container(padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: TextField(controller: _commentCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Escreva sua opinião...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none))), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { if (_commentCtrl.text.isNotEmpty) { widget.onSubmit(_rating, _commentCtrl.text); } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)), child: const Text("ENVIAR AVALIAÇÃO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))]));
  }
}
class _ReviewCard extends StatelessWidget {
  final String name; final int stars; final String comment; final String date;
  const _ReviewCard({required this.name, required this.stars, required this.comment, required this.date});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)), Text(date, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10))]), const SizedBox(height: 5), Row(children: List.generate(5, (index) => Icon(index < stars ? Icons.star : Icons.star_border, size: 16, color: Colors.amber))), const SizedBox(height: 8), Text(comment, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87))]));
  }
}

// ==========================================
// TELA 9: PERFIL (HISTÓRICO REAL DO FIREBASE)
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String userName = user?.displayName ?? "Visitante";
    final String userEmail = user?.email ?? "sem email";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)), title: Text("Meu Perfil", style: GoogleFonts.greatVibes(fontSize: 30, color: Colors.white)), centerTitle: true),
      body: Stack(
        children: [
          Container(height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_home.jpg'), fit: BoxFit.cover)), child: Container(color: Colors.black.withOpacity(0.8))),
          
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
            child: Column(
              children: [
                // Avatar
                Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: CircleAvatar(radius: 60, backgroundImage: NetworkImage(SessionService.isAdmin ? "https://i.pinimg.com/736x/ea/58/13/ea58133bb7a0497fa97607730d47343e.jpg" : "https://cdn-icons-png.flaticon.com/512/3135/3135715.png"))),
                const SizedBox(height: 15),
                Text(userName, style: GoogleFonts.poppins(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                Text(userEmail, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54)),
                
                const SizedBox(height: 40),
                Align(alignment: Alignment.centerLeft, child: Text("Meus Pedidos", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
                const SizedBox(height: 15),

                // LISTA DE PEDIDOS DO FIREBASE
                if (user == null)
                  const Text("Faça login para ver seus pedidos.", style: TextStyle(color: Colors.white54))
                else
                  StreamBuilder<QuerySnapshot>(
                    // Busca pedidos onde userId é igual ao meu ID, ordenado por data (descendente)
                    stream: FirebaseFirestore.instance.collection('orders')
                        .where('userId', isEqualTo: user.uid)
                        // .orderBy('date', descending: true) // Nota: Requer índice no Firebase, vamos deixar simples por enquanto
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: Color(0xFF800020));
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("Você ainda não fez pedidos.", style: TextStyle(color: Colors.white54));

                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final items = data['items'] as List<dynamic>;
                          final firstItem = items[0]; // Pega o primeiro item para mostrar na capa
                          final total = (data['total'] as num).toDouble();
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                            child: Row(
                              children: [
                                // Foto do primeiro vinho
                                Container(width: 50, height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Image.network(firstItem['image'], fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.wine_bar))),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text("${items.length} produto(s)", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text("Total: R\$ ${total.toStringAsFixed(2)}", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                    Text("Status: ${data['status']}", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 12)),
                                  ]),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14)
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// TELA 6: CARRINHO (CART SCREEN)
// ==========================================
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    double totalValue = CartService.getTotal();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
      ),
      body: Stack(
        children: [
          Container(height: MediaQuery.of(context).size.height, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_home.jpg'), fit: BoxFit.cover)), child: Container(color: Colors.black.withOpacity(0.7))),
          Column(
            children: [
              const SizedBox(height: 100),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(color: const Color(0xFF581C1C), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28), const SizedBox(width: 10), Text("Carrinho", style: GoogleFonts.greatVibes(fontSize: 35, color: Colors.white))]), Text("${CartService.items.length} Itens", style: GoogleFonts.poppins(color: Colors.white70))]),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: CartService.items.isEmpty 
                  ? Center(child: Text("Seu carrinho está vazio...", style: GoogleFonts.poppins(color: Colors.white54))) 
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: CartService.items.length,
                      itemBuilder: (context, index) { return _CartItem(item: CartService.items[index], onChanged: () => setState((){})); },
                    ),
              ),
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Valor Total:", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text("R\$ ${totalValue.toStringAsFixed(2)}", style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
                      onPressed: () {
                        if (CartService.items.isEmpty) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Carrinho vazio!")));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen()));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: Text("PAGAMENTO", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                    )),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final Map<String, dynamic> item; final VoidCallback onChanged;
  const _CartItem({required this.item, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(
        children: [
          Container(width: 70, height: 90, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Image.network(item['image'], fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.wine_bar))),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text(item['price'], style: GoogleFonts.poppins(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14))])),
          Column(children: [Row(children: [GestureDetector(onTap: () { CartService.removeItem(item); onChanged(); }, child: const Icon(Icons.remove_circle_outline, color: Colors.white70)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Text("${item['qty']}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))), GestureDetector(onTap: () { CartService.addItem(item); onChanged(); }, child: const Icon(Icons.add_circle_outline, color: Colors.white))])])
        ],
      ),
    );
  }
}

// ==========================================
// TELA 7: PAGAMENTO (COM SALVAMENTO REAL)
// ==========================================
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedMethod = 0;
  bool _isProcessing = false; // Para mostrar carregando

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white), centerTitle: true, title: Text("Formas de Pagamentos", style: GoogleFonts.greatVibes(fontSize: 35, color: Colors.white)), actions: [IconButton(onPressed: (){}, icon: const Icon(Icons.menu, color: Colors.white))]),
      body: Stack(
        children: [
          Container(height: MediaQuery.of(context).size.height, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_home.jpg'), fit: BoxFit.cover)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: Container(color: Colors.black.withOpacity(0.7)))),
          Column(children: [
            const SizedBox(height: 120), 
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [_PaymentOptionRow(icon: FontAwesomeIcons.solidCreditCard, label: "Cartão de Crédito/Débito", isSelected: _selectedMethod == 1, onTap: () => setState(() => _selectedMethod = 1)), const SizedBox(height: 15), _PaymentOptionRow(icon: FontAwesomeIcons.pix, label: "Pix", isSelected: _selectedMethod == 2, onTap: () => setState(() => _selectedMethod = 2)), const SizedBox(height: 15), _PaymentOptionRow(icon: FontAwesomeIcons.barcode, label: "Boleto", isSelected: _selectedMethod == 3, onTap: () => setState(() => _selectedMethod = 3))])), 
            
            // Botão de Confirmar
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2)))), child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
              // AÇÃO DE SALVAR
              onPressed: (_selectedMethod == 0 || _isProcessing) ? null : () async { 
                setState(() => _isProcessing = true);
                
                // Salva no Firebase
                await CartService.saveOrder();
                
                if (mounted) {
                  setState(() => _isProcessing = false);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderSuccessScreen())); 
                }
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020), disabledBackgroundColor: Colors.grey.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
              child: _isProcessing 
                ? const CircularProgressIndicator(color: Colors.white) 
                : Text("Confirmar método de pagamento", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
            )))))
          ])
        ],
      ),
    );
  }
}

// ==========================================
// TELA 8: SUCESSO DO PEDIDO
// ==========================================
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg_welcome.jpg'), fit: BoxFit.cover)), child: Container(color: Colors.black.withOpacity(0.3))),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(color: const Color(0xFFE8DCCA).withOpacity(0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black54)), child: const Icon(Icons.notifications_active_outlined, size: 40, color: Colors.black54)),
                        const SizedBox(height: 20),
                        Text("Seu Pedido será\nenviado o mais breve\npossível.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 25),
                        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFBCAAA4), borderRadius: BorderRadius.circular(20)), child: Column(children: [RichText(textAlign: TextAlign.center, text: TextSpan(style: GoogleFonts.poppins(color: const Color(0xFF3E2723), fontSize: 14), children: const [TextSpan(text: "Nosso Sistema já recebeu seu pedido e o mesmo está "), TextSpan(text: "em produção para sair para a entrega.", style: TextStyle(fontWeight: FontWeight.bold))])), const SizedBox(height: 15), Text("Obrigado pela preferência.", style: GoogleFonts.greatVibes(fontSize: 24, color: const Color(0xFF3E2723)))])),
                        const SizedBox(height: 25),
                        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { CartService.clearCart(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CatalogScreen()), (route) => false); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: Text("FINALIZAR", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)))),
                        const SizedBox(height: 15),
                        RichText(text: TextSpan(style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87), children: [TextSpan(text: 'Tanino', style: const TextStyle(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)), const TextSpan(text: 'Wine', style: TextStyle(fontWeight: FontWeight.w300))])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// WIDGETS AUXILIARES RESTANTES
// ==========================================
class _InfoBadge extends StatelessWidget {
  final String? image; final IconData? icon; final String label; final Color? color;
  const _InfoBadge({this.image, this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)), child: image != null ? ClipOval(child: Image.network(image!, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.public, color: Colors.grey))) : Icon(icon, color: color, size: 20)), const SizedBox(height: 4), Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w500), textAlign: TextAlign.center)]);
  }
}
class _GlassInput extends StatelessWidget {
  final String label;
  final bool isPassword;
  final IconData? icon;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextInputType keyboardType;

  // Removi o 'onChanged' daqui pois não estamos usando
  const _GlassInput({
    required this.label, 
    this.isPassword = false, 
    this.icon, 
    this.controller, 
    this.onTap, 
    this.readOnly = false, 
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.8), 
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(color: Colors.white24)
      ),
      child: TextField(
        controller: controller, 
        obscureText: isPassword, 
        readOnly: readOnly, 
        onTap: onTap, 
        keyboardType: keyboardType,
        // Removi a chamada do onChanged aqui também
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: label, 
          hintStyle: GoogleFonts.greatVibes(color: Colors.white54, fontSize: 22),
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          suffixIcon: icon != null 
            ? Icon(icon, size: 20, color: Colors.white54) 
            : (isPassword ? const Icon(Icons.percent, size: 18, color: Colors.white54) : null),
        ),
      ),
    );
  }
}
class _SocialButton extends StatelessWidget {
  final IconData icon; final Color color; final Color iconColor; final VoidCallback? onTap;
  const _SocialButton({required this.icon, required this.color, required this.iconColor, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(width: 55, height: 55, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Center(child: FaIcon(icon, color: iconColor, size: 26))));
  }
}
// Cole isso no final do arquivo main.dart, fora da última chave "}"

class _PaymentOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOptionRow({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFF722F37); 

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: activeColor, size: 20)
            else
              Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
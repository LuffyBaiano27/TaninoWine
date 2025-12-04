import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controladores de Texto
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  // Endereço
  final _cepCtrl = TextEditingController();
  final _addressCtrl = TextEditingController(); // Rua
  final _numberCtrl = TextEditingController();
  final _districtCtrl = TextEditingController(); // Bairro
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();

  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 1. CARREGAR DADOS DO FIREBASE ---
  Future<void> _loadUserData() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Dados Pessoais
        _nameCtrl.text = data['name'] ?? user!.displayName ?? "";
        _phoneCtrl.text = data['phone'] ?? "";
        
        // Endereço
        _cepCtrl.text = data['cep'] ?? "";
        _addressCtrl.text = data['address'] ?? "";
        _numberCtrl.text = data['number'] ?? "";
        _districtCtrl.text = data['district'] ?? "";
        _cityCtrl.text = data['city'] ?? "";
        _stateCtrl.text = data['state'] ?? "";
        _complementCtrl.text = data['complement'] ?? "";
      } else {
        // Se for o primeiro acesso, preenche o que der do Auth
        _nameCtrl.text = user!.displayName ?? "";
      }
    } catch (e) {
      print("Erro ao carregar perfil: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. SALVAR DADOS NO FIREBASE ---
  Future<void> _saveProfile() async {
    if (user == null) return;
    
    // Validação básica
    if (_nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _numberCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha Nome, Rua e Número!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Atualiza nome no Auth (para aparecer no Login/Home rapidinho)
      await user!.updateDisplayName(_nameCtrl.text);

      // Salva tudo no Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameCtrl.text,
        'email': user!.email,
        'phone': _phoneCtrl.text,
        // Objeto de Endereço Plano
        'cep': _cepCtrl.text,
        'address': _addressCtrl.text,
        'number': _numberCtrl.text,
        'district': _districtCtrl.text,
        'city': _cityCtrl.text,
        'state': _stateCtrl.text,
        'complement': _complementCtrl.text,
        // Campo facilitador para exibir em outras telas (ex: Detalhes do Pedido)
        'fullAddress': "${_addressCtrl.text}, ${_numberCtrl.text} - ${_districtCtrl.text}, ${_cityCtrl.text}/${_stateCtrl.text}"
      }, SetOptions(merge: true)); // Merge é vital para não apagar outros campos (como a futura foto)

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Endereço salvo com sucesso! 🚚"), 
          backgroundColor: Colors.green
        ));
        Navigator.pop(context);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Meu Endereço", style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Fundo
          Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/bg_home.jpg'), fit: BoxFit.cover),
            ),
            child: Container(color: Colors.black.withOpacity(0.85)), // Um pouco mais escuro para ler melhor
          ),
          
          if (_isLoading) 
            const Center(child: CircularProgressIndicator(color: Color(0xFF800020)))
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Icon(Icons.location_on_outlined, size: 50, color: Colors.amber)),
                  const SizedBox(height: 20),
                  
                  // Seção: Quem recebe
                  Text("Dados de Contato", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _EditInput(label: "Nome Completo", controller: _nameCtrl, icon: Icons.person),
                  const SizedBox(height: 10),
                  _EditInput(label: "Telefone / Celular", controller: _phoneCtrl, icon: Icons.phone, type: TextInputType.phone),

                  const SizedBox(height: 30),
                  
                  // Seção: Onde entrega
                  Text("Endereço de Entrega", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Expanded(flex: 2, child: _EditInput(label: "CEP", controller: _cepCtrl, icon: Icons.map, type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: _EditInput(label: "Cidade", controller: _cityCtrl)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _EditInput(label: "Bairro", controller: _districtCtrl)),
                      const SizedBox(width: 10),
                      Expanded(flex: 1, child: _EditInput(label: "UF", controller: _stateCtrl)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _EditInput(label: "Rua / Avenida", controller: _addressCtrl, icon: Icons.home)),
                      const SizedBox(width: 10),
                      Expanded(flex: 1, child: _EditInput(label: "Nº", controller: _numberCtrl, type: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _EditInput(label: "Complemento (Apto, Bloco...)", controller: _complementCtrl),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800020), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5
                      ),
                      child: Text("SALVAR ENDEREÇO", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Widget Local de Input (Estilo Vidro)
class _EditInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType type;

  const _EditInput({
    required this.label, 
    required this.controller, 
    this.icon, 
    this.type = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24)
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: Colors.white54, size: 20) : null,
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }
}
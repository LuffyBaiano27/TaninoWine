import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Agora sendo usado para formatar a data

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const OrderDetailsScreen({
    super.key, 
    required this.orderData, 
    required this.orderId
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  
  // Função para definir o índice do status atual (0 a 3)
  int _getStatusIndex(String status) {
    switch (status.toLowerCase()) {
      case 'aguardando pagamento': return 0;
      case 'preparando': return 1;
      case 'enviado': return 2;
      case 'entregue': return 3;
      default: return 0;
    }
  }

  // Modal de Avaliação
  void _showReviewModal() {
    // Usamos StatefulBuilder para atualizar as estrelas DENTRO do modal
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        // Variáveis locais do modal
        int localRating = 5; 
        TextEditingController commentController = TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(25, 25, 25, MediaQuery.of(context).viewInsets.bottom + 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Avaliar Pedido", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text("O que achou dos vinhos?", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 15),
                  
                  // Estrelas Interativas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setModalState(() {
                            localRating = index + 1; // Atualiza a nota ao clicar
                          });
                        },
                        icon: Icon(
                          index < localRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 35,
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 20),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Deixe um comentário...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020), padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () {
                        // Aqui você enviaria 'localRating' e 'commentController.text' para o Firebase
                        print("Nota enviada: $localRating"); 
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obrigado pela avaliação! 🍷")));
                      },
                      child: const Text("ENVIAR AVALIAÇÃO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status'] ?? 'Aguardando Pagamento';
    final currentStep = _getStatusIndex(status);
    final items = widget.orderData['items'] as List<dynamic>? ?? [];
    final total = (widget.orderData['total'] as num).toDouble(); // Garante double
    
    // CORREÇÃO DA DATA: Lógica para formatar a data vinda do Firebase
    String formattedDate = "Data desconhecida";
    if (widget.orderData['date'] != null) {
      final Timestamp timestamp = widget.orderData['date'];
      final DateTime dateTime = timestamp.toDate();
      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime); // Usa o pacote intl
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Detalhes do Pedido", style: GoogleFonts.poppins(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Pedido
            Text("Pedido #${widget.orderId.substring(0, 5).toUpperCase()}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
            // AQUI USAMOS A VARIÁVEL DATE QUE ESTAVA DANDO ERRO ANTES
            Text(formattedDate, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
            
            const SizedBox(height: 5),
            Text("Total: R\$ ${total.toStringAsFixed(2)}", style: GoogleFonts.poppins(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            // --- TIMELINE DE STATUS (STEPPER CUSTOMIZADO) ---
            _buildStatusTimeline(currentStep),
            const SizedBox(height: 40),

            // Lista de Produtos
            Text("Itens do Pedido", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      // Imagem Pequena
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
                        child: Image.network(item['image'] ?? '', fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.wine_bar)),
                      ),
                      const SizedBox(width: 15),
                      // Detalhes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text("${item['qty']}x  ${item['price']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- BOTÃO DE AVALIAR (SÓ SE ESTIVER ENTREGUE) ---
            if (currentStep == 3) ...[
               SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  onPressed: _showReviewModal,
                  icon: const Icon(Icons.star, color: Colors.black),
                  label: const Text("AVALIAR PEDIDO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Endereço e Infos
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.location_on, color: Colors.white54, size: 18), SizedBox(width: 10), Text("Endereço de Entrega", style: TextStyle(color: Colors.white54))]),
                  const SizedBox(height: 10),
                  Text(widget.orderData['address'] ?? "Endereço padrão do perfil", style: const TextStyle(color: Colors.white)),
                  const Divider(color: Colors.white10, height: 30),
                   const Row(children: [Icon(Icons.credit_card, color: Colors.white54, size: 18), SizedBox(width: 10), Text("Forma de Pagamento", style: TextStyle(color: Colors.white54))]),
                   const SizedBox(height: 10),
                   Text(widget.orderData['paymentMethod'] ?? "Cartão de Crédito", style: const TextStyle(color: Colors.white)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Widget Customizado da Timeline
  Widget _buildStatusTimeline(int currentStep) {
    final steps = [
      {'label': 'Aguardando', 'icon': Icons.access_time},
      {'label': 'Preparando', 'icon': Icons.inventory_2},
      {'label': 'Enviado', 'icon': Icons.local_shipping},
      {'label': 'Entregue', 'icon': Icons.check_circle},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isActive = index <= currentStep;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              // Ícone e Label
              Column(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF800020) : Colors.white10,
                      shape: BoxShape.circle,
                      boxShadow: isActive ? [BoxShadow(color: const Color(0xFF800020).withOpacity(0.5), blurRadius: 10)] : [],
                    ),
                    child: Icon(step['icon'] as IconData, color: isActive ? Colors.white : Colors.white24, size: 20),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    step['label'] as String,
                    style: TextStyle(color: isActive ? Colors.white : Colors.white24, fontSize: 10),
                  )
                ],
              ),
              // Linha Conectora (se não for o último)
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 15, left: 5, right: 5), // Alinha com a bolinha
                    color: index < currentStep ? const Color(0xFF800020) : Colors.white10,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
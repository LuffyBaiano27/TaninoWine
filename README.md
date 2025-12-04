# 🍷 TaninoWine

> **A Experiência Premium em Vinhos na Palma da sua Mão.**

O **TaninoWine** é uma aplicação completa de e-commerce para venda de vinhos à distância, desenvolvida com **Flutter** e integrada ao **Firebase**. O projeto visa entregar uma interface elegante (Dark Mode), robusta e fluida, proporcionando uma experiência de usuário imersiva desde a escolha do rótulo até o checkout.

---

### 👨‍💻 Sobre o Projeto

Este aplicativo está sendo desenvolvido como parte do curso de **Análise e Desenvolvimento de Sistemas**.

* **Desenvolvedores:** João Marcelo (LuffyBaiano) e Kaique Dias
* **Idealização:** Taiane Leite
* **Status Atual:** 🚧 Em Construção (MVP Funcional)

---

### 🚀 Funcionalidades & Recursos Implementados

#### 📱 Experiência do Usuário
* **Catálogo Premium:** Interface visual rica com detalhes dos rótulos.
* **Filtros Avançados:** Sistema de busca inteligente com modal para filtrar por **Categoria, Uva, País e Nome** simultaneamente.
* **Carrinho de Compras:** Gestão de itens, cálculo de total e seleção de método de pagamento (Pix, Cartão, Boleto).
* **Perfil de Usuário:** Gestão de conta, edição de endereço de entrega e visualização de histórico.
* **Rastreamento de Pedidos:** Timeline visual com status do pedido (Aguardando → Entregue).
* **Avaliações:** Sistema para avaliar e visualizar notas dos vinhos.

#### 🛠️ Back-end & Admin
* **Integração Firebase:** Dados do catálogo e pedidos sincronizados em tempo real (Firestore).
* **Autenticação:** Login e Cadastro via E-mail/Senha com persistência de sessão.
* **Modo Administrador:** Painel exclusivo para adicionar e excluir vinhos do catálogo diretamente pelo app.

---

### 🗺️ Roadmap (Checklist de Melhorias)

Abaixo, a lista de funcionalidades planejadas para as próximas versões (Beta e Release):

#### 🔐 Autenticação & Segurança
- [ ] Implementar **Login com Google**.
- [ ] Remover Login com Facebook (Depreciado).
- [ ] **Bloqueio de Visitantes:** Restringir a finalização de compra apenas para usuários logados.
- [ ] **Verificação de Idade:** Garantir que o usuário seja maior de 18 anos no cadastro.

#### 👤 Perfil & Mídia
- [ ] **Upload de Imagens:** Permitir que o usuário envie foto da galeria (Firebase Storage) na criação e edição de perfil.

#### 💳 Financeiro & Logística
- [ ] **Pagamento Real:** Integração com Gateway de Pagamento (API Bancária) para transações reais.
- [ ] **Rastreamento GPS:** Link para mapa acompanhando a entrega em tempo real.
- [ ] **Previsão de Entrega:** Cálculo de frete e prazo baseado no CEP.

#### 📢 Lançamento
- [ ] **Povoamento do Banco:** Inserir catálogo completo de vinhos reais.
- [ ] **Deploy:** Hospedagem do APK para download da versão Beta.

---

### 🛠️ Tecnologias Utilizadas
* **Flutter** (Framework UI)
* **Dart** (Linguagem)
* **Firebase Firestore** (Banco de Dados NoSQL)
* **Firebase Auth** (Autenticação)
* **Provider** (Gerenciamento de Estado)

---

### 🔞 Aviso Legal
> *O consumo de bebidas alcoólicas é proibido para menores de 18 anos. Beba com moderação.*

---

> *Projeto criado com muito café, energético e, no caso da Taiane, vinho!* 🍷⚡
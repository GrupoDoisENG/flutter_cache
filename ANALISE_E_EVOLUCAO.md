# Análise e Evolução — flutter_problematico_catalog

## Visão Geral

O projeto original foi construído intencionalmente com anti-padrões Flutter para fins didáticos. Todo o código — modelo de dados, chamadas HTTP, lógica de negócio e interface — estava concentrado em um único arquivo (`lib/main.dart`, 306 linhas). Os problemas causavam lentidão perceptível, consumo desnecessário de rede, interface bloqueante e arquitetura impossível de testar ou escalar.

Este documento descreve cada problema identificado, a solução aplicada e a justificativa técnica.

---

## Estrutura Antes vs. Depois

**Antes:**
```
lib/
└── main.dart   ← 306 linhas contendo tudo
```

**Depois:**
```
lib/
├── main.dart                              ← 22 linhas (apenas inicialização)
├── models/
│   └── product.dart                       ← modelo de domínio
├── data/
│   └── product_api_client.dart            ← acesso HTTP
├── repositories/
│   └── product_repository.dart            ← cache e abstração de dados
├── providers/
│   └── product_providers.dart             ← gerenciamento de estado (Riverpod)
├── screens/
│   ├── product_list_screen.dart           ← tela de lista
│   └── product_detail_screen.dart         ← tela de detalhe
└── widgets/
    ├── product_skeleton.dart              ← skeleton loader
    ├── product_list_tile.dart             ← item da lista com cache de imagem
    └── product_gallery.dart              ← galeria com cache de imagem
```

---

## Dependências Adicionadas

| Pacote | Versão | Finalidade |
|--------|--------|------------|
| `flutter_riverpod` | ^2.6.1 | Gerenciamento de estado reativo |
| `cached_network_image` | ^3.4.1 | Cache de imagens em disco e memória |
| `dio` | ^5.8.0+1 | Cliente HTTP com timeouts e tratamento de erros |
| `shimmer` | ^3.0.0 | Skeleton loader animado |

**Removido:** `http: ^1.2.1` — substituído pelo Dio.

---

## Problemas Identificados e Soluções

---

### Problema 1 — Arquitetura Monolítica

**Descrição:**
Todo o código da aplicação (modelo `Product`, lógica de fetch HTTP, regras de negócio e widgets de UI) estava em um único arquivo `lib/main.dart` com 306 linhas. Não havia separação entre camadas.

**Impacto:**
- Impossível testar a lógica de negócio isoladamente
- Impossível reusar componentes em outras telas
- Qualquer alteração exigia modificar o mesmo arquivo
- Escalabilidade zero: adicionar novas telas ou features aumentava o acoplamento

**Solução:**
Separação em camadas com responsabilidades únicas:
- **Data:** `product_api_client.dart` — apenas comunicação HTTP
- **Repository:** `product_repository.dart` — cache e abstração de acesso a dados
- **Providers:** `product_providers.dart` — estado da aplicação
- **Screens:** apresentação das telas
- **Widgets:** componentes reutilizáveis
- **main.dart:** reduzido a 22 linhas (inicialização e roteamento)

**Justificativa técnica:**
O princípio da responsabilidade única (SRP) determina que cada módulo deve ter apenas uma razão para mudar. Com a separação em camadas, a lógica HTTP pode ser alterada sem tocar na UI, e a UI pode evoluir sem interferir na lógica de dados. Isso também viabiliza testes unitários por camada.

---

### Problema 2 — Ausência de Cache de Dados

**Localização original:** `loadProducts()` — linhas 80–120 de `main.dart`

**Descrição:**
A cada ação do usuário — abertura do app, toque no botão de refresh e, principalmente, ao **voltar da tela de detalhe** — o sistema realizava uma nova requisição HTTP completa à API, descartando os dados já carregados.

```dart
// Original: recarga forçada ao voltar da tela de detalhe
Future<void> openDetails(Product product) async {
  await Navigator.push(...);
  await loadProducts(); // ← requisição desnecessária
}
```

**Impacto:**
- Consumo de rede desnecessário
- Latência de 2+ segundos a cada navegação
- Experiência de usuário degradada com spinner frequente

**Solução:**
`ProductRepository` com cache em memória e TTL de 5 minutos:

```dart
bool get _isCacheValid =>
    _cache != null &&
    _cacheTime != null &&
    DateTime.now().difference(_cacheTime!) < _cacheDuration;

Future<List<Product>> getProducts({bool forceRefresh = false}) async {
  if (!forceRefresh && _isCacheValid) return _cache!;
  final products = await _client.fetchProducts();
  _cache = products;
  _cacheTime = DateTime.now();
  return _cache!;
}
```

**Justificativa técnica:**
O padrão de cache com TTL (Time-To-Live) garante que dados recentes sejam servidos da memória sem custo de rede. O parâmetro `forceRefresh: true` é usado apenas no pull-to-refresh intencional, quando o usuário explicitamente solicita atualização. Retornos da tela de detalhe passam a ser O(1) — apenas leitura do cache.

---

### Problema 3 — Latência Artificial de 2 Segundos

**Localização original:** linha 93 de `main.dart`

**Descrição:**
Um delay intencional foi adicionado em toda operação de carga:

```dart
await Future.delayed(const Duration(seconds: 2));
```

Isso somava 2 segundos à latência real de rede em **cada** chamada: inicialização, refresh e retorno da tela de detalhe.

**Impacto:**
- Tempo mínimo de espera de 2s em toda interação com dados
- Composto com a latência real de rede: 3–4 segundos no total
- Degradação severa da experiência

**Solução:**
O `Future.delayed` foi removido. O `ProductApiClient` usa Dio com timeouts reais configurados:

```dart
BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
)
```

**Justificativa técnica:**
Timeouts reais protegem contra falhas de rede genuínas sem introduzir latência artificial. A percepção de velocidade do app agora reflete apenas o tempo de resposta da API.

---

### Problema 4 — Ausência de Cache de Imagens

**Localização original:** linhas 190 e 248 de `main.dart`

**Descrição:**
Imagens eram carregadas com `Image.network()` sem qualquer configuração de cache:

```dart
Image.network(
  product.thumbnail,
  // sem cache, sem placeholder, sem política de retry
)
```

Ao rolar a lista ou navegar entre telas, as mesmas imagens eram baixadas novamente da rede.

**Impacto:**
- Flickering visual durante scroll
- Re-download das mesmas imagens a cada navegação
- Desperdício de banda e bateria
- UI lenta ao exibir listas longas

**Solução:**
`CachedNetworkImage` em `ProductListTile` e `ProductGallery`:

```dart
CachedNetworkImage(
  imageUrl: product.thumbnail,
  width: 72,
  height: 72,
  fit: BoxFit.cover,
  placeholder: (context, url) => Shimmer.fromColors(...),
  errorWidget: (context, url, error) => Icon(Icons.broken_image),
)
```

**Justificativa técnica:**
`CachedNetworkImage` mantém um cache em disco e em memória. Na primeira exibição, a imagem é baixada e persistida. Em exibições subsequentes — scroll, navegação, reinicialização do widget — a imagem é servida do cache local sem nenhuma chamada de rede.

---

### Problema 5 — Spinner Bloqueante em Tela Cheia

**Localização original:** linhas 150–155 de `main.dart`

**Descrição:**
Durante qualquer operação de carregamento, a tela inteira era substituída por um `CircularProgressIndicator`, impedindo qualquer interação:

```dart
if (isLoading) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}
```

Isso ocorria também no **refresh**, quando os dados anteriores já estavam disponíveis.

**Impacto:**
- Usuário perde visibilidade do conteúdo já carregado durante recargas
- Experiência visual abrupta e bloqueante
- Percepção de lentidão aumentada

**Solução:**
- **Primeira carga:** `ProductSkeleton` com Shimmer — comunica progresso sem bloquear
- **Recargas:** `RefreshIndicator` no topo da lista — lista permanece visível

```dart
productsAsync.when(
  loading: () => const ProductSkeleton(), // apenas na primeira carga
  data: (products) => RefreshIndicator(
    onRefresh: () => ref.read(productListProvider.notifier).refresh(),
    child: ListView.separated(...),
  ),
  error: (e, _) => ErrorWidget(...),
)
```

**Justificativa técnica:**
Skeleton loaders são preferíveis a spinners porque preservam a estrutura visual da página, reduzindo a percepção de tempo de espera. O `RefreshIndicator` padrão do Material Design mantém o conteúdo anterior visível enquanto novos dados chegam, evitando a sensação de "tela em branco".

---

### Problema 6 — Recarga Forçada ao Voltar da Tela de Detalhe

**Localização original:** linhas 122–134 de `main.dart`

**Descrição:**
Ao retornar da tela de detalhe, `loadProducts()` era chamado incondicionalmente:

```dart
Future<void> openDetails(Product product) async {
  await Navigator.push(...);
  await loadProducts(); // ← sempre, mesmo sem mudança de dados
}
```

Isso disparava: 2s de delay artificial + requisição HTTP + rebuild completo da lista.

**Impacto:**
- 2–4 segundos de espera ao simplesmente voltar de uma tela de detalhe
- Spinner bloqueante após cada navegação
- Experiência idêntica a uma falha de rede

**Solução:**
Navegação síncrona sem reload:

```dart
void _openDetail(BuildContext context, Product product) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
  );
  // sem await, sem loadProducts()
}
```

**Justificativa técnica:**
Os dados do produto não mudam durante a visita à tela de detalhe. Recarregar é redundante. O cache do `ProductRepository` garante que os dados exibidos na lista sejam consistentes. Recargas explícitas ficam reservadas ao pull-to-refresh e ao botão de refresh, ambos sob controle do usuário.

---

### Problema 7 — Três Chamadas `setState` por Ciclo de Carga

**Localização original:** linhas 81–84, 106–110, 115–118 de `main.dart`

**Descrição:**
Uma única operação de carga de dados provocava três rebuilds do widget:

```dart
// 1º setState — marca isLoading = true
setState(() { isLoading = true; errorMessage = null; });

// ... requisição HTTP ...

// 2º setState — atualiza a lista
setState(() { products = rawProducts.map(...).toList(); });

// 3º setState (no finally) — marca isLoading = false
setState(() { isLoading = false; });
```

**Impacto:**
- 3 rebuilds completos do widget por operação
- Renderização desnecessária da árvore de widgets
- Possíveis frames perdidos (jank) em dispositivos lentos

**Solução:**
`AsyncNotifier` do Riverpod emite um único estado por transição:

```dart
Future<void> refresh() async {
  state = const AsyncLoading();          // 1 emissão
  state = await AsyncValue.guard(...);   // 1 emissão (AsyncData ou AsyncError)
}
```

**Justificativa técnica:**
Riverpod compara o estado anterior com o novo antes de notificar os observers. Cada transição gera exatamente uma notificação, resultando em um único rebuild da UI por operação. Isso elimina o problema de múltiplos rebuilds encadeados.

---

### Problema 8 — Gerenciamento de Estado com `setState` Puro

**Localização original:** classe `_ProductListPageState` em `main.dart`

**Descrição:**
O estado da aplicação era gerenciado diretamente no widget com variáveis locais:

```dart
class _ProductListPageState extends State<ProductListPage> {
  bool isLoading = false;
  String? errorMessage;
  List<Product> products = [];
  // lógica de fetch misturada com UI
}
```

**Impacto:**
- Lógica de negócio acoplada à camada de apresentação
- Impossível reusar o estado em outras telas
- Impossível testar a lógica sem instanciar o widget
- Sem separação entre "o quê exibir" e "como buscar"

**Solução:**
Riverpod `AsyncNotifier` com `ConsumerWidget`:

```dart
class ProductListNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async =>
      ref.read(productRepositoryProvider).getProducts();

  Future<void> refresh() async { ... }
}
```

```dart
class ProductListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);
    return productsAsync.when(data: ..., loading: ..., error: ...);
  }
}
```

**Justificativa técnica:**
`AsyncNotifier` separa completamente a lógica de dados da UI. O widget apenas observa e reage ao estado — não sabe como os dados são buscados. Isso torna o `ProductListNotifier` testável de forma isolada e o estado compartilhável entre múltiplos widgets ou telas.

---

### Problema 9 — Tratamento de Erros Genérico

**Localização original:** linhas 99–100 e 111–114 de `main.dart`

**Descrição:**
Erros eram capturados de forma genérica sem distinção por tipo:

```dart
if (response.statusCode != 200) {
  throw Exception('Erro ao buscar produtos');
}
// ...
catch (e) {
  setState(() { errorMessage = 'Falha ao carregar produtos: $e'; });
}
```

Sem timeout configurado no cliente HTTP e sem diferenciação entre falha de rede, timeout e erro do servidor.

**Impacto:**
- Mensagens de erro genéricas sem orientação ao usuário
- Sem possibilidade de tratamento diferenciado por tipo de falha
- Sem timeout: requisições podiam bloquear indefinidamente

**Solução:**
`ProductApiException` tipada com mapeamento de `DioExceptionType`:

```dart
String _mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      return 'Tempo de conexão esgotado. Verifique sua internet.';
    case DioExceptionType.badResponse:
      return 'Erro do servidor: ${e.response?.statusCode}';
    case DioExceptionType.connectionError:
      return 'Sem conexão com a internet.';
    default:
      return 'Erro de rede inesperado.';
  }
}
```

Na UI, o estado `AsyncError` exibe a mensagem com botão de retry:

```dart
error: (error, _) => Column(children: [
  Text(error.toString()),
  ElevatedButton(
    onPressed: () => ref.read(productListProvider.notifier).refresh(),
    child: const Text('Tentar novamente'),
  ),
])
```

**Justificativa técnica:**
Erros tipados permitem que a camada de apresentação tome decisões informadas: exibir mensagem de "sem internet" vs. "erro do servidor" vs. "timeout". O botão de retry fecha o ciclo UX sem precisar reiniciar o app.

---

### Problema 10 — Modelo `Product` Incompleto

**Localização original:** linhas 27–60 de `main.dart`

**Descrição:**
O modelo `Product` era funcional apenas para exibição, sem recursos necessários para serialização, comparação ou imutabilidade:

```dart
class Product {
  // sem ==, sem hashCode
  // sem toJson
  // sem copyWith
  // construtor não-const
  factory Product.fromMap(...) { ... } // apenas fromMap
}
```

**Impacto:**
- Riverpod não consegue detectar mudanças reais de estado sem `==`
- Não serializável para cache persistente (SharedPreferences, SQLite)
- Impossível atualizar campos específicos sem recriar o objeto manualmente

**Solução:**
Model completo com `@immutable`:

```dart
@immutable
class Product {
  const Product({...});

  factory Product.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }

  Product copyWith({...}) { ... }

  @override
  bool operator ==(Object other) { ... } // todos os campos

  @override
  int get hashCode => Object.hash(...);
}
```

**Justificativa técnica:**
`@immutable` e `const` garantem que objetos `Product` não sejam mutados após criação. A implementação de `==` e `hashCode` permite que Riverpod compare estados corretamente, evitando rebuilds desnecessários quando os dados não mudam. `toJson` habilita serialização para cache persistente futuro.

---

### Problema 11 — Ausência de Placeholder durante Carregamento de Imagens

**Localização original:** linhas 190 e 248 de `main.dart`

**Descrição:**
`Image.network()` não exibia nenhum conteúdo enquanto a imagem era baixada — o espaço ficava em branco ou cinza sem animação:

```dart
Image.network(
  product.thumbnail,
  errorBuilder: (...) => Container(color: Colors.grey.shade300),
  // sem placeholder de carregamento
)
```

**Impacto:**
- UI com "buracos" visuais durante o carregamento
- Flickering ao rolar a lista (imagens aparecem abruptamente)
- Experiência visual inferior

**Solução:**
Shimmer animado como placeholder em todos os widgets de imagem:

```dart
CachedNetworkImage(
  imageUrl: product.thumbnail,
  placeholder: (context, url) => Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: Container(color: Colors.white, width: 72, height: 72),
  ),
  errorWidget: (context, url, error) => Icon(Icons.broken_image),
)
```

O mesmo padrão é aplicado no `ProductSkeleton` para o estado de carregamento inicial da lista.

**Justificativa técnica:**
Shimmer loaders comunicam ao usuário que conteúdo está sendo carregado, mantendo a estrutura visual da página. Estudos de UX mostram que animações de placeholder reduzem a percepção subjetiva de tempo de espera em comparação a espaços em branco ou spinners genéricos.

---

## Resumo das Melhorias

| # | Problema | Arquivo Corrigido | Padrão Aplicado |
|---|----------|-------------------|-----------------|
| 1 | Monolito em único arquivo | Todos os arquivos novos | Separação em camadas (Data / Repository / Provider / UI) |
| 2 | Zero cache de dados | `product_repository.dart` | Cache em memória com TTL |
| 3 | Delay artificial de 2s | `product_api_client.dart` | Remoção + timeout real via Dio |
| 4 | Zero cache de imagens | `product_list_tile.dart`, `product_gallery.dart` | `CachedNetworkImage` (disco + memória) |
| 5 | Spinner bloqueante em tela cheia | `product_list_screen.dart`, `product_skeleton.dart` | Skeleton loader + `RefreshIndicator` |
| 6 | Recarga forçada ao voltar | `product_list_screen.dart` | Navegação síncrona sem reload |
| 7 | 3 `setState` por ciclo (3 rebuilds) | `product_providers.dart` | `AsyncNotifier` com emissão única de estado |
| 8 | `setState` como gerenciamento de estado | `product_providers.dart`, telas | Riverpod `AsyncNotifier` + `ConsumerWidget` |
| 9 | Erros genéricos sem retry | `product_api_client.dart`, `product_list_screen.dart` | `ProductApiException` tipada + botão retry |
| 10 | Model sem `==`, `hashCode`, `toJson`, `copyWith` | `product.dart` | Model imutável completo com `@immutable` |
| 11 | Sem placeholder de carregamento de imagens | Widgets de imagem, `product_skeleton.dart` | Shimmer animado |

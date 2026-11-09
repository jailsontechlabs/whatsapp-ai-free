# JailsonTech WhatsApp AI — implantação pelo painel Cloudflare

## O que esta versão entrega
- Recebe `messages.upsert` da Evolution API.
- Ignora mensagens enviadas pelo próprio número, grupos e status.
- Evita processar o mesmo ID de mensagem duas vezes.
- Salva contatos, conversas e histórico no D1.
- Busca as informações do negócio no D1.
- Consulta NVIDIA Nemotron 3 Super via endpoint OpenAI-compatible.
- Envia a resposta pela Evolution API.
- Divide respostas grandes em mensagens menores.
- Responde com uma mensagem de contingência quando recebe mídia não textual.

**Limite desta versão:** texto de entrada e saída. O Nemotron 3 Super 120B A12B é texto-para-texto. Áudio, imagem, PDF e resposta por voz exigem processadores adicionais; não ative Base64 esperando que este código interprete mídia.

## 1. Inicializar o D1
1. Cloudflare > Storage & databases > D1 SQL Database.
2. Abra `atendente-whatsapp-ai-db`.
3. Abra `Console`.
4. Cole o conteúdo integral de `schema.sql`.
5. Execute.
6. Confira se as tabelas foram criadas.

## 2. Conferir os bindings e variáveis do Worker
Worker: `atendente-whatsapp-ai`

Binding:
- D1 database binding: `DB` -> `atendente-whatsapp-ai-db`

Runtime variables / secrets:
- Secret `NVIDIA_API_KEY` (já criado)
- Secret `EVOLUTION_APIKEY` (já criado)
- Variable `EVOLUTION_URL` = `https://minha-url-evolution.com`
- Variable `EVOLUTION_INSTANCIA` = `minha_instancia_evolution`

Não acrescente `/manager` à URL. Não cole chaves em código.

## 3. Publicar o código
1. Workers & Pages > `atendente-whatsapp-ai` > Edit code.
2. Abra o arquivo principal `worker.js` (ou o único arquivo JavaScript do editor).
3. Substitua TODO o conteúdo pelo arquivo `worker.js` deste pacote.
4. Clique em Save and deploy / Deploy.
5. Abra:
   `https://meu_link_worker_cloudflare.workers.dev/health`
6. Confirme que a resposta JSON mostra `databaseBound`, `nvidiaSecretSet`, `evolutionSecretSet`, `evolutionUrlSet` e `instanceSet` como `true`.

Se aparecer `false`, corrija a variável/secret ou binding antes de configurar o webhook.

## 4. Testar a conexão NVIDIA sem expor a chave
O teste real será feito pelo primeiro WhatsApp de teste. Se a NVIDIA retornar erro, abra Worker > Observability > Logs e procure `AI_ERROR`. Nunca copie a chave para o chat ou para o código.

## 5. Configurar webhook Evolution
Na instância `minha_instancia_evolution`, configure:
- Webhook: Enabled
- URL: `https://meu_link_worker_cloudflare.workers.dev/webhook/evolution`
- Evento: `MESSAGES_UPSERT` (ou `messages.upsert`, conforme o seletor do Manager)
- Webhook by Events: desativado, se a tela oferecer essa opção
- Base64: `false` nesta versão

Salve. Não marque eventos de status, updates ou mensagens enviadas se não forem necessários.

## 6. Teste ponta a ponta
1. Use um segundo WhatsApp para enviar uma mensagem à instância conectada.
2. Comece com: `Olá, quais serviços vocês oferecem?`
3. A resposta deve chegar pelo mesmo WhatsApp.
4. Envie outra mensagem de continuação, por exemplo: `E qual é o horário?`
5. O atendente deve manter o contexto.
6. D1 > Explore Data: confira `contacts`, `conversations`, `messages` e `processed_events`.

## 7. Alimentar os dados do negócio
No D1 > Console, altere o negócio padrão. Exemplo:

```sql
UPDATE businesses
SET
  name = 'Nome real da empresa',
  description = 'O que a empresa faz e para quem atende.',
  opening_hours = 'Segunda a sexta, das 8h às 18h.',
  address = 'Rua, número, bairro, cidade.',
  instructions = 'Tom cordial e consultivo. Faça triagem antes de encaminhar. Nunca invente preços ou horários.',
  updated_at = datetime('now')
WHERE id = 'default';
```

Cadastre serviços, preços e perguntas frequentes em `knowledge_base`:

```sql
INSERT INTO knowledge_base (business_id, title, content, priority)
VALUES
('default', 'Serviço: avaliação', 'A avaliação inicial deve ser agendada com a equipe. Não prometa horários sem confirmação.', 20),
('default', 'Pagamento', 'Aceitamos Pix e cartão. Confirme condições específicas com a equipe.', 10);
```

Para corrigir/remover uma informação:
```sql
UPDATE knowledge_base SET content = 'Texto corrigido' WHERE id = 1;
-- ou
UPDATE knowledge_base SET active = 0 WHERE id = 1;
```

## 8. Como tarefas e atendimento humano entram
As tabelas `tasks` e `handoffs` já estão criadas como estrutura. Nesta primeira versão, o modelo não executa ações externas nem cria agendamentos reais. Não diga ao cliente que um horário foi reservado ou que uma tarefa foi concluída sem uma integração que confirme a operação.

## 9. Áudio, imagem e documentos — próxima expansão
- Áudio: Evolution precisa disponibilizar/baixar o arquivo; depois um serviço de speech-to-text transcreve; o texto segue para o Nemotron.
- Imagem: usar modelo de visão. O Nemotron 3 Super 120B A12B escolhido não recebe imagem. A família Nemotron 3.5 Super VL é uma opção de visão, mas requer teste de disponibilidade, endpoint e custo/limite.
- PDF: baixar com limite de tamanho, extrair texto e enviar trechos relevantes ao modelo.
- Resposta por voz: adicionar TTS e enviar o áudio via Evolution.
- Não habilite Base64 para todos os eventos até existir tratamento de tamanho, mídia e armazenamento.

## 10. Segurança e operação
- Nunca compartilhe `NVIDIA_API_KEY` ou `EVOLUTION_APIKEY`.
- O endpoint de webhook deve receber somente eventos da instância esperada. Para produção, acrescente autenticação de webhook por cabeçalho secreto se a sua versão/configuração Evolution permitir headers customizados.
- Esta versão é protótipo de uma única instância/um único negócio. Não é ainda um SaaS multiempresa.
- O Worker pode permanecer publicado no plano gratuito dentro dos limites, mas Evolution hospedada no Render e NVIDIA são dependências externas e podem ficar indisponíveis ou impor limites.
- Se falhar, consulte Workers & Pages > Worker > Observability > Logs. O código não grava segredos nos logs.

## Endpoints
- `GET /health` — verifica bindings e presença das variáveis sem revelar valores.
- `POST /webhook/evolution` — recebe eventos Evolution.

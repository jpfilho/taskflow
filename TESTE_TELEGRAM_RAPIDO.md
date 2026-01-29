# 🧪 TESTE RÁPIDO DO TELEGRAM

## 📱 PASSO A PASSO NO APP

### **1️⃣ Abrir um Chat**

1. No app Flutter, vá para a tela de **Chat** (ícone de mensagem)
2. Você verá uma lista de **Comunidades**
3. Clique em qualquer comunidade (ex: "DIVISÃO X - SEGMENTO Y")
4. Depois clique em um **Grupo/Tarefa** específico

---

### **2️⃣ Abrir Configurações do Telegram**

No topo da tela do chat, procure por um **ícone do Telegram** (ou ⚙️/📱).

**Clique nele!**

Isso vai abrir o diálogo de configuração do Telegram.

---

### **3️⃣ Configurar Integração**

No diálogo que abriu:

1. **Vincular conta Telegram:**
   - Clique em "Vincular meu Telegram"
   - Um deep link será gerado
   - Abra no navegador ou Telegram
   - Fale `/start` com o bot @TaskFlow_chat_bot

2. **Ativar espelhamento:**
   - Marque a opção "Ativar espelhamento"
   - Escolha o modo: **DM** (Direct Message)
   - Clique em "Salvar"

---

### **4️⃣ Testar Envio: Flutter → Telegram**

1. No chat do Flutter, **digite uma mensagem:** "Teste 1 do Flutter"
2. Envie a mensagem
3. **Abra o Telegram** no seu celular/PC
4. Verifique se o bot **@TaskFlow_chat_bot** te enviou a mensagem

**✅ Funcionou?** → Ótimo!  
**❌ Não funcionou?** → Copie o erro e me avise

---

### **5️⃣ Testar Recebimento: Telegram → Flutter**

1. No Telegram, **responda** a mensagem do bot
2. Digite: "Teste 2 do Telegram"
3. **Volte ao Flutter**
4. Verifique se a mensagem apareceu no chat

**✅ Funcionou?** → Perfeito!  
**❌ Não funcionou?** → Me avise

---

## 🐛 SE NÃO ENCONTRAR O ÍCONE DO TELEGRAM

Pode ser que o ícone não esteja visível. Nesse caso, tente:

1. Procure por um ícone de **menu** (⋮ ou ⚙️) no canto superior direito
2. Ou procure nas opções do chat

**Se não encontrar**, me avise que vou verificar o código!

---

## 📊 QUERIES PARA VERIFICAR NO SUPABASE

Se quiser verificar se está funcionando no banco:

```sql
-- Ver mensagens do Telegram
SELECT * FROM mensagens 
WHERE source = 'telegram' 
ORDER BY created_at DESC 
LIMIT 10;

-- Ver subscriptions ativas
SELECT * FROM telegram_subscriptions;

-- Ver identidades linkadas
SELECT * FROM telegram_identities;
```

---

## ✅ CHECKLIST

- [ ] Abri um chat no Flutter
- [ ] Encontrei o ícone do Telegram
- [ ] Vinculei minha conta Telegram
- [ ] Ativei o espelhamento (modo DM)
- [ ] Enviei mensagem do Flutter → chegou no Telegram
- [ ] Enviei mensagem do Telegram → chegou no Flutter

---

**COMECE AGORA E ME AVISE O RESULTADO!** 🚀

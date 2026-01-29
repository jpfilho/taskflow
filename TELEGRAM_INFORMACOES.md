# 🤖 INFORMAÇÕES DO TELEGRAM - TASKFLOW

## 📋 **DADOS DO BOT:**

- **Bot Username:** `@taskflow_bot`
- **Bot Token:** `8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec`
- **Webhook Secret:** `Tg0h00kSecr3t2025fasKFlow`

---

## ⚠️ **FALTA OBTER:**

- **CHAT_ID** do grupo onde o bot está

---

## 🔍 **COMO OBTER O CHAT_ID:**

### **Opção 1: Usando o script (RECOMENDADO)**

```powershell
.\obter_chat_id.ps1
```

1. Digite o token quando solicitado (copie de cima)
2. Vá no Telegram e envie uma mensagem no grupo
3. Volte e pressione ENTER
4. O script vai mostrar o Chat ID

### **Opção 2: Manual via navegador**

1. Acesse no navegador:
   ```
   https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/getUpdates
   ```

2. Procure por: `"chat":{"id":-1001234567890`

3. Copie o número (ex: `-1001234567890`)

---

## 🚀 **PRÓXIMOS PASSOS:**

1. ✅ SSL configurado
2. ⏳ Obter CHAT_ID (em andamento)
3. ⏳ Configurar webhook
4. ⏳ Deploy Edge Functions (pode ter problema)
5. ⏳ Testar integração

---

## 📝 **NOTAS:**

- O domínio correto é: `api.taskflowv3.com.br` (com "v" de victor)
- Já tem SSL/HTTPS funcionando
- Supabase self-hosted pode não suportar Edge Functions nativamente

/**
 * Servidor Dedicado e Exclusivo de Autenticação Active Directory (Chesf)
 * 
 * Este servidor roda na porta 3001 e atende SOMENTE:
 * - POST /auth/ad-login  -> Autentica usuário no AD e sincroniza no Supabase
 * - GET  /health         -> Health check simples
 * 
 * NÃO CONTÉM NENHUMA INTEGRAÇÃO COM TELEGRAM OU OUTROS SERVIÇOS.
 */

const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const { authenticateAD } = require('./ad_auth');

const app = express();
const PORT = process.env.PORT || 3001;

// Configuração do Supabase (para vincular/salvar o usuário logado)
const SUPABASE_URL = process.env.SUPABASE_URL_INTERNAL || 'http://127.0.0.1:8000';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Middlewares
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ ok: true, servico: 'TaskFlow AD Auth Server', status: 'online' });
});

// Endpoint de login pelo Active Directory
app.post('/auth/ad-login', async (req, res) => {
  const { username, password } = req.body || {};

  if (!username || !password) {
    return res.status(400).json({
      ok: false,
      error: 'Informe o usuário e a senha de rede.',
    });
  }

  console.log(`🔐 [AD Auth] Tentativa de login para usuário: ${username}`);

  try {
    const authResult = await authenticateAD(username, password);

    if (!authResult.success) {
      console.warn(`❌ [AD Auth] Falha na autenticação para ${username}:`, authResult.error);
      return res.status(401).json({
        ok: false,
        error: authResult.error || 'Credenciais inválidas.',
      });
    }

    const adUser = authResult.user;
    console.log(`✅ [AD Auth] Usuário autenticado com sucesso no AD:`, adUser.username);

    // Buscar usuário no Supabase pela tabela usuarios
    const emailLower = (adUser.email || `${adUser.username}@chesf.gov.br`).toLowerCase();
    
    const { data: existingUsers, error: searchError } = await supabase
      .from('usuarios')
      .select('*')
      .or(`email.ilike.${emailLower},email.ilike.${adUser.username}@%`)
      .limit(1);

    if (searchError) {
      console.error('❌ [AD Auth] Erro ao buscar usuário no Supabase:', searchError);
    }

    let finalUser = null;

    if (existingUsers && existingUsers.length > 0) {
      finalUser = existingUsers[0];
      if (adUser.nome && adUser.nome !== finalUser.nome) {
        await supabase
          .from('usuarios')
          .update({ nome: adUser.nome, updated_at: new Date().toISOString() })
          .eq('id', finalUser.id);
        finalUser.nome = adUser.nome;
      }
    } else {
      // Provisiona usuário automaticamente no Task Flow
      const novoId = require('crypto').randomUUID();
      const novoUsuario = {
        id: novoId,
        email: emailLower,
        nome: adUser.nome || adUser.username,
        senha_hash: 'AD_AUTHENTICATED',
        ativo: true,
        is_root: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const { data: inserted, error: insertError } = await supabase
        .from('usuarios')
        .insert(novoUsuario)
        .select()
        .single();

      if (insertError) {
        console.error('❌ [AD Auth] Erro ao criar usuário no Supabase:', insertError);
        finalUser = novoUsuario;
      } else {
        finalUser = inserted;
      }
    }

    return res.json({
      ok: true,
      usuario: finalUser,
      ad_info: {
        username: adUser.username,
        nome: adUser.nome,
        email: adUser.email,
        departamento: adUser.departamento,
      },
    });
  } catch (err) {
    console.error('💥 [AD Auth] Exceção inesperada no AD login:', err);
    return res.status(500).json({
      ok: false,
      error: `Erro interno no servidor de autenticação: ${err.message}`,
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('==================================================');
  console.log('🏢 Servidor Exclusivo de Login AD (Rede Chesf)');
  console.log('==================================================');
  console.log(`✅ Escutando na porta ${PORT} (0.0.0.0:${PORT})`);
  console.log(`🔗 Endpoint de Login: POST http://0.0.0.0:${PORT}/auth/ad-login`);
  console.log(`🔗 Health Check: GET http://0.0.0.0:${PORT}/health`);
  console.log('==================================================');
});

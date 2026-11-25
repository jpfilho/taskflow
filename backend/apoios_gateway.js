const crypto = require('crypto');
const {
  createApoiosNotificacoesWorker,
  enqueueOutboxEvent,
} = require('./apoios_notificacoes_worker');

const TOKEN_TTL_SECONDS = 12 * 60 * 60; // 12 horas
const _loginAttempts = new Map();
const _revokedJtis = new Map(); // jti -> expiresAtMs
const _jwksCache = new Map(); // tenantId -> { keys, fetchedAt }

function checkLoginRateLimit(key) {
  const now = Date.now();
  const windowMs = 5 * 60 * 1000;
  const maxAttempts = 10;
  if (_loginAttempts.size > 2000) {
    for (const [k, v] of _loginAttempts.entries()) {
      if (now - v.firstAt > windowMs) _loginAttempts.delete(k);
    }
  }
  const entry = _loginAttempts.get(key);
  if (!entry || now - entry.firstAt > windowMs) {
    _loginAttempts.set(key, { count: 1, firstAt: now });
    return true;
  }
  entry.count += 1;
  return entry.count <= maxAttempts;
}

function getGatewaySecret() {
  const secret =
    process.env.APOIOS_GATEWAY_SECRET ||
    process.env.JWT_SECRET ||
    process.env.SUPABASE_SERVICE_KEY;
  if (secret && String(secret).trim().length >= 16) {
    return String(secret);
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('APOIOS_GATEWAY_SECRET não configurado em ambiente de produção.');
  }
  return crypto.createHash('sha256').update('taskflow-dev-apoios-secret').digest('hex');
}

function base64UrlEncode(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(String(input), 'utf8');
  return buf
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function base64UrlDecode(str) {
  let b64 = String(str).replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4 !== 0) b64 += '=';
  return Buffer.from(b64, 'base64').toString('utf8');
}

function signApoiosToken(usuario) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = base64UrlEncode(
    JSON.stringify({
      jti: crypto.randomUUID(),
      sub: usuario.id,
      email: usuario.email,
      nome: usuario.nome || null,
      is_root: Boolean(usuario.is_root),
      iat: now,
      exp: now + TOKEN_TTL_SECONDS,
      scope: 'apoios_operacionais',
    })
  );
  const data = `${header}.${payload}`;
  const sig = base64UrlEncode(
    crypto.createHmac('sha256', getGatewaySecret()).update(data).digest()
  );
  return `${data}.${sig}`;
}

function verifyApoiosToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, payload, sig] = parts;
  const data = `${header}.${payload}`;
  const expectedSig = base64UrlEncode(
    crypto.createHmac('sha256', getGatewaySecret()).update(data).digest()
  );

  const sigBuf = Buffer.from(sig);
  const expectedBuf = Buffer.from(expectedSig);
  if (sigBuf.length !== expectedBuf.length) return null;
  if (!crypto.timingSafeEqual(sigBuf, expectedBuf)) return null;

  try {
    const decoded = JSON.parse(base64UrlDecode(payload));
    const now = Math.floor(Date.now() / 1000);
    if (!decoded.sub || !decoded.exp || decoded.exp < now) return null;
    if (decoded.scope !== 'apoios_operacionais') return null;
    if (decoded.jti && _revokedJtis.has(decoded.jti)) return null;
    return decoded;
  } catch (_) {
    return null;
  }
}

async function isTokenRevoked(supabase, decoded) {
  if (!decoded || !decoded.jti) return false;
  const nowMs = Date.now();
  const cachedExp = _revokedJtis.get(decoded.jti);
  if (cachedExp && cachedExp > nowMs) return true;
  if (cachedExp && cachedExp <= nowMs) _revokedJtis.delete(decoded.jti);

  try {
    const { data } = await supabase
      .from('tasks_apoios_tokens_revogados')
      .select('jti, expires_at')
      .eq('jti', decoded.jti)
      .maybeSingle();
    if (data) {
      const expMs = new Date(data.expires_at).getTime() || nowMs + 3600000;
      _revokedJtis.set(decoded.jti, expMs);
      return true;
    }
  } catch (_) {
    // Em caso de tabela ainda não migrada em testes unitários, mantém fallback em memória
  }
  return false;
}

async function verifyEntraJwtToken(accessToken, { tenantId, expectedAudience }) {
  if (!accessToken || typeof accessToken !== 'string') {
    throw new Error('Token Entra ID ausente.');
  }
  const parts = accessToken.split('.');
  if (parts.length !== 3) {
    throw new Error('Token Entra ID malformado.');
  }
  const [headerB64, payloadB64, sigB64] = parts;
  const header = JSON.parse(base64UrlDecode(headerB64));
  const payload = JSON.parse(base64UrlDecode(payloadB64));

  if (header.alg !== 'RS256' || !header.kid) {
    throw new Error('Algoritmo ou kid inválido no token Entra ID.');
  }

  // Rejeitar explicitamente tokens emitidos para Microsoft Graph ou outras APIs
  const msGraphAppId = '00000003-0000-0000-c000-000000000000';
  if (!expectedAudience || payload.aud === msGraphAppId || payload.aud !== expectedAudience) {
    throw new Error('Audiência (aud) do token Entra ID não corresponde à API do TaskFlow.');
  }

  const validIssuers = [
    `https://login.microsoftonline.com/${tenantId}/v2.0`,
    `https://sts.windows.net/${tenantId}/`,
  ];
  if (!validIssuers.includes(payload.iss)) {
    throw new Error('Emissor (iss) do token Entra ID inválido.');
  }
  if (payload.tid !== tenantId) {
    throw new Error('Tenant (tid) do token Entra ID não autorizado.');
  }

  const now = Math.floor(Date.now() / 1000);
  if (!payload.exp || payload.exp <= now) {
    throw new Error('Token Entra ID expirado.');
  }
  if (payload.nbf && payload.nbf > now + 60) {
    throw new Error('Token Entra ID ainda não é válido (nbf).');
  }

  // Buscar JWKS do tenant (cache 15 min)
  const cached = _jwksCache.get(tenantId);
  let keys = cached && Date.now() - cached.fetchedAt < 15 * 60 * 1000 ? cached.keys : null;
  if (!keys) {
    const jwksRes = await fetch(
      `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`
    );
    if (!jwksRes.ok) {
      throw new Error('Falha ao obter chaves públicas JWKS da Microsoft.');
    }
    const jwksJson = await jwksRes.json();
    keys = jwksJson.keys || [];
    _jwksCache.set(tenantId, { keys, fetchedAt: Date.now() });
  }

  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) {
    throw new Error('Chave pública (kid) não encontrada no JWKS da Microsoft.');
  }

  const publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  const sigBuf = Buffer.from(
    sigB64.replace(/-/g, '+').replace(/_/g, '/'),
    'base64'
  );
  const validSig = crypto.verify(
    'RSA-SHA256',
    Buffer.from(`${headerB64}.${payloadB64}`),
    publicKey,
    sigBuf
  );
  if (!validSig) {
    throw new Error('Assinatura digital RS256 do token Entra ID inválida.');
  }

  return payload;
}

async function loadUsuarioComPerfil(supabase, usuarioId) {
  const { data: usuario, error } = await supabase
    .from('usuarios')
    .select('id, email, nome, ativo, is_root')
    .eq('id', usuarioId)
    .maybeSingle();

  if (error || !usuario || usuario.ativo === false) {
    return null;
  }

  const [regRes, divRes, segRes, execRes] = await Promise.all([
    supabase.from('usuarios_regionais').select('regional_id').eq('usuario_id', usuarioId),
    supabase.from('usuarios_divisoes').select('divisao_id').eq('usuario_id', usuarioId),
    supabase.from('usuarios_segmentos').select('segmento_id').eq('usuario_id', usuarioId),
    usuario.email
      ? supabase
          .from('executores')
          .select('login, funcoes!left(funcao)')
          .eq('ativo', true)
          .ilike('login', String(usuario.email).toLowerCase().trim())
          .maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  const funcao = execRes?.data?.funcoes?.funcao
    ? String(execRes.data.funcoes.funcao).toUpperCase()
    : '';
  const podeEditar =
    Boolean(usuario.is_root) ||
    funcao.includes('COORDENADOR') ||
    funcao.includes('GERENTE');

  return {
    id: usuario.id,
    email: usuario.email,
    nome: usuario.nome,
    ativo: usuario.ativo !== false,
    isRoot: Boolean(usuario.is_root),
    podeEditar,
    regionalIds: (regRes.data || []).map((r) => r.regional_id).filter(Boolean),
    divisaoIds: (divRes.data || []).map((d) => d.divisao_id).filter(Boolean),
    segmentoIds: (segRes.data || []).map((s) => s.segmento_id).filter(Boolean),
  };
}

function usuarioPertenceUnidade(perfil, { regionalId, divisaoId, segmentoId }) {
  if (!perfil) return false;
  if (perfil.isRoot) return true;
  if (regionalId && perfil.regionalIds.length > 0 && !perfil.regionalIds.includes(regionalId)) {
    return false;
  }
  if (divisaoId) {
    if (!perfil.divisaoIds.includes(divisaoId)) return false;
    if (segmentoId && !perfil.segmentoIds.includes(segmentoId)) {
      return false;
    }
    return true;
  }
  if (
    regionalId &&
    perfil.divisaoIds.length === 0 &&
    perfil.regionalIds.includes(regionalId)
  ) {
    return true;
  }
  return false;
}

function usuarioPodeVerSolicitacao(perfil, sol) {
  if (!perfil || !sol) return false;
  if (perfil.isRoot) return true;
  if (sol.solicitante_usuario_id && sol.solicitante_usuario_id === perfil.id) {
    return true;
  }
  if (sol.responsavel_atendimento_id && sol.responsavel_atendimento_id === perfil.id) {
    return true;
  }
  const ehSolicitante = usuarioPertenceUnidade(perfil, {
    regionalId: sol.regional_solicitante_id,
    divisaoId: sol.divisao_solicitante_id,
    segmentoId: sol.segmento_solicitante_id,
  });
  const ehDestino = usuarioPertenceUnidade(perfil, {
    regionalId: sol.regional_destino_id,
    divisaoId: sol.divisao_destino_id,
    segmentoId: sol.segmento_destino_id,
  });
  return ehSolicitante || ehDestino;
}

async function enrichSolicitacoes(supabase, solicitacoes) {
  if (!solicitacoes || solicitacoes.length === 0) return [];
  const ids = solicitacoes.map((s) => s.id);

  const [periodosRes, vinculosRes, historicoRes, situacoesRes] = await Promise.all([
    supabase
      .from('tasks_apoios_solicitacoes_periodos')
      .select('*')
      .in('solicitacao_id', ids)
      .order('data_inicio', { ascending: true }),
    supabase
      .from('tasks_apoios_vinculos')
      .select('*')
      .in('solicitacao_id', ids),
    supabase
      .from('tasks_apoios_historico')
      .select('*')
      .in('solicitacao_id', ids)
      .order('created_at', { ascending: false }),
    supabase
      .from('v_tasks_apoios_situacao')
      .select('*')
      .in('solicitacao_id', ids),
  ]);

  const periodosBySol = new Map();
  for (const p of periodosRes.data || []) {
    const arr = periodosBySol.get(p.solicitacao_id) || [];
    arr.push(p);
    periodosBySol.set(p.solicitacao_id, arr);
  }

  const vinculosBySol = new Map();
  for (const v of vinculosRes.data || []) {
    const arr = vinculosBySol.get(v.solicitacao_id) || [];
    arr.push(v);
    vinculosBySol.set(v.solicitacao_id, arr);
  }

  const histBySol = new Map();
  for (const h of historicoRes.data || []) {
    const arr = histBySol.get(h.solicitacao_id) || [];
    arr.push(h);
    histBySol.set(h.solicitacao_id, arr);
  }

  const sitBySol = new Map();
  for (const sit of situacoesRes.data || []) {
    sitBySol.set(sit.solicitacao_id, sit);
  }

  return solicitacoes.map((s) => ({
    ...s,
    periodos: periodosBySol.get(s.id) || [],
    vinculos: vinculosBySol.get(s.id) || [],
    historico: histBySol.get(s.id) || [],
    situacao: sitBySol.get(s.id) || null,
  }));
}

function registerApoiosGateway(app, supabase, options = {}) {
  if (!app || !supabase) {
    throw new Error('app e supabase são obrigatórios para registerApoiosGateway');
  }

  const notifWorker = createApoiosNotificacoesWorker(supabase, options);
  if (options.startWorker !== false) {
    notifWorker.start();
  }

  async function requireApoiosAuth(req, res, next) {
    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
      const decoded = verifyApoiosToken(token);
      if (!decoded || (await isTokenRevoked(supabase, decoded))) {
        return res.status(401).json({
          ok: false,
          code: 'AUTH_REQUIRED',
          error: 'Sessão de Apoios Operacionais ausente, expirada ou revogada.',
        });
      }

      const perfil = await loadUsuarioComPerfil(supabase, decoded.sub);
      if (!perfil) {
        return res.status(403).json({
          ok: false,
          code: 'USER_INACTIVE',
          error: 'Usuário não encontrado ou inativo.',
        });
      }

      req.apoiosUser = perfil;
      req.apoiosTokenPayload = decoded;
      return next();
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  }

  function requireApoiosEditor(req, res, next) {
    if (!req.apoiosUser?.podeEditar) {
      return res.status(403).json({
        ok: false,
        code: 'EDIT_FORBIDDEN',
        error: 'Apenas coordenadores e gerentes podem criar ou editar apoios operacionais.',
      });
    }
    return next();
  }

  // 1. Login dedicado para troca por token assinado (email + senha na tabela usuarios)
  app.post('/auth/apoios-login', async (req, res) => {
    try {
      const { email, password } = req.body || {};
      const emailLower = String(email || '').toLowerCase().trim();
      const rateKey = `${req.ip || 'ip'}:${emailLower}`;
      if (!checkLoginRateLimit(rateKey)) {
        return res.status(429).json({
          ok: false,
          error: 'Muitas tentativas de autenticação. Aguarde alguns minutos.',
        });
      }
      if (!emailLower || !password) {
        return res.status(400).json({
          ok: false,
          error: 'Informe email e senha para autenticar o gateway de Apoios.',
        });
      }

      const { data: usuario, error } = await supabase
        .from('usuarios')
        .select('id, email, nome, senha_hash, ativo, is_root')
        .eq('email', emailLower)
        .eq('ativo', true)
        .maybeSingle();

      if (error) {
        return res.status(500).json({ ok: false, error: error.message });
      }

      if (
        !usuario ||
        !usuario.senha_hash ||
        usuario.senha_hash === 'AD_AUTHENTICATED' ||
        usuario.senha_hash === 'AZURE_AD_AUTHENTICATED' ||
        usuario.senha_hash !== String(password)
      ) {
        return res.status(401).json({
          ok: false,
          error: 'Credenciais inválidas para acesso ao gateway.',
        });
      }

      const perfil = await loadUsuarioComPerfil(supabase, usuario.id);
      if (!perfil) {
        return res.status(403).json({ ok: false, error: 'Usuário inativo.' });
      }

      const token = signApoiosToken(usuario);
      return res.json({
        ok: true,
        token,
        expiresIn: TOKEN_TTL_SECONDS,
        usuario: perfil,
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 2. Troca de Supabase Auth JWT (quando disponível) por token do gateway
  app.post('/auth/apoios-exchange', async (req, res) => {
    try {
      const authHeader = req.headers.authorization || '';
      const accessToken =
        (authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '') ||
        req.body?.supabaseAccessToken;

      if (!accessToken) {
        return res.status(400).json({
          ok: false,
          error: 'Token de sessão Supabase não informado.',
        });
      }

      const { data, error } = await supabase.auth.getUser(accessToken);
      if (error || !data?.user?.email) {
        return res.status(401).json({
          ok: false,
          error: 'Sessão Supabase inválida ou expirada.',
        });
      }

      const emailLower = data.user.email.toLowerCase().trim();
      const { data: usuario } = await supabase
        .from('usuarios')
        .select('id, email, nome, ativo, is_root')
        .eq('email', emailLower)
        .eq('ativo', true)
        .maybeSingle();

      if (!usuario) {
        return res.status(403).json({
          ok: false,
          error: 'Usuário autenticado não possui cadastro ativo no TaskFlow.',
        });
      }

      const perfil = await loadUsuarioComPerfil(supabase, usuario.id);
      const token = signApoiosToken(usuario);
      return res.json({
        ok: true,
        token,
        expiresIn: TOKEN_TTL_SECONDS,
        usuario: perfil,
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 2b. Revogação explícita de token no logout
  app.post('/auth/apoios-logout', requireApoiosAuth, async (req, res) => {
    try {
      const decoded = req.apoiosTokenPayload;
      if (decoded?.jti) {
        const expMs = (decoded.exp || Math.floor(Date.now() / 1000) + 3600) * 1000;
        _revokedJtis.set(decoded.jti, expMs);
        await supabase.from('tasks_apoios_tokens_revogados').upsert({
          jti: decoded.jti,
          usuario_id: req.apoiosUser.id,
          expires_at: new Date(expMs).toISOString(),
          motivo: 'LOGOUT',
        });
      }
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 2c. Troca criptograficamente validada de Access Token Microsoft Entra ID (API TaskFlow)
  app.post('/auth/apoios-entra-exchange', async (req, res) => {
    try {
      const rateKey = `entra:${req.ip || 'ip'}`;
      if (!checkLoginRateLimit(rateKey)) {
        return res.status(429).json({
          ok: false,
          error: 'Muitas tentativas de autenticação Entra ID. Aguarde alguns minutos.',
        });
      }

      const expectedAudience = process.env.APOIOS_ENTRA_API_AUDIENCE;
      const tenantId =
        process.env.APOIOS_ENTRA_TENANT_ID || '8a0ffb54-9716-4a93-9158-9e3a7206f18e';
      if (!expectedAudience) {
        return res.status(503).json({
          ok: false,
          code: 'ENTRA_NOT_CONFIGURED',
          error:
            'Integração Entra ID para API de Apoios ainda não configurada no servidor (APOIOS_ENTRA_API_AUDIENCE ausente).',
        });
      }

      const authHeader = req.headers.authorization || '';
      const accessToken =
        (authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '') ||
        req.body?.entraAccessToken;
      if (!accessToken) {
        return res.status(400).json({
          ok: false,
          error: 'Access token Entra ID não informado.',
        });
      }

      let claims;
      try {
        claims = await verifyEntraJwtToken(accessToken, {
          tenantId,
          expectedAudience,
        });
      } catch (err) {
        return res.status(401).json({
          ok: false,
          code: 'ENTRA_TOKEN_INVALID',
          error: err.message,
        });
      }

      const emailClaim = (
        claims.preferred_username ||
        claims.upn ||
        claims.email ||
        claims.unique_name ||
        ''
      )
        .toString()
        .toLowerCase()
        .trim();
      if (!emailClaim) {
        return res.status(401).json({
          ok: false,
          code: 'ENTRA_IDENTITY_MISSING',
          error: 'Token Entra ID válido, porém sem claim de identidade corporativa.',
        });
      }

      const { data: usuario } = await supabase
        .from('usuarios')
        .select('id, email, nome, ativo, is_root')
        .eq('email', emailClaim)
        .eq('ativo', true)
        .maybeSingle();

      if (!usuario) {
        return res.status(403).json({
          ok: false,
          code: 'USER_NOT_ACTIVE',
          error: 'Identidade corporativa não possui usuário ativo cadastrado no TaskFlow.',
        });
      }

      const perfil = await loadUsuarioComPerfil(supabase, usuario.id);
      const token = signApoiosToken(usuario);
      return res.json({
        ok: true,
        token,
        expiresIn: TOKEN_TTL_SECONDS,
        usuario: perfil,
        entraOid: claims.oid || claims.sub || null,
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 3. Perfil autenticado atual
  app.get('/api/apoios/me', requireApoiosAuth, (req, res) => {
    res.json({ ok: true, usuario: req.apoiosUser });
  });

  // 4. Catálogo de tipos (por padrão apenas ativos; `?incluirInativos=true` para cadastros)
  app.get('/api/apoios/tipos', requireApoiosAuth, async (req, res) => {
    try {
      const incluirInativos = req.query.incluirInativos === 'true';
      let query = supabase
        .from('tasks_apoios_tipos')
        .select('*')
        .order('ordem', { ascending: true })
        .order('nome', { ascending: true });

      if (!incluirInativos) {
        query = query.eq('ativo', true);
      }

      const { data, error } = await query;
      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.json({ ok: true, data: data || [] });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 4b. Cadastro de tipos de apoio (criar / editar / excluir)
  function normalizarCodigoTipoApoio(raw) {
    return String(raw || '')
      .trim()
      .toUpperCase()
      .replace(/[^A-Z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 40);
  }

  app.post('/api/apoios/tipos', requireApoiosAuth, requireApoiosEditor, async (req, res) => {
    try {
      const body = req.body || {};
      const nome = String(body.nome || '').trim();
      const codigo = normalizarCodigoTipoApoio(body.codigo || nome);
      if (!nome) {
        return res.status(400).json({ ok: false, error: 'Nome do tipo de apoio é obrigatório.' });
      }
      if (!codigo) {
        return res.status(400).json({ ok: false, error: 'Código do tipo de apoio é obrigatório.' });
      }
      const payload = {
        codigo,
        nome,
        descricao: body.descricao != null ? String(body.descricao).trim() : null,
        icone: body.icone != null ? String(body.icone).trim() : null,
        ordem: Number.isFinite(Number(body.ordem)) ? Number(body.ordem) : 0,
        ativo: body.ativo !== false,
      };
      const { data, error } = await supabase
        .from('tasks_apoios_tipos')
        .insert(payload)
        .select('*')
        .single();
      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.status(201).json({ ok: true, data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  app.patch('/api/apoios/tipos/:id', requireApoiosAuth, requireApoiosEditor, async (req, res) => {
    try {
      const { id } = req.params;
      const body = req.body || {};
      const patch = { updated_at: new Date().toISOString() };
      if (body.nome !== undefined) {
        const nome = String(body.nome || '').trim();
        if (!nome) {
          return res.status(400).json({ ok: false, error: 'Nome do tipo de apoio é obrigatório.' });
        }
        patch.nome = nome;
      }
      if (body.codigo !== undefined) {
        const codigo = normalizarCodigoTipoApoio(body.codigo);
        if (!codigo) {
          return res.status(400).json({ ok: false, error: 'Código inválido.' });
        }
        patch.codigo = codigo;
      }
      if (body.descricao !== undefined) {
        patch.descricao = body.descricao != null ? String(body.descricao).trim() : null;
      }
      if (body.icone !== undefined) {
        patch.icone = body.icone != null ? String(body.icone).trim() : null;
      }
      if (body.ordem !== undefined && Number.isFinite(Number(body.ordem))) {
        patch.ordem = Number(body.ordem);
      }
      if (body.ativo !== undefined) {
        patch.ativo = Boolean(body.ativo);
      }
      const { data, error } = await supabase
        .from('tasks_apoios_tipos')
        .update(patch)
        .eq('id', id)
        .select('*')
        .single();
      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.json({ ok: true, data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  app.delete('/api/apoios/tipos/:id', requireApoiosAuth, requireApoiosEditor, async (req, res) => {
    try {
      const { id } = req.params;
      const { error } = await supabase
        .from('tasks_apoios_tipos')
        .delete()
        .eq('id', id);
      if (error) {
        if (String(error.code) === '23503') {
          return res.status(409).json({
            ok: false,
            error: 'Este tipo já está vinculado a solicitações. Inative-o em vez de excluir.',
          });
        }
        return res.status(400).json({ ok: false, error: error.message });
      }
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 5. Resumos em lote por taskIds (sem consultas N+1)
  app.get('/api/apoios/resumos', requireApoiosAuth, async (req, res) => {
    try {
      const rawIds = String(req.query.taskIds || '').trim();
      if (!rawIds) {
        return res.json({ ok: true, data: {} });
      }
      const taskIds = rawIds
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
        .slice(0, 200);

      if (taskIds.length === 0) {
        return res.json({ ok: true, data: {} });
      }

      const { data: solData, error: solError } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .in('task_solicitante_id', taskIds);

      if (solError) {
        return res.status(400).json({ ok: false, error: solError.message });
      }

      const { data: vincComoApoio, error: vincError } = await supabase
        .from('tasks_apoios_vinculos')
        .select('*')
        .in('task_apoio_id', taskIds)
        .eq('ativo', true);

      if (vincError) {
        return res.status(400).json({ ok: false, error: vincError.message });
      }

      const solVisiveis = (solData || []).filter((s) =>
        usuarioPodeVerSolicitacao(req.apoiosUser, s)
      );
      const enriquecidas = await enrichSolicitacoes(supabase, solVisiveis);

      return res.json({
        ok: true,
        data: {
          solicitacoes: enriquecidas,
          vinculosComoApoio: vincComoApoio || [],
        },
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 6. Buscar solicitações com filtros e escopo organizacional
  app.get('/api/apoios/solicitacoes', requireApoiosAuth, async (req, res) => {
    try {
      const {
        taskId,
        divisaoSolicitanteId,
        divisaoDestinoId,
        status,
        limit = '100',
        offset = '0',
      } = req.query;

      let query = supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .order('created_at', { ascending: false });

      if (taskId) query = query.eq('task_solicitante_id', String(taskId));
      if (divisaoSolicitanteId) {
        query = query.eq('divisao_solicitante_id', String(divisaoSolicitanteId));
      }
      if (divisaoDestinoId) {
        query = query.eq('divisao_destino_id', String(divisaoDestinoId));
      }
      if (status) {
        query = query.eq('status', String(status));
      }

      const lim = Math.min(Math.max(parseInt(limit, 10) || 100, 1), 200);
      const off = Math.max(parseInt(offset, 10) || 0, 0);
      query = query.range(off, off + lim - 1);

      const { data, error } = await query;
      if (error) return res.status(400).json({ ok: false, error: error.message });

      const visiveis = (data || []).filter((s) =>
        usuarioPodeVerSolicitacao(req.apoiosUser, s)
      );
      const enriquecidas = await enrichSolicitacoes(supabase, visiveis);

      return res.json({ ok: true, data: enriquecidas });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 7. Buscar solicitação por ID
  app.get('/api/apoios/solicitacoes/:id', requireApoiosAuth, async (req, res) => {
    try {
      const { id } = req.params;
      const { data, error } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (error) return res.status(400).json({ ok: false, error: error.message });
      if (!data) return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });
      if (!usuarioPodeVerSolicitacao(req.apoiosUser, data)) {
        return res.status(403).json({
          ok: false,
          error: 'Sem permissão organizacional para visualizar esta solicitação.',
        });
      }

      const [enriquecida] = await enrichSolicitacoes(supabase, [data]);
      return res.json({ ok: true, data: enriquecida });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 8. Criar solicitação (+ períodos)
  app.post('/api/apoios/solicitacoes', requireApoiosAuth, requireApoiosEditor, async (req, res) => {
    try {
      const body = req.body || {};
      const solicitacao = body.solicitacao || body;
      const periodos = Array.isArray(body.periodos)
        ? body.periodos
        : Array.isArray(solicitacao.periodos)
        ? solicitacao.periodos
        : [];

      if (
        !solicitacao.segmento_destino_id ||
        String(solicitacao.segmento_destino_id).trim() === ''
      ) {
        return res.status(400).json({
          ok: false,
          error: 'Segmento de destino é obrigatório.',
        });
      }

      if (
        !usuarioPertenceUnidade(req.apoiosUser, {
          regionalId: solicitacao.regional_solicitante_id,
          divisaoId: solicitacao.divisao_solicitante_id,
          segmentoId: solicitacao.segmento_solicitante_id,
        })
      ) {
        return res.status(403).json({
          ok: false,
          error: 'Usuário não pertence à unidade solicitante informada.',
        });
      }

      const isUuid = (v) =>
        typeof v === 'string' &&
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);

      const payloadInsert = {
        ...solicitacao,
        solicitante_usuario_id: req.apoiosUser.id,
      };
      if (!isUuid(payloadInsert.id)) delete payloadInsert.id;
      if (!isUuid(payloadInsert.segmento_solicitante_id)) delete payloadInsert.segmento_solicitante_id;
      if (!isUuid(payloadInsert.segmento_destino_id)) delete payloadInsert.segmento_destino_id;
      if (!isUuid(payloadInsert.task_solicitante_id)) delete payloadInsert.task_solicitante_id;
      delete payloadInsert.atualizado_por_usuario_id;
      delete payloadInsert.periodos;
      delete payloadInsert.vinculos;
      delete payloadInsert.historico;
      delete payloadInsert.situacao;

      const { data: criada, error } = await supabase
        .from('tasks_apoios_solicitacoes')
        .insert(payloadInsert)
        .select('*')
        .single();

      if (error) {
        return res.status(400).json({ ok: false, error: error.message });
      }

      if (periodos.length > 0) {
        const periodosInsert = periodos.map((p) => {
          const item = {
            ...p,
            solicitacao_id: criada.id,
          };
          if (!isUuid(item.id)) delete item.id;
          delete item.ordem;
          return item;
        });
        const { error: perErr } = await supabase
          .from('tasks_apoios_solicitacoes_periodos')
          .insert(periodosInsert);

        if (perErr) {
          return res.status(400).json({ ok: false, error: perErr.message });
        }
      }

      const [enriquecida] = await enrichSolicitacoes(supabase, [criada]);
      await enqueueOutboxEvent(supabase, {
        eventoTipo: 'SOLICITACAO_CRIADA',
        entidadeTipo: 'SOLICITACAO',
        entidadeId: criada.id,
        solicitacaoId: criada.id,
        taskId: criada.task_solicitante_id,
        payload: {
          ator_usuario_id: req.apoiosUser.id,
          ator_nome: req.apoiosUser.nome || req.apoiosUser.email,
        },
        idempotencyKey: `SOL_CRIADA:${criada.id}:v${criada.versao || 1}`,
      });
      setImmediate(() => notifWorker.processOutboxQueue().catch(() => {}));
      return res.status(201).json({ ok: true, data: enriquecida });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 9. Atualizar solicitação (transição de status / contraproposta / edição)
  async function handleAtualizarSolicitacao(req, res) {
    try {
      const { id } = req.params;
      const body = req.body || {};
      const solicitacaoPatch = body.solicitacao || body;

      const { data: atual, error: fetchErr } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (fetchErr) return res.status(400).json({ ok: false, error: fetchErr.message });
      if (!atual) return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });

      const ehSolicitante = usuarioPertenceUnidade(req.apoiosUser, {
        regionalId: atual.regional_solicitante_id,
        divisaoId: atual.divisao_solicitante_id,
        segmentoId: atual.segmento_solicitante_id,
      });
      const ehDestino = usuarioPertenceUnidade(req.apoiosUser, {
        regionalId: atual.regional_destino_id,
        divisaoId: atual.divisao_destino_id,
        segmentoId: atual.segmento_destino_id,
      });

      if (!req.apoiosUser.isRoot && !ehSolicitante && !ehDestino) {
        return res.status(403).json({
          ok: false,
          error: 'Sem permissão organizacional para alterar esta solicitação.',
        });
      }

      const novoStatus = solicitacaoPatch.status;
      if (
        !req.apoiosUser.isRoot &&
        novoStatus &&
        ['ACEITA', 'RECUSADA', 'CONTRAPROPOSTA', 'EM_ANALISE'].includes(novoStatus) &&
        !ehDestino
      ) {
        return res.status(403).json({
          ok: false,
          error: 'Apenas a unidade prestadora de destino pode responder à solicitação.',
        });
      }

      const updateFields = { ...solicitacaoPatch };
      delete updateFields.id;
      delete updateFields.periodos;
      delete updateFields.vinculos;
      delete updateFields.historico;
      delete updateFields.situacao;
      delete updateFields.created_at;
      delete updateFields.updated_at;
      delete updateFields.atualizado_por_usuario_id;
      delete updateFields.respondido_por_usuario_id;
      if (novoStatus === 'ACEITA' || novoStatus === 'RECUSADA' || novoStatus === 'CONTRAPROPOSTA') {
        updateFields.responsavel_atendimento_id = req.apoiosUser.id;
      }
      if (novoStatus === 'CANCELADA') {
        updateFields.cancelado_por = req.apoiosUser.id;
      }

      const versaoEsperada =
        solicitacaoPatch.versao ?? body.versaoEsperada ?? atual.versao;

      const { data: updated, error: updErr } = await supabase
        .from('tasks_apoios_solicitacoes')
        .update({ ...updateFields, versao: versaoEsperada })
        .eq('id', id)
        .select('*')
        .single();

      if (updErr) {
        const statusCode = updErr.message.includes('Conflito de versão') ? 409 : 400;
        return res.status(statusCode).json({ ok: false, error: updErr.message });
      }

      const [enriquecida] = await enrichSolicitacoes(supabase, [updated]);
      const eventoMap = {
        EM_ANALISE: 'SOLICITACAO_EM_ANALISE',
        ACEITA:
          atual.status === 'CONTRAPROPOSTA'
            ? 'CONTRAPROPOSTA_ACEITA'
            : 'SOLICITACAO_ACEITA',
        RECUSADA: 'SOLICITACAO_RECUSADA',
        CONTRAPROPOSTA: 'CONTRAPROPOSTA_ENVIADA',
        CANCELADA: 'SOLICITACAO_CANCELADA',
      };
      const eventoTipo = eventoMap[updated.status];
      if (eventoTipo && updated.status !== atual.status) {
        if (['ACEITA', 'RECUSADA', 'CONTRAPROPOSTA', 'CANCELADA', 'CONCLUIDA'].includes(updated.status)) {
          const { data: notifIds } = await supabase
            .from('notificacoes_internas')
            .select('id')
            .eq('solicitacao_id', updated.id)
            .in('evento_tipo', [
              'SOLICITACAO_CRIADA',
              'CONTRAPROPOSTA_ENVIADA',
              'RECONFIRMACAO_SOLICITADA',
              'ALERTA_PRAZO_APOIO',
            ]);
          const ids = (notifIds || []).map((r) => r.id).filter(Boolean);
          if (ids.length > 0) {
            await supabase
              .from('notificacoes_destinatarios')
              .update({ lida: true, lida_em: new Date().toISOString() })
              .in('notificacao_id', ids)
              .eq('lida', false);
          }
        }
        await enqueueOutboxEvent(supabase, {
          eventoTipo,
          entidadeTipo: 'SOLICITACAO',
          entidadeId: updated.id,
          solicitacaoId: updated.id,
          taskId: updated.task_solicitante_id,
          payload: {
            ator_usuario_id: req.apoiosUser.id,
            ator_nome: req.apoiosUser.nome || req.apoiosUser.email,
            status_anterior: atual.status,
            status_novo: updated.status,
            justificativa: updated.justificativa_decisao || null,
          },
          idempotencyKey: `SOL_STATUS:${updated.id}:${updated.status}:v${updated.versao}`,
        });
        setImmediate(() => notifWorker.processOutboxQueue().catch(() => {}));
      }
      return res.json({ ok: true, data: enriquecida });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  }

  app.patch('/api/apoios/solicitacoes/:id', requireApoiosAuth, requireApoiosEditor, handleAtualizarSolicitacao);
  app.put('/api/apoios/solicitacoes/:id', requireApoiosAuth, requireApoiosEditor, handleAtualizarSolicitacao);

  // 10. Buscar vínculos por taskId
  app.get('/api/apoios/vinculos/task/:taskId', requireApoiosAuth, async (req, res) => {
    try {
      const { taskId } = req.params;
      const { data, error } = await supabase
        .from('tasks_apoios_vinculos')
        .select('*')
        .or(`task_principal_id.eq.${taskId},task_apoio_id.eq.${taskId}`)
        .order('created_at', { ascending: false });

      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.json({ ok: true, data: data || [] });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 11. Criar vínculo definitivo
  app.post('/api/apoios/vinculos', requireApoiosAuth, requireApoiosEditor, async (req, res) => {
    try {
      const vinculo = req.body?.vinculo || req.body || {};
      if (vinculo.solicitacao_id) {
        const { data: sol } = await supabase
          .from('tasks_apoios_solicitacoes')
          .select('*')
          .eq('id', vinculo.solicitacao_id)
          .maybeSingle();

        if (!sol) {
          return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });
        }

        const ehDestino = usuarioPertenceUnidade(req.apoiosUser, {
          regionalId: sol.regional_destino_id,
          divisaoId: sol.divisao_destino_id,
          segmentoId: sol.segmento_destino_id,
        });
        if (!req.apoiosUser.isRoot && !ehDestino) {
          return res.status(403).json({
            ok: false,
            error: 'Apenas a unidade prestadora de destino pode vincular a atividade de apoio.',
          });
        }
      }

      const payloadInsert = {
        ...vinculo,
        created_by: req.apoiosUser.id,
      };
      delete payloadInsert.vinculado_por_usuario_id;

      const { data, error } = await supabase
        .from('tasks_apoios_vinculos')
        .insert(payloadInsert)
        .select('*')
        .single();

      if (error) return res.status(400).json({ ok: false, error: error.message });
      if (data?.solicitacao_id) {
        await enqueueOutboxEvent(supabase, {
          eventoTipo: 'VINCULO_CRIADO',
          entidadeTipo: 'VINCULO',
          entidadeId: data.id,
          solicitacaoId: data.solicitacao_id,
          taskId: data.task_apoio_id,
          payload: {
            ator_usuario_id: req.apoiosUser.id,
            ator_nome: req.apoiosUser.nome || req.apoiosUser.email,
          },
          idempotencyKey: `VINC_CRIADO:${data.id}:v${data.versao || 1}`,
        });
        setImmediate(() => notifWorker.processOutboxQueue().catch(() => {}));
      }
      return res.status(201).json({ ok: true, data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 12. Atualizar/desativar vínculo
  async function handleAtualizarVinculo(req, res) {
    try {
      const { id } = req.params;
      const patch = req.body?.vinculo || req.body || {};

      const { data: atual } = await supabase
        .from('tasks_apoios_vinculos')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (!atual) {
        return res.status(404).json({ ok: false, error: 'Vínculo não encontrado.' });
      }

      const updateFields = { ...patch };
      delete updateFields.id;
      delete updateFields.created_at;
      delete updateFields.updated_at;
      delete updateFields.desativado_por_usuario_id;
      if (updateFields.ativo === false) {
        updateFields.desativado_por = req.apoiosUser.id;
      }
      if (updateFields.status_confirmacao) {
        const novoStatusConf = String(updateFields.status_confirmacao).toUpperCase();
        if (!['AGUARDANDO_CONFIRMACAO', 'CONFIRMADO', 'RECUSADO', 'CANCELADO'].includes(novoStatusConf)) {
          return res.status(400).json({ ok: false, error: 'status_confirmacao inválido.' });
        }
        updateFields.status_confirmacao = novoStatusConf;
        if (novoStatusConf === 'CONFIRMADO' || novoStatusConf === 'RECUSADO') {
          updateFields.confirmado_por = req.apoiosUser.id;
          updateFields.confirmado_em = new Date().toISOString();
        }
      }

      const { data, error } = await supabase
        .from('tasks_apoios_vinculos')
        .update({ ...updateFields, versao: patch.versao ?? atual.versao })
        .eq('id', id)
        .select('*')
        .single();

      if (error) {
        const code = error.message.includes('Conflito de versão') ? 409 : 400;
        return res.status(code).json({ ok: false, error: error.message });
      }
      if (data?.ativo === false && data?.solicitacao_id) {
        await enqueueOutboxEvent(supabase, {
          eventoTipo: 'VINCULO_DESATIVADO',
          entidadeTipo: 'VINCULO',
          entidadeId: data.id,
          solicitacaoId: data.solicitacao_id,
          taskId: data.task_apoio_id,
          payload: {
            ator_usuario_id: req.apoiosUser.id,
            ator_nome: req.apoiosUser.nome || req.apoiosUser.email,
            motivo: data.motivo_desativacao || null,
          },
          idempotencyKey: `VINC_DESAT:${data.id}:v${data.versao}`,
        });
        setImmediate(() => notifWorker.processOutboxQueue().catch(() => {}));
      }
      return res.json({ ok: true, data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  }

  app.patch('/api/apoios/vinculos/:id', requireApoiosAuth, requireApoiosEditor, handleAtualizarVinculo);
  app.put('/api/apoios/vinculos/:id', requireApoiosAuth, requireApoiosEditor, handleAtualizarVinculo);

  // 13. Histórico de uma solicitação
  app.get('/api/apoios/historico/:solicitacaoId', requireApoiosAuth, async (req, res) => {
    try {
      const { solicitacaoId } = req.params;
      const { data: sol } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('id', solicitacaoId)
        .maybeSingle();

      if (!sol) return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });
      if (!usuarioPodeVerSolicitacao(req.apoiosUser, sol)) {
        return res.status(403).json({ ok: false, error: 'Sem permissão organizacional.' });
      }

      const { data, error } = await supabase
        .from('tasks_apoios_historico')
        .select('*')
        .eq('solicitacao_id', solicitacaoId)
        .order('created_at', { ascending: false });

      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.json({ ok: true, data: data || [] });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 14. Criar atividade de apoio na tabela tasks e vincular automaticamente à solicitação
  app.post('/api/apoios/atividades-apoio', requireApoiosAuth, requireApoiosEditor, async (req, res) => {
    try {
      const { solicitacaoId, task, idempotencyKey } = req.body || {};
      const tarefaTitulo = task?.tarefa || task?.title;
      const dataInicio = task?.data_inicio || task?.start_date;
      const dataFim = task?.data_fim || task?.end_date;

      if (!task || !tarefaTitulo || !dataInicio || !dataFim) {
        return res.status(400).json({
          ok: false,
          error: 'Informe tarefa (ou title), data_inicio e data_fim da atividade de apoio.',
        });
      }

      const effectiveIdempotencyKey =
        (idempotencyKey && String(idempotencyKey).trim()) ||
        (task.id && solicitacaoId ? `ATIV_APOIO:${solicitacaoId}:${task.id}` : null);

      if (effectiveIdempotencyKey) {
        const { data: existingVinc } = await supabase
          .from('tasks_apoios_vinculos')
          .select('*')
          .eq('idempotency_key', effectiveIdempotencyKey)
          .maybeSingle();
        if (existingVinc) {
          const { data: existingTask } = await supabase
            .from('tasks')
            .select('*')
            .eq('id', existingVinc.task_apoio_id)
            .maybeSingle();
          return res.status(200).json({
            ok: true,
            idempotent: true,
            data: {
              task: existingTask || null,
              vinculo: existingVinc,
            },
          });
        }
      }

      let sol = null;
      if (solicitacaoId) {
        const { data } = await supabase
          .from('tasks_apoios_solicitacoes')
          .select('*')
          .eq('id', solicitacaoId)
          .maybeSingle();
        sol = data;
        if (!sol) {
          return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });
        }
        const ehDestino = usuarioPertenceUnidade(req.apoiosUser, {
          regionalId: sol.regional_destino_id,
          divisaoId: sol.divisao_destino_id,
          segmentoId: sol.segmento_destino_id,
        });
        if (!req.apoiosUser.isRoot && !ehDestino) {
          return res.status(403).json({
            ok: false,
            error: 'Apenas a unidade prestadora de destino pode criar a atividade de apoio.',
          });
        }
      }

      const regId = task.regional_id || sol?.regional_destino_id || null;
      const divId = task.divisao_id || sol?.divisao_destino_id || null;
      let regionalNome = task.regional;
      let divisaoNome = task.divisao;
      if (!regionalNome && regId) {
        const { data: rRow } = await supabase
          .from('regionais')
          .select('*')
          .eq('id', regId)
          .maybeSingle();
        regionalNome = rRow?.nome || rRow?.sigla || rRow?.regional || 'Regional';
      }
      if (!divisaoNome && divId) {
        const { data: dRow } = await supabase
          .from('divisoes')
          .select('*')
          .eq('id', divId)
          .maybeSingle();
        divisaoNome = dRow?.nome || dRow?.sigla || dRow?.divisao || 'Divisão';
      }

      const taskId = task.id || crypto.randomUUID();
      const taskPayload = {
        id: taskId,
        tarefa: String(tarefaTitulo),
        observacoes: task.observacoes || task.description || null,
        data_inicio: dataInicio,
        data_fim: dataFim,
        status: task.status || 'PROG',
        tipo: task.tipo || 'Apoio Operacional',
        coordenador: task.coordenador || req.apoiosUser.nome || req.apoiosUser.email,
        executor: task.executor || 'A definir',
        regional: regionalNome || 'Regional',
        divisao: divisaoNome || 'Divisão',
        local: task.local || sol?.locais_atendimento || 'A definir',
        regional_id: regId,
        divisao_id: divId,
        segmento_id: task.segmento_id || sol?.segmento_destino_id || null,
      };

      const { data: createdTask, error: taskErr } = await supabase
        .from('tasks')
        .insert(taskPayload)
        .select('*')
        .single();

      if (taskErr) {
        return res.status(400).json({ ok: false, error: taskErr.message });
      }

      let createdVinculo = null;
      if (sol) {
        const vinculoPayload = {
          ...(effectiveIdempotencyKey ? { idempotency_key: effectiveIdempotencyKey } : {}),
          solicitacao_id: sol.id,
          task_principal_id: sol.task_solicitante_id,
          task_apoio_id: createdTask.id,
          task_principal_titulo_snapshot: sol.task_solicitante_titulo_snapshot,
          task_apoio_titulo_snapshot: createdTask.tarefa,
          tipo_apoio_id: sol.tipo_apoio_id,
          finalidade: 'APOIO_OPERACIONAL',
          cobertura_inicio: createdTask.data_inicio,
          cobertura_fim: createdTask.data_fim,
          status_confirmacao: 'CONFIRMADO',
          confirmado_por: req.apoiosUser.id,
          confirmado_em: new Date().toISOString(),
          ativo: true,
          created_by: req.apoiosUser.id,
        };
        const { data: vinc, error: vincErr } = await supabase
          .from('tasks_apoios_vinculos')
          .insert(vinculoPayload)
          .select('*')
          .single();

        if (vincErr) {
          // Compensação transacional: evita atividade órfã em caso de falha ao vincular
          await supabase.from('tasks').delete().eq('id', createdTask.id);
          return res.status(400).json({ ok: false, error: vincErr.message });
        }
        createdVinculo = vinc;
        await enqueueOutboxEvent(supabase, {
          eventoTipo: 'ATIVIDADE_APOIO_CRIADA',
          entidadeTipo: 'VINCULO',
          entidadeId: vinc.id,
          solicitacaoId: sol.id,
          taskId: createdTask.id,
          payload: {
            ator_usuario_id: req.apoiosUser.id,
            ator_nome: req.apoiosUser.nome || req.apoiosUser.email,
            tarefa: createdTask.tarefa,
          },
          idempotencyKey: `APOIO_TASK_CRIADA:${vinc.id}:v1`,
        });
        setImmediate(() => notifWorker.processOutboxQueue().catch(() => {}));
      }

      return res.status(201).json({
        ok: true,
        data: {
          task: createdTask,
          vinculo: createdVinculo,
        },
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 15. Notificações internas paginadas do usuário autenticado
  app.get('/api/apoios/notificacoes', requireApoiosAuth, async (req, res) => {
    try {
      const {
        apenasNaoLidas,
        categoria,
        modulo = 'APOIOS_OPERACIONAIS',
        limit = '30',
        offset = '0',
      } = req.query;
      const lim = Math.min(Math.max(parseInt(limit, 10) || 30, 1), 100);
      const off = Math.max(parseInt(offset, 10) || 0, 0);

      await sincronizarNotificacoesUnidadeUsuario(supabase, req.apoiosUser);

      const fetchLimit = Math.min(Math.max((off + lim) * 4, 100), 400);
      let query = supabase
        .from('notificacoes_destinatarios')
        .select('id, lida, lida_em, created_at, notificacao:notificacoes_internas!inner(*)')
        .eq('usuario_id', req.apoiosUser.id)
        .eq('arquivada', false)
        .eq('notificacao.modulo', String(modulo))
        .order('created_at', { ascending: false })
        .range(0, fetchLimit - 1);

      if (apenasNaoLidas === 'true') {
        query = query.eq('lida', false);
      }
      if (categoria) {
        query = query.eq('notificacao.categoria', String(categoria));
      }

      const { data, error } = await query;
      if (error) return res.status(400).json({ ok: false, error: error.message });

      const filtrados = await filtrarNotificacoesPorPerfilAtual(
        supabase,
        req.apoiosUser,
        data || []
      );

      const items = filtrados.slice(off, off + lim).map((row) => ({
        destinatario_id: row.id,
        lida: Boolean(row.lida),
        lida_em: row.lida_em,
        ...(row.notificacao || {}),
      }));
      return res.json({ ok: true, data: items });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  async function sincronizarNotificacoesUnidadeUsuario(supabase, perfil) {
    try {
      if (!perfil || perfil.isRoot) return;
      if (!perfil.segmentoIds || perfil.segmentoIds.length === 0) return;

      const { data: sols } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select(
          'id, solicitante_usuario_id, regional_solicitante_id, divisao_solicitante_id, segmento_solicitante_id, regional_destino_id, divisao_destino_id, segmento_destino_id, status'
        )
        .in('segmento_destino_id', perfil.segmentoIds)
        .in('status', ['PENDENTE', 'EM_ANALISE', 'CONTRAPROPOSTA']);

      const solsDestino = (sols || []).filter((s) => {
        const ehDestino = usuarioPertenceUnidade(perfil, {
          regionalId: s.regional_destino_id,
          divisaoId: s.divisao_destino_id,
          segmentoId: s.segmento_destino_id,
        });
        if (!ehDestino) return false;
        if (s.solicitante_usuario_id && s.solicitante_usuario_id === perfil.id) {
          const aindaNaOrigem = usuarioPertenceUnidade(perfil, {
            regionalId: s.regional_solicitante_id,
            divisaoId: s.divisao_solicitante_id,
            segmentoId: s.segmento_solicitante_id,
          });
          if (aindaNaOrigem) return false;
        }
        return true;
      });

      if (solsDestino.length === 0) return;
      const solIds = solsDestino.map((s) => s.id);

      const { data: notifs } = await supabase
        .from('notificacoes_internas')
        .select('id, solicitacao_id, created_at')
        .in('solicitacao_id', solIds)
        .in('evento_tipo', [
          'SOLICITACAO_CRIADA',
          'SOLICITACAO_EM_ANALISE',
          'CONTRAPROPOSTA_ENVIADA',
          'SOLICITACAO_REABERTA',
        ])
        .order('created_at', { ascending: false });

      if (!notifs || notifs.length === 0) return;
      const notifIds = notifs.map((n) => n.id);

      const { data: existentes } = await supabase
        .from('notificacoes_destinatarios')
        .select('notificacao_id')
        .eq('usuario_id', perfil.id)
        .in('notificacao_id', notifIds);

      const existentesSet = new Set((existentes || []).map((e) => e.notificacao_id));
      const faltantes = notifIds
        .filter((id) => !existentesSet.has(id))
        .map((notificacaoId) => ({
          notificacao_id: notificacaoId,
          usuario_id: perfil.id,
          lida: false,
          arquivada: false,
        }));

      if (faltantes.length > 0) {
        await supabase.from('notificacoes_destinatarios').upsert(faltantes, {
          onConflict: 'notificacao_id,usuario_id',
          ignoreDuplicates: true,
        });
      }
    } catch (_) {
      // Falha não bloqueante na sincronização sob demanda
    }
  }

  async function filtrarNotificacoesPorPerfilAtual(supabase, perfil, rows) {
    if (!rows || rows.length === 0) return [];
    if (perfil.isRoot) return rows;
    const solIds = Array.from(
      new Set(
        rows
          .map((r) => r.notificacao?.solicitacao_id)
          .filter(Boolean)
      )
    );
    if (solIds.length === 0) return rows;

    const { data: sols } = await supabase
      .from('tasks_apoios_solicitacoes')
      .select(
        'id, regional_solicitante_id, divisao_solicitante_id, segmento_solicitante_id, regional_destino_id, divisao_destino_id, segmento_destino_id'
      )
      .in('id', solIds);

    const solMap = new Map((sols || []).map((s) => [s.id, s]));
    const visiveis = rows.filter((row) => {
      const solId = row.notificacao?.solicitacao_id;
      if (!solId) return true;
      const sol = solMap.get(solId);
      if (!sol) return false;
      const ehOrigem = usuarioPertenceUnidade(perfil, {
        regionalId: sol.regional_solicitante_id,
        divisaoId: sol.divisao_solicitante_id,
        segmentoId: sol.segmento_solicitante_id,
      });
      const ehDestino = usuarioPertenceUnidade(perfil, {
        regionalId: sol.regional_destino_id,
        divisaoId: sol.divisao_destino_id,
        segmentoId: sol.segmento_destino_id,
      });
      return ehOrigem || ehDestino;
    });

    // Mantém apenas a notificação mais recente por solicitação para evitar
    // cartões aparentemente duplicados com o mesmo status atual.
    const vistasPorSolicitacao = new Set();
    return visiveis.filter((row) => {
      const solId = row.notificacao?.solicitacao_id;
      if (!solId) return true;
      if (vistasPorSolicitacao.has(solId)) return false;
      vistasPorSolicitacao.add(solId);
      return true;
    });
  }

  // 16. Contador rápido de notificações não lidas
  app.get('/api/apoios/notificacoes/contador', requireApoiosAuth, async (req, res) => {
    try {
      await sincronizarNotificacoesUnidadeUsuario(supabase, req.apoiosUser);
      const { data, error } = await supabase
        .from('notificacoes_destinatarios')
        .select('id, lida, notificacao:notificacoes_internas!inner(solicitacao_id)')
        .eq('usuario_id', req.apoiosUser.id)
        .eq('arquivada', false)
        .order('created_at', { ascending: false })
        .limit(400);

      if (error) return res.status(400).json({ ok: false, error: error.message });
      const filtrados = await filtrarNotificacoesPorPerfilAtual(
        supabase,
        req.apoiosUser,
        data || []
      );
      const naoLidas = filtrados.filter((r) => !r.lida).length;
      return res.json({ ok: true, data: { naoLidas } });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 17. Marcar notificação individual como lida (mantém pendentes solicitações ainda sem decisão)
  async function handleMarcarLida(req, res) {
    try {
      const { id } = req.params;
      const { data: notifInfo } = await supabase
        .from('notificacoes_internas')
        .select('id, evento_tipo, solicitacao_id')
        .eq('id', id)
        .maybeSingle();

      if (
        notifInfo?.solicitacao_id &&
        ['SOLICITACAO_CRIADA', 'CONTRAPROPOSTA_ENVIADA', 'RECONFIRMACAO_SOLICITADA'].includes(
          notifInfo.evento_tipo
        )
      ) {
        const { data: solAtual } = await supabase
          .from('tasks_apoios_solicitacoes')
          .select('status')
          .eq('id', notifInfo.solicitacao_id)
          .maybeSingle();
        if (solAtual && ['PENDENTE', 'EM_ANALISE', 'CONTRAPROPOSTA'].includes(solAtual.status)) {
          return res.json({
            ok: true,
            preservedPending: true,
            data: { notificacao_id: id, lida: false, lida_em: null },
          });
        }
      }

      const nowIso = new Date().toISOString();
      const { data, error } = await supabase
        .from('notificacoes_destinatarios')
        .update({ lida: true, lida_em: nowIso })
        .eq('notificacao_id', id)
        .eq('usuario_id', req.apoiosUser.id)
        .select('id, lida, lida_em')
        .maybeSingle();

      if (error) return res.status(400).json({ ok: false, error: error.message });
      if (!data) return res.status(404).json({ ok: false, error: 'Notificação não encontrada.' });

      if (notifInfo?.solicitacao_id) {
        const { data: irmas } = await supabase
          .from('notificacoes_internas')
          .select('id')
          .eq('solicitacao_id', notifInfo.solicitacao_id);
        const irmasIds = (irmas || []).map((r) => r.id).filter((nid) => nid && nid !== id);
        if (irmasIds.length > 0) {
          await supabase
            .from('notificacoes_destinatarios')
            .update({ lida: true, lida_em: nowIso })
            .eq('usuario_id', req.apoiosUser.id)
            .in('notificacao_id', irmasIds)
            .eq('lida', false);
        }
      }

      return res.json({ ok: true, data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  }
  app.patch('/api/apoios/notificacoes/:id/lida', requireApoiosAuth, handleMarcarLida);
  app.put('/api/apoios/notificacoes/:id/lida', requireApoiosAuth, handleMarcarLida);

  // 18. Marcar notificações informativas como lidas (preserva solicitações aguardando decisão)
  app.post('/api/apoios/notificacoes/marcar-todas-lidas', requireApoiosAuth, async (req, res) => {
    try {
      const { data: pendentes } = await supabase
        .from('notificacoes_destinatarios')
        .select('id, notificacao:notificacoes_internas!inner(id, evento_tipo, solicitacao_id)')
        .eq('usuario_id', req.apoiosUser.id)
        .eq('lida', false);

      const idsParaMarcar = [];
      const solIds = Array.from(
        new Set(
          (pendentes || [])
            .map((p) => p.notificacao?.solicitacao_id)
            .filter(Boolean)
        )
      );
      const solStatusMap = new Map();
      if (solIds.length > 0) {
        const { data: sols } = await supabase
          .from('tasks_apoios_solicitacoes')
          .select('id, status')
          .in('id', solIds);
        for (const s of sols || []) solStatusMap.set(s.id, s.status);
      }

      for (const item of pendentes || []) {
        const n = item.notificacao;
        const exigeAcao =
          n?.solicitacao_id &&
          ['SOLICITACAO_CRIADA', 'CONTRAPROPOSTA_ENVIADA', 'RECONFIRMACAO_SOLICITADA'].includes(
            n.evento_tipo
          ) &&
          ['PENDENTE', 'EM_ANALISE', 'CONTRAPROPOSTA'].includes(
            solStatusMap.get(n.solicitacao_id)
          );
        if (!exigeAcao) idsParaMarcar.push(item.id);
      }

      if (idsParaMarcar.length > 0) {
        const { error } = await supabase
          .from('notificacoes_destinatarios')
          .update({ lida: true, lida_em: new Date().toISOString() })
          .in('id', idsParaMarcar);
        if (error) return res.status(400).json({ ok: false, error: error.message });
      }
      return res.json({ ok: true, marcadas: idsParaMarcar.length });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 19. Preferências individuais de notificação
  app.get('/api/apoios/preferencias', requireApoiosAuth, async (req, res) => {
    try {
      const { data, error } = await supabase
        .from('notificacoes_preferencias')
        .select('*')
        .eq('escopo', 'USUARIO')
        .eq('usuario_id', req.apoiosUser.id)
        .eq('modulo', 'APOIOS_OPERACIONAIS')
        .maybeSingle();

      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.json({
        ok: true,
        data: data || {
          escopo: 'USUARIO',
          usuario_id: req.apoiosUser.id,
          modulo: 'APOIOS_OPERACIONAIS',
          receber_interna: true,
          receber_telegram: true,
          eventos_habilitados: ['ALL'],
          antecedencias_dias: [7, 3, 1, 0],
        },
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  app.put('/api/apoios/preferencias', requireApoiosAuth, async (req, res) => {
    try {
      const body = req.body || {};
      const payload = {
        escopo: 'USUARIO',
        usuario_id: req.apoiosUser.id,
        modulo: 'APOIOS_OPERACIONAIS',
        receber_interna: body.receber_interna !== false,
        receber_telegram: body.receber_telegram !== false,
        eventos_habilitados: Array.isArray(body.eventos_habilitados)
          ? body.eventos_habilitados
          : ['ALL'],
        antecedencias_dias: Array.isArray(body.antecedencias_dias)
          ? body.antecedencias_dias
          : [7, 3, 1, 0],
        updated_at: new Date().toISOString(),
      };

      const { data: existing } = await supabase
        .from('notificacoes_preferencias')
        .select('id')
        .eq('escopo', 'USUARIO')
        .eq('usuario_id', req.apoiosUser.id)
        .eq('modulo', 'APOIOS_OPERACIONAIS')
        .maybeSingle();

      let result;
      if (existing?.id) {
        result = await supabase
          .from('notificacoes_preferencias')
          .update(payload)
          .eq('id', existing.id)
          .select('*')
          .single();
      } else {
        result = await supabase
          .from('notificacoes_preferencias')
          .insert(payload)
          .select('*')
          .single();
      }

      if (result.error) return res.status(400).json({ ok: false, error: result.error.message });
      return res.json({ ok: true, data: result.data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 20. Conversa operacional vinculada à solicitação (isolada às unidades participantes)
  app.get('/api/apoios/solicitacoes/:id/mensagens', requireApoiosAuth, async (req, res) => {
    try {
      const { id } = req.params;
      const { data: sol } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (!sol) return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });
      if (!usuarioPodeVerSolicitacao(req.apoiosUser, sol)) {
        return res.status(403).json({ ok: false, error: 'Sem permissão organizacional.' });
      }

      const { data, error } = await supabase
        .from('tasks_apoios_mensagens')
        .select('*')
        .eq('solicitacao_id', id)
        .order('created_at', { ascending: true });

      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.json({ ok: true, data: data || [] });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  app.post('/api/apoios/solicitacoes/:id/mensagens', requireApoiosAuth, async (req, res) => {
    try {
      const { id } = req.params;
      const texto = String(req.body?.mensagem || '').trim();
      if (!texto) {
        return res.status(400).json({ ok: false, error: 'Mensagem não pode ser vazia.' });
      }

      const { data: sol } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (!sol) return res.status(404).json({ ok: false, error: 'Solicitação não encontrada.' });
      if (!usuarioPodeVerSolicitacao(req.apoiosUser, sol)) {
        return res.status(403).json({ ok: false, error: 'Sem permissão organizacional.' });
      }

      const { data, error } = await supabase
        .from('tasks_apoios_mensagens')
        .insert({
          solicitacao_id: id,
          autor_usuario_id: req.apoiosUser.id,
          autor_nome: req.apoiosUser.nome || req.apoiosUser.email,
          unidade_id: req.apoiosUser.divisaoIds[0] || null,
          mensagem: texto,
        })
        .select('*')
        .single();

      if (error) return res.status(400).json({ ok: false, error: error.message });
      return res.status(201).json({ ok: true, data });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 21. Processamento sob demanda da Outbox (útil para testes e sincronização imediata)
  app.post('/api/apoios/notificacoes/processar-outbox', requireApoiosAuth, async (req, res) => {
    try {
      const result = await notifWorker.processOutboxQueue();
      return res.json({ ok: true, data: result });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 21b. Visualização somente leitura de atividade relacionada a apoio (cross-unidade)
  app.get('/api/apoios/tasks/:taskId', requireApoiosAuth, async (req, res) => {
    try {
      const { taskId } = req.params;
      if (!taskId || !/^[0-9a-f-]{36}$/i.test(taskId)) {
        return res.status(400).json({ ok: false, error: 'taskId inválido.' });
      }

      const { data: taskRow, error: taskErr } = await supabase
        .from('tasks')
        .select(
          `
            *,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(locais!inner(id, local)),
            tasks_executores!left(executores!inner(id, nome)),
            tasks_equipes!left(equipes!inner(id, nome)),
            tasks_frotas!left(frota!inner(id, nome, placa))
          `
        )
        .eq('id', taskId)
        .maybeSingle();

      if (taskErr) return res.status(400).json({ ok: false, error: taskErr.message });
      if (!taskRow) return res.status(404).json({ ok: false, error: 'Atividade não encontrada.' });

      let autorizado =
        Boolean(req.apoiosUser.isRoot) ||
        usuarioPertenceUnidade(req.apoiosUser, {
          regionalId: taskRow.regional_id,
          divisaoId: taskRow.divisao_id,
          segmentoId: taskRow.segmento_id,
        });

      if (!autorizado) {
        const [{ data: solsDiretas }, { data: vinculos }] = await Promise.all([
          supabase
            .from('tasks_apoios_solicitacoes')
            .select(
              'id, regional_solicitante_id, divisao_solicitante_id, segmento_solicitante_id, regional_destino_id, divisao_destino_id, segmento_destino_id'
            )
            .eq('task_solicitante_id', taskId)
            .limit(20),
          supabase
            .from('tasks_apoios_vinculos')
            .select('solicitacao_id')
            .or(`task_principal_id.eq.${taskId},task_apoio_id.eq.${taskId}`)
            .limit(20),
        ]);

        let todasSols = solsDiretas || [];
        const vincSolIds = Array.from(
          new Set((vinculos || []).map((v) => v.solicitacao_id).filter(Boolean))
        );
        if (vincSolIds.length > 0) {
          const { data: solsVinc } = await supabase
            .from('tasks_apoios_solicitacoes')
            .select(
              'id, regional_solicitante_id, divisao_solicitante_id, segmento_solicitante_id, regional_destino_id, divisao_destino_id, segmento_destino_id'
            )
            .in('id', vincSolIds);
          todasSols = [...todasSols, ...(solsVinc || [])];
        }

        autorizado = todasSols.some(
          (s) =>
            usuarioPertenceUnidade(req.apoiosUser, {
              regionalId: s.regional_solicitante_id,
              divisaoId: s.divisao_solicitante_id,
              segmentoId: s.segmento_solicitante_id,
            }) ||
            usuarioPertenceUnidade(req.apoiosUser, {
              regionalId: s.regional_destino_id,
              divisaoId: s.divisao_destino_id,
              segmentoId: s.segmento_destino_id,
            })
        );
      }

      if (!autorizado) {
        return res.status(403).json({
          ok: false,
          error: 'Sem permissão para visualizar esta atividade.',
        });
      }

      const { data: segments } = await supabase
        .from('gantt_segments')
        .select('*')
        .eq('task_id', taskId)
        .order('data_inicio', { ascending: true })
        .limit(100);

      return res.json({
        ok: true,
        data: {
          ...taskRow,
          gantt_segments: segments || [],
        },
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 22. Carregamento em lote para o Gantt Integrado (Fase 7 — zero N+1, resumo seguro)
  app.get('/api/apoios/gantt-integrado', requireApoiosAuth, async (req, res) => {
    try {
      const rawIds = String(req.query.taskIds || '').trim();
      const taskIds = rawIds
        ? rawIds.split(',').map((s) => s.trim()).filter(Boolean).slice(0, 500)
        : [];

      let solQuery = supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('ativo', true)
        .order('data_inicio_solicitada', { ascending: true })
        .limit(500);

      if (taskIds.length > 0) {
        solQuery = solQuery.in('task_solicitante_id', taskIds);
      }

      const { data: solsRaw, error: solErr } = await solQuery;
      if (solErr) return res.status(400).json({ ok: false, error: solErr.message });

      const visiveis = (solsRaw || []).filter((s) =>
        usuarioPodeVerSolicitacao(req.apoiosUser, s)
      );
      const enriquecidas = await enrichSolicitacoes(supabase, visiveis);

      const linkedTaskIds = new Set(taskIds);
      for (const s of enriquecidas) {
        if (s.task_solicitante_id) linkedTaskIds.add(s.task_solicitante_id);
        for (const v of s.vinculos || []) {
          if (v.ativo && v.task_apoio_id) linkedTaskIds.add(v.task_apoio_id);
          if (v.ativo && v.task_principal_id) linkedTaskIds.add(v.task_principal_id);
        }
      }

      let tasksVinculadas = [];
      if (linkedTaskIds.size > 0) {
        const { data: tData } = await supabase
          .from('tasks')
          .select(
            'id, tarefa, data_inicio, data_fim, status, regional, divisao, regional_id, divisao_id, segmento_id, local, frota, executor, equipe_id'
          )
          .in('id', Array.from(linkedTaskIds).slice(0, 500));
        tasksVinculadas = tData || [];
      }

      return res.json({
        ok: true,
        data: {
          solicitacoes: enriquecidas,
          tasksVinculadas,
        },
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // 23. Indicadores gerenciais consolidados no backend (respeitando escopo do usuário)
  app.get('/api/apoios/indicadores-gerenciais', requireApoiosAuth, async (req, res) => {
    try {
      const { data: solsRaw, error } = await supabase
        .from('tasks_apoios_solicitacoes')
        .select('*')
        .eq('ativo', true)
        .limit(1000);

      if (error) return res.status(400).json({ ok: false, error: error.message });

      const visiveis = (solsRaw || []).filter((s) =>
        usuarioPodeVerSolicitacao(req.apoiosUser, s)
      );
      const enriquecidas = await enrichSolicitacoes(supabase, visiveis);

      const porStatus = {};
      for (const s of enriquecidas) {
        porStatus[s.status] = (porStatus[s.status] || 0) + 1;
      }

      return res.json({
        ok: true,
        data: {
          totalSolicitacoes: enriquecidas.length,
          porStatus,
          solicitacoes: enriquecidas,
        },
      });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
}

module.exports = {
  registerApoiosGateway,
  signApoiosToken,
  verifyApoiosToken,
};

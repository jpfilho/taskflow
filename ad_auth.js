const ldap = require('ldapjs');

const AD_CONFIG = {
  url: process.env.AD_URL || 'ldap://adsede.redechesf.local:389',
  domain: process.env.AD_DOMAIN || 'redechesf',
  baseDn: process.env.AD_BASE_DN || 'DC=redechesf,DC=local',
  connectTimeout: 5000,
  timeout: 7000,
};

/**
 * Autentica usuário no Active Directory da Chesf
 * @param {string} username - Login de rede ou matrícula
 * @param {string} password - Senha de rede
 * @returns {Promise<{success: boolean, user?: object, error?: string}>}
 */
async function authenticateAD(username, password) {
  if (!username || !password) {
    return { success: false, error: 'Usuário e senha são obrigatórios' };
  }

  // Limpar nome de usuário (remover domínio se já digitou)
  let cleanUser = username.trim().toLowerCase();
  cleanUser = cleanUser.replace(/^redechesf\\/i, '');
  cleanUser = cleanUser.replace(/@redechesf\.local$/i, '');
  cleanUser = cleanUser.replace(/@chesf\.gov\.br$/i, '');

  const upn = `${cleanUser}@redechesf.local`;

  return new Promise((resolve) => {
    let client;
    let finished = false;

    const timer = setTimeout(() => {
      if (!finished) {
        finished = true;
        try { if (client) client.destroy(); } catch (_) {}
        resolve({
          success: false,
          error: 'Tempo limite ao conectar com o Active Directory (adsede.redechesf.local). O servidor precisa estar na rede interna da Chesf.',
        });
      }
    }, AD_CONFIG.connectTimeout + 2000);

    try {
      client = ldap.createClient({
        url: AD_CONFIG.url,
        connectTimeout: AD_CONFIG.connectTimeout,
        timeout: AD_CONFIG.timeout,
      });

      client.on('error', (err) => {
        if (!finished) {
          finished = true;
          clearTimeout(timer);
          try { client.destroy(); } catch (_) {}
          resolve({
            success: false,
            error: `Erro de conexão com o AD (${err.code || err.message}). Verifique o acesso à rede interna.`,
          });
        }
      });

      // Tenta autenticar (bind)
      client.bind(upn, password, (err) => {
        if (finished) return;

        if (err) {
          finished = true;
          clearTimeout(timer);
          try { client.unbind(); client.destroy(); } catch (_) {}

          // Erro 49 = Invalid Credentials
          if (err.name === 'InvalidCredentialsError' || err.code === 49) {
            return resolve({
              success: false,
              error: 'Usuário de rede ou senha incorretos.',
            });
          }
          return resolve({
            success: false,
            error: `Falha na autenticação do AD: ${err.message || err.name}`,
          });
        }

        // Se autenticou com sucesso, busca os dados complementares do usuário
        const opts = {
          filter: `(|(sAMAccountName=${cleanUser})(userPrincipalName=${upn}))`,
          scope: 'sub',
          attributes: ['displayName', 'mail', 'sAMAccountName', 'department', 'title'],
        };

        client.search(AD_CONFIG.baseDn, opts, (searchErr, res) => {
          let userEntry = null;

          if (searchErr) {
            finished = true;
            clearTimeout(timer);
            try { client.unbind(); client.destroy(); } catch (_) {}
            return resolve({
              success: true,
              user: {
                username: cleanUser,
                email: `${cleanUser}@chesf.gov.br`,
                nome: cleanUser,
              },
            });
          }

          res.on('searchEntry', (entry) => {
            userEntry = entry.object;
          });

          res.on('error', () => {
            if (!finished) {
              finished = true;
              clearTimeout(timer);
              try { client.unbind(); client.destroy(); } catch (_) {}
              resolve({
                success: true,
                user: {
                  username: cleanUser,
                  email: `${cleanUser}@chesf.gov.br`,
                  nome: cleanUser,
                },
              });
            }
          });

          res.on('end', () => {
            if (!finished) {
              finished = true;
              clearTimeout(timer);
              try { client.unbind(); client.destroy(); } catch (_) {}
              const nome = (userEntry && userEntry.displayName) ? userEntry.displayName : cleanUser;
              const email = (userEntry && userEntry.mail) ? userEntry.mail : `${cleanUser}@chesf.gov.br`;

              resolve({
                success: true,
                user: {
                  username: cleanUser,
                  email: email,
                  nome: nome,
                  departamento: userEntry ? userEntry.department : null,
                },
              });
            }
          });
        });
      });
    } catch (e) {
      if (!finished) {
        finished = true;
        clearTimeout(timer);
        resolve({
          success: false,
          error: `Exceção ao inicializar cliente LDAP: ${e.message}`,
        });
      }
    }
  });
}

module.exports = {
  authenticateAD,
  AD_CONFIG,
};

/* eslint-disable no-console */
/**
 * Ingestores geoespaciais para Queimadas (INPE Dataserver COIDS) e Raios.
 * Foca em idempotência (hash + função SQL) e logs claros.
 */
const DEFAULT_RAIOS_URL = process.env.RAIOS_URL || '';
const BLITZ_BASE = process.env.BLITZORTUNG_BASE || 'https://data.blitzortung.org/Data/Public/';
const INPE_FOCOS_URL = process.env.INPE_FOCOS_URL || '';
const COIDS_LIST_10MIN = 'https://dataserver-coids.inpe.br/queimadas/queimadas/focos/csv/10min/';
const COIDS_LIST_DIARIO_BR = 'https://dataserver-coids.inpe.br/queimadas/queimadas/focos/csv/diario/Brasil/';

function parseTimestamp(raw) {
  if (!raw) return null;
  // Aceitar Date, número, string ISO ou formatos comuns do INPE
  if (raw instanceof Date) return raw;
  if (typeof raw === 'number') return new Date(raw);
  const asStr = String(raw);
  // Formato dd/MM/yyyy HH:mm ou yyyy-MM-dd HH:mm:ss
  const isoCandidate = asStr.replace(' ', 'T');
  const dt = new Date(isoCandidate);
  if (!Number.isNaN(dt.getTime())) return dt;
  return null;
}

function extractLatLon(item = {}) {
  const lat =
    item.latitude ??
    item.lat ??
    item.lat_gmt ??
    item.y ??
    item.LAT ??
    item.latitud ??
    null;
  const lon =
    item.longitude ??
    item.lon ??
    item.long ??
    item.x ??
    item.LON ??
    item.longitud ??
    null;
  return { lat: lat != null ? Number(lat) : null, lon: lon != null ? Number(lon) : null };
}

function extractDatetime(item = {}) {
  return (
    parseTimestamp(
      item.data_hora_gmt ??
        item.data_hora ??
        item.datahora ??
        item.dt ?? // genérico
        item.timestamp ??
        item.hora_gmt ??
        item.date ??
        item.datetime ??
        item.data ?? // CSVs do INPE costumam trazer data separada
        item.obsTime
    ) || null
  );
}

const https = require('https');
const httpsAgent = new https.Agent({ rejectUnauthorized: false });
const { parse } = require('csv-parse/sync');
const crypto = require('crypto');
const { setTimeout: sleep } = require('node:timers/promises');

async function fetchText(url) {
  const resp = await fetch(url, {
    agent: url.startsWith('https') ? httpsAgent : undefined,
  });
  if (!resp.ok) {
    throw new Error(`Falha ao baixar ${url} - status ${resp.status}`);
  }
  return resp.text();
}

async function fetchJson(url) {
  const resp = await fetch(url, {
    agent: url.startsWith('https') ? httpsAgent : undefined,
  });
  if (!resp.ok) {
    throw new Error(`Falha ao baixar ${url} - status ${resp.status}`);
  }
  return resp.json();
}

async function fetchWithRetry(url, { retries = 3, timeoutMs = 20000 } = {}) {
  let attempt = 0;
  let lastErr;
  while (attempt < retries) {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      const resp = await fetch(url, {
        redirect: 'follow',
        signal: controller.signal,
        agent: url.startsWith('https') ? httpsAgent : undefined,
      });
      clearTimeout(timer);
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}`);
      }
      const text = await resp.text();
      return { resp, text };
    } catch (e) {
      lastErr = e;
      attempt += 1;
      if (attempt >= retries) break;
      const backoff = 500 * 2 ** attempt;
      console.warn(`⚠️ fetch retry ${attempt}/${retries} para ${url}: ${e.message}`);
      await sleep(backoff);
    }
  }
  throw lastErr;
}

function hashNatural(lat, lon, acqTime, sat = '') {
  return crypto.createHash('md5').update(`${lat}|${lon}|${acqTime.toISOString()}|${sat}`).digest('hex');
}

function extractCsvFromListing(listing) {
  const regex = /href="([^"]+\.csv)"/gi;
  const files = [];
  let m;
  while ((m = regex.exec(listing)) !== null) {
    files.push(m[1]);
  }
  return files;
}

async function getLatest10MinFileName() {
  if (INPE_FOCOS_URL) {
    const parts = INPE_FOCOS_URL.split('/');
    return { csvUrl: INPE_FOCOS_URL, fileName: parts[parts.length - 1] };
  }
  const html = await fetchText(COIDS_LIST_10MIN);
  const files = extractCsvFromListing(html);
  if (!files.length) {
    throw new Error('Nenhum CSV encontrado na listagem 10min do COIDS');
  }
  files.sort();
  const fileName = files[files.length - 1];
  return { csvUrl: `${COIDS_LIST_10MIN}${fileName}`, fileName };
}

function parseCoidsCsv(csvText) {
  const records = parse(csvText, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });
  return records
    .map((row) => {
      const lower = Object.keys(row).reduce((acc, k) => {
        acc[k.toLowerCase()] = row[k];
        return acc;
      }, {});
      const lat = parseFloat(lower.latitude || lower.lat || lower.lat_gmt || lower.y);
      const lon = parseFloat(lower.longitude || lower.lon || lower.long || lower.x);
      // Datas nos CSVs do COIDS costumam vir como datahora ou data_hora_gmt
      const when =
        lower.datahora ||
        lower.data_hora_gmt ||
        lower.data_hora ||
        lower.data ||
        lower.dt ||
        lower.timestamp;
      const acqTime = parseTimestamp(when);
      const sat = lower.satelite || lower.satellite || lower.sensor || '';
      if (!lat || !lon || !acqTime) return null;
      const id = hashNatural(lat, lon, acqTime, sat);
      return {
        id,
        source: 'inpe_dataserver',
        acq_time: acqTime,
        latitude: lat,
        longitude: lon,
        sat,
        raw: row,
      };
    })
    .filter(Boolean);
}

async function ingestQueimadas({ pgPool, sinceMinutes = 120 } = {}) {
  const client = await pgPool.connect();
  try {
    const { csvUrl, fileName } = await getLatest10MinFileName();
    console.log(`🌐 Baixando focos de queimadas de ${csvUrl}`);
    const csvText = await fetchText(csvUrl);
    const parsed = parseCoidsCsv(csvText);
    const cutoff = new Date(Date.now() - sinceMinutes * 60 * 1000);
    const recs = parsed.filter((r) => r.acq_time >= cutoff);

    // Descobrir se existe coluna geom
    let hasGeom = false;
    try {
      const check = await client.query(
        `SELECT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'tbl_queimadas_focos' AND column_name = 'geom'
        )`,
      );
      hasGeom = check.rows?.[0]?.exists === true;
    } catch (e) {
      hasGeom = false;
    }

    let upserts = 0;
    for (const r of recs) {
      const params = [
        r.id,
        r.source,
        r.acq_time,
        r.latitude,
        r.longitude,
        r.sat,
        r.raw,
      ];
      let sql = `
        INSERT INTO geo_queimadas (id, source, acq_time, latitude, longitude, satellite, raw${hasGeom ? ', geom' : ''})
        VALUES ($1, $2, $3, $4, $5, $6, $7${hasGeom ? ', ST_SetSRID(ST_MakePoint($5, $4), 4326)::geography' : ''})
        ON CONFLICT (id) DO NOTHING
      `;
      await client.query(sql, params);
      upserts += 1;
    }

    console.log(`✅ Queimadas: processadas ${recs.length} (upserts: ${upserts}) | arquivo: ${fileName}`);
    return { processed: recs.length, upserts };
  } finally {
    client.release();
  }
}

function parseRaiosCsv(text) {
  const records = parse(text, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });
  return records
    .map((row) => {
      const lower = Object.keys(row).reduce((acc, k) => {
        acc[k.toLowerCase()] = row[k];
        return acc;
      }, {});
      const lat = parseFloat(lower.lat || lower.latitude);
      const lon = parseFloat(lower.lon || lower.longitude);
      const when = lower.time || lower.timestamp || lower.datahora || lower.data_hora;
      const acqTime = parseTimestamp(when);
      if (!lat || !lon || !acqTime) return null;
      const id = crypto
        .createHash('md5')
        .update(`blitz|${lat}|${lon}|${acqTime.toISOString()}`)
        .digest('hex');
      return {
        id,
        fonte: 'raios_fonte',
        data_hora: acqTime,
        lat,
        lon,
        raw: row,
      };
    })
    .filter(Boolean);
}

function parseRaiosJsonLines(text) {
  const lines = text.split('\n').filter((l) => l.trim().length > 2);
  const out = [];
  for (const line of lines) {
    try {
      const obj = JSON.parse(line);
      const lat = parseFloat(obj.lat || obj.latitude);
      const lon = parseFloat(obj.lon || obj.longitude);
      const when = obj.time || obj.timestamp || obj.t || obj.datahora;
      const acqTime = parseTimestamp(when);
      if (!lat || !lon || !acqTime) continue;
      const id = crypto
        .createHash('md5')
        .update(`blitz|${lat}|${lon}|${acqTime.toISOString()}`)
        .digest('hex');
      out.push({
        id,
        fonte: 'blitzortung',
        data_hora: acqTime,
        lat,
        lon,
        raw: obj,
      });
    } catch (e) {
      // ignore line
    }
  }
  return out;
}

async function ingestRaios({ pgPool } = {}) {
  // Se RAIOS_URL estiver definida, usar como fonte
  if (DEFAULT_RAIOS_URL) {
    return ingestRaiosFromUrl({ pgPool, url: DEFAULT_RAIOS_URL });
  }
  // Caso contrário, tentar Blitzortung
  return ingestRaiosFromBlitz({ pgPool });
}

async function ingestRaiosFromUrl({ pgPool, url }) {
  const client = await pgPool.connect();
  try {
    console.log(`🌐 Baixando raios de ${url}`);
    const { resp, text } = await fetchWithRetry(url, { retries: 3, timeoutMs: 20000 });
    const contentType = resp.headers.get('content-type') || '';
    let rows = [];
    if (url.endsWith('.csv') || contentType.includes('text/csv')) {
      rows = parseRaiosCsv(text);
    } else {
      // tentar JSON/JSONL
      try {
        const json = JSON.parse(text);
        if (Array.isArray(json)) {
          rows = json
            .map((obj) => {
              const lat = parseFloat(obj.lat || obj.latitude);
              const lon = parseFloat(obj.lon || obj.longitude);
              const when = obj.time || obj.timestamp || obj.t || obj.datahora;
              const acqTime = parseTimestamp(when);
              if (!lat || !lon || !acqTime) return null;
              const id = crypto
                .createHash('md5')
                .update(`raiosurl|${lat}|${lon}|${acqTime.toISOString()}`)
                .digest('hex');
              return {
                id,
                fonte: 'raios_url',
                data_hora: acqTime,
                lat,
                lon,
                raw: obj,
              };
            })
            .filter(Boolean);
        } else {
          rows = parseRaiosJsonLines(text);
        }
      } catch (e) {
        rows = parseRaiosJsonLines(text);
      }
    }

    let upserts = 0;
    for (const r of rows) {
      await client.query(
        `INSERT INTO geo_raios (id, source, strike_time, latitude, longitude, raw, geom)
         VALUES ($1, $2, $3, $4, $5, $6, ST_SetSRID(ST_MakePoint($5, $4), 4326)::geography)
         ON CONFLICT (id) DO NOTHING`,
        [r.id, 'raios_url', r.data_hora, r.lat, r.lon, r.raw],
      );
      upserts += 1;
    }
    console.log(`✅ Raios (RAIOS_URL): processadas ${rows.length}, upserts ${upserts}`);
    return { processed: rows.length, upserts };
  } finally {
    client.release();
  }
}

async function ingestRaiosFromBlitz({ pgPool } = {}) {
  const client = await pgPool.connect();
  try {
    // Blitzortung: buscar arquivo mais recente do dia corrente (tolerância 30min)
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, '0');
    const d = String(now.getUTCDate()).padStart(2, '0');
    const base = `${BLITZ_BASE}${y}/${m}/${d}/`;
    let listing;
    try {
      const { text } = await fetchWithRetry(base, { retries: 2, timeoutMs: 15000 });
      listing = text;
    } catch (e) {
      console.warn(`⚠️ Blitzortung indisponível (${base}): ${e.message}`);
      return { processed: 0, upserts: 0, skipped: true };
    }

    const $ = cheerio.load(listing);
    const files = [];
    $('a').each((_, el) => {
      const href = $(el).attr('href');
      if (href && href.toLowerCase().endsWith('.json')) {
        files.push(href);
      }
    });
    if (!files.length) {
      console.warn('⚠️ Nenhum arquivo JSON encontrado no diretório Blitzortung');
      return { processed: 0, upserts: 0, skipped: true };
    }
    files.sort();
    const latest = files[files.length - 1];
    const url = `${base}${latest}`;
    console.log(`🌐 Baixando raios Blitzortung: ${url}`);
    let text;
    try {
      const fetched = await fetchWithRetry(url, { retries: 2, timeoutMs: 15000 });
      text = fetched.text;
    } catch (e) {
      console.warn(`⚠️ Falha ao baixar Blitzortung ${url}: ${e.message}`);
      return { processed: 0, upserts: 0, skipped: true };
    }

    const rows = parseRaiosJsonLines(text);
    let upserts = 0;
    for (const r of rows) {
      await client.query(
        `INSERT INTO geo_raios (id, source, strike_time, latitude, longitude, raw, geom)
         VALUES ($1, $2, $3, $4, $5, $6, ST_SetSRID(ST_MakePoint($5, $4), 4326)::geography)
         ON CONFLICT (id) DO NOTHING`,
        [r.id, r.fonte, r.data_hora, r.lat, r.lon, r.raw],
      );
      upserts += 1;
    }
    console.log(`✅ Raios (Blitzortung): processadas ${rows.length}, upserts ${upserts}`);
    return { processed: rows.length, upserts };
  } finally {
    client.release();
  }
}

async function ingestRaios({
  pgPool,
  fonte = 'ELAT-RAIOS',
  url = DEFAULT_RAIOS_URL,
  start,
  end,
  fallbackItems,
} = {}) {
  if (!url && (!fallbackItems || fallbackItems.length === 0)) {
    console.warn('⚠️ Nenhuma URL de raios configurada (RAIOS_URL). Pular ingestão.');
    return { processed: 0, upserts: 0, skipped: true };
  }

  const client = await pgPool.connect();
  try {
    let rows = fallbackItems;
    if (url) {
      console.log(`🌐 Baixando raios de ${url}`);
      const data = await fetchJson(url);
      rows = Array.isArray(data)
        ? data
        : Array.isArray(data?.features)
          ? data.features.map((f) => ({ ...f.properties, ...f.attributes, ...f }))
          : [];
    }

    let upserts = 0;
    for (const item of rows) {
      const { lat, lon } = extractLatLon(item);
      const dataHora = extractDatetime(item);
      if (!lat || !lon || !dataHora) continue;
      if (start && dataHora < new Date(start)) continue;
      if (end && dataHora > new Date(end)) continue;

      const atributos = { ...item };
      delete atributos.lat;
      delete atributos.lon;
      delete atributos.latitude;
      delete atributos.longitude;

      await client.query(
        'SELECT upsert_evento_raio($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5) AS id',
        [fonte, dataHora, lon, lat, atributos],
      );
      upserts += 1;
    }
    console.log(`✅ Raios: processadas ${rows.length} entradas, upserts: ${upserts}`);
    return { processed: rows.length, upserts };
  } finally {
    client.release();
  }
}

async function queryEventos({ pgPool, table, bbox, start, end, limit = 200, offset = 0 }) {
  const client = await pgPool.connect();
  try {
    const clauses = [];
    const params = [];

    if (start) {
      params.push(new Date(start));
      clauses.push(`data_hora >= $${params.length}`);
    }
    if (end) {
      params.push(new Date(end));
      clauses.push(`data_hora <= $${params.length}`);
    }
    if (bbox) {
      const [minLon, minLat, maxLon, maxLat] = bbox.split(',').map(Number);
      params.push(minLon, minLat, maxLon, maxLat);
      clauses.push(
        `ST_Intersects(geom, ST_MakeEnvelope($${params.length - 3}, $${params.length - 2}, $${params.length - 1}, $${params.length}, 4326)::geography)`,
      );
    }
    params.push(limit);
    params.push(offset);

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    const sql = `
      SELECT id, fonte, data_hora, atributos, lat, lon, created_at
      FROM ${table}
      ${where}
      ORDER BY data_hora DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}
    `;
    const { rows } = await client.query(sql, params);
    return rows;
  } finally {
    client.release();
  }
}

async function refreshAgregados({ pgPool, windowDays = 7, bufferM = 50 }) {
  const client = await pgPool.connect();
  try {
    await client.query('SELECT refresh_eventos_agregados_trecho($1, $2)', [windowDays, bufferM]);
    return { ok: true };
  } finally {
    client.release();
  }
}

async function getTrechoAlertas({ pgPool, trechoId }) {
  const client = await pgPool.connect();
  try {
    const { rows } = await client.query(
      `SELECT * FROM eventos_agregados_trecho WHERE trecho_geom_id = $1 ORDER BY tipo_evento, window_days`,
      [trechoId],
    );
    return rows;
  } finally {
    client.release();
  }
}

module.exports = {
  ingestQueimadas,
  ingestRaios,
  queryEventos,
  refreshAgregados,
  getTrechoAlertas,
};

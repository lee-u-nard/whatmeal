// Diagnostic replay of synthetic disposable-account data ONLY. Never selects a
// cloud project, resets an emulator, prints a recipe, or reads credentials.
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';

const HOST = '127.0.0.1:9380';
const PROJECT = 'demo-whatmeal-cloud-security';
const DATABASE = `projects/${PROJECT}/databases/(default)`;
const ORIGIN = `http://${HOST}`;
const BASE = `${ORIGIN}/v1/${DATABASE}/documents`;
// Stable byte-for-byte copy of the original failed disposable-account batch.
// Later successful Android runs replace their current capture; never silently
// change the regression fixture to that newer generated recipe.
const INPUT = fileURLToPath(new URL('../../build/cloudtest-private/evidence/original-rule-budget-capture.json', import.meta.url));

class SafeFailure extends Error {}
function requireSafe(condition, code) { if (!condition) throw new SafeFailure(code); }
class CapturedNumber {
  constructor(source) { this.source = source; }
  get integer() { return /^-?\d+$/.test(this.source); }
  get value() { return Number(this.source); }
}
function number(value) { return value instanceof CapturedNumber ? value.value : value; }
function integer(value) { return value instanceof CapturedNumber && value.integer; }
function parseCapture(raw) {
  // JSON.parse would otherwise collapse a native double such as 1.0 into an
  // integer. Node's source-context reviver preserves the original wire type.
  return JSON.parse(raw, (_key, value, context) => {
    if (typeof value !== 'number') return value;
    requireSafe(typeof context?.source === 'string', 'NODE_JSON_SOURCE_CONTEXT_REQUIRED');
    return new CapturedNumber(context.source);
  });
}
function jwt(uid) {
  const now = Math.floor(Date.now() / 1000);
  return [{alg: 'none', typ: 'JWT'}, {
    aud: PROJECT, iss: `https://securetoken.google.com/${PROJECT}`,
    sub: uid, user_id: uid, iat: now, exp: now + 3600,
    firebase: {sign_in_provider: 'custom', identities: {}},
  }].map(part => Buffer.from(JSON.stringify(part)).toString('base64url')).join('.') + '.';
}
async function request(suffix, {writes, uid, admin = false} = {}) {
  const url = new URL(`${BASE}${suffix}`);
  requireSafe(url.origin === ORIGIN && url.hostname === '127.0.0.1' &&
    url.port === '9380' && url.pathname.startsWith(`/v1/${DATABASE}/documents`), 'LOCAL_ENDPOINT_GUARD');
  const response = await fetch(url, {
    method: writes ? 'POST' : 'GET', redirect: 'error',
    headers: {'Content-Type': 'application/json', Authorization: `Bearer ${admin ? 'owner' : jwt(uid)}`},
    ...(writes ? {body: JSON.stringify({writes})} : {}),
    signal: AbortSignal.timeout(15000),
  });
  // Never include native response bodies or URLs in diagnostic output.
  await response.arrayBuffer();
  return response.status;
}
const commit = (writes, uid, admin = false) => request(':commit', {writes, uid, admin});
const state = path => request(`/${path}`, {admin: true});

function fieldPath(parts) {
  return parts.map(part => /^[A-Za-z_][A-Za-z0-9_]*$/.test(part)
    ? part : '`' + part.replaceAll('\\', '\\\\').replaceAll('`', '\\`') + '`').join('.');
}
function timestamp(seconds, nanoseconds) {
  const secs = number(seconds), nanos = number(nanoseconds);
  requireSafe(Number.isSafeInteger(secs) && Number.isInteger(nanos) && nanos >= 0 && nanos < 1e9,
    'INVALID_CAPTURE_TIMESTAMP');
  const iso = new Date(secs * 1000).toISOString();
  return {timestampValue: iso.replace(/\.\d{3}Z$/, `.${String(nanos).padStart(9, '0')}Z`)};
}
function encodeValue(value, parts, transforms, inArray = false) {
  if (value === null) return {nullValue: null};
  if (value instanceof CapturedNumber) {
    if (value.integer) return {integerValue: value.source};
    requireSafe(Number.isFinite(value.value), 'NONFINITE_CAPTURE_NUMBER');
    return {doubleValue: value.value};
  }
  if (typeof value === 'boolean') return {booleanValue: value};
  if (typeof value === 'string') return {stringValue: value};
  if (Array.isArray(value)) return {arrayValue: {
    values: value.map((entry, index) => encodeValue(entry, [...parts, String(index)], transforms, true)),
  }};
  requireSafe(value && typeof value === 'object', 'UNSUPPORTED_CAPTURE_VALUE');
  if (value.__type === 'timestamp') return timestamp(value.seconds, value.nanoseconds);
  if (value.__type === 'dateTimeMillis') {
    const millis = number(value.value);
    requireSafe(Number.isSafeInteger(millis), 'INVALID_CAPTURE_DATE');
    return {timestampValue: new Date(millis).toISOString()};
  }
  if (value.__type === 'serverTimestamp') {
    requireSafe(!inArray, 'SERVER_TIMESTAMP_IN_ARRAY');
    transforms.push({fieldPath: fieldPath(parts), setToServerValue: 'REQUEST_TIME'});
    return undefined;
  }
  requireSafe(!Object.hasOwn(value, '__type'), 'UNSUPPORTED_CAPTURE_SENTINEL');
  const fields = {};
  for (const [key, child] of Object.entries(value)) {
    const encoded = encodeValue(child, [...parts, key], transforms, inArray);
    if (encoded !== undefined) Object.defineProperty(fields, key,
      {value: encoded, enumerable: true, configurable: true});
  }
  return {mapValue: {fields}};
}
function leaves(value, parts = []) {
  if (value && typeof value === 'object' && !(value instanceof CapturedNumber) &&
      !Array.isArray(value) && !value.__type && Object.keys(value).length) {
    return Object.entries(value).flatMap(([key, child]) => leaves(child, [...parts, key]));
  }
  return [fieldPath(parts)];
}
function restWrite(write) {
  requireSafe(write.operation === 'set' && write.data && typeof write.data === 'object' &&
    !Array.isArray(write.data), 'ONLY_CAPTURED_SET_SUPPORTED');
  const transforms = [];
  const fields = encodeValue(write.data, [], transforms).mapValue.fields;
  const encoded = {update: {name: `${DATABASE}/documents/${write.path}`, fields}};
  const options = write.options;
  requireSafe(options == null || (Array.isArray(options) && options.length === 2), 'UNSUPPORTED_SET_OPTIONS');
  if (options) {
    const [merge, mergeFields] = options;
    requireSafe(merge == null || typeof merge === 'boolean', 'UNSUPPORTED_MERGE_FLAG');
    if (mergeFields != null) {
      requireSafe(Array.isArray(mergeFields) && mergeFields.every(parts =>
        Array.isArray(parts) && parts.length && parts.every(part => typeof part === 'string')),
      'UNSUPPORTED_MERGE_FIELDS');
      encoded.updateMask = {fieldPaths: mergeFields.map(fieldPath)};
    } else if (merge === true) {
      const transformed = new Set(transforms.map(item => item.fieldPath));
      encoded.updateMask = {fieldPaths: leaves(write.data).filter(path => !transformed.has(path))};
    }
  }
  if (transforms.length) encoded.updateTransforms = transforms;
  return encoded;
}

const planFields = ['title','startDate','endDate','numberOfDays','mealTypes','cuisinePreferences',
  'prioritizePantry','selectedMemberIds','estimatedCost','groceryListId','status','createdBy','createdAt','updatedAt'];
const mealFields = ['title','subtitle','imageUrl','cuisine','mealType','dayIndex','prepTime','cookTime',
  'servings','calories','protein','carbs','fats','badgeText','ingredients','instructions','availableIngredients',
  'missingIngredients','tags','reasoning','imageSearchQuery','youtubeSearchQuery','status','accepted',
  'replacedByMealId','replacedMealId','isFavorite','createdAt'];
function violationsFor(write) {
  const data = write.data;
  const isPlan = write.path.split('/').length === 4;
  const violations = [];
  const add = (field, code, extra = {}) => violations.push({field, code, ...extra});
  const unknown = Object.keys(data).filter(key => !(isPlan ? planFields : mealFields).includes(key));
  if (unknown.length) add('(unknown fields)', 'FIELD_ALLOWLIST', {count: unknown.length});
  const text = (key, max, optional = false) => {
    const value = data[key];
    if (optional && value == null) return;
    if (typeof value !== 'string') add(key, 'STRING_TYPE');
    else if ([...value].length > max) add(key, 'STRING_LENGTH', {length: [...value].length, maximum: max});
  };
  const time = (key, optional = false) => {
    const value = data[key];
    if (optional && value == null) return;
    if (!value || !['serverTimestamp','timestamp','dateTimeMillis'].includes(value.__type)) add(key, 'TIMESTAMP_TYPE');
  };
  const list = (key, max) => {
    const value = data[key];
    if (!Array.isArray(value)) { add(key, 'LIST_TYPE'); return; }
    if (value.length > max) add(key, 'LIST_LENGTH', {length: value.length, maximum: max});
    value.forEach((entry, index) => {
      if (typeof entry !== 'string') add(`${key}[${index}]`, 'STRING_ENTRY_TYPE');
      else if ([...entry].length > 1000) add(`${key}[${index}]`, 'STRING_LENGTH', {length: [...entry].length, maximum: 1000});
      else if (entry.includes('\u001f')) add(`${key}[${index}]`, 'RESERVED_SEPARATOR');
    });
  };
  const int = (key, minimum, maximum) => {
    const value = data[key];
    if (!integer(value)) add(key, 'INTEGER_TYPE');
    else if (value.value < minimum || value.value > maximum) add(key, 'INTEGER_RANGE', {minimum, maximum});
  };
  const bool = key => { if (typeof data[key] !== 'boolean') add(key, 'BOOL_TYPE'); };
  time('createdAt');
  if (isPlan) {
    text('title', 200); time('startDate', true); time('endDate', true); time('updatedAt', true);
    int('numberOfDays', 1, 31); list('mealTypes', 10); list('cuisinePreferences', 100); list('selectedMemberIds', 100);
    bool('prioritizePantry'); text('estimatedCost', 100, true); text('groceryListId', 128, true); text('createdBy', 128, true);
    if (!['active','saved','completed','archived','draft'].includes(data.status)) add('status', 'ENUM_VALUE');
  } else {
    text('title', 300); int('dayIndex', 0, 30);
    for (const [key, max] of Object.entries({subtitle:1000,imageUrl:2048,cuisine:100,mealType:100,prepTime:100,
      cookTime:100,servings:100,calories:100,protein:100,carbs:100,fats:100,badgeText:200,reasoning:4000,
      imageSearchQuery:500,youtubeSearchQuery:500,replacedByMealId:128,replacedMealId:128})) text(key, max, true);
    for (const key of ['instructions','availableIngredients','missingIngredients']) list(key, 100);
    list('tags', 50); bool('accepted'); bool('isFavorite');
    if (!['pending','accepted','completed','notCompleted','replaced'].includes(data.status)) add('status', 'ENUM_VALUE');
    if (data.accepted !== (data.status === 'accepted')) add('accepted', 'STATUS_MISMATCH');
    if (!Array.isArray(data.ingredients)) add('ingredients', 'LIST_TYPE');
    else {
      if (data.ingredients.length > 100) add('ingredients', 'LIST_LENGTH', {length:data.ingredients.length, maximum:100});
      data.ingredients.forEach((item, index) => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) { add(`ingredients[${index}]`, 'MAP_TYPE'); return; }
        const extras = Object.keys(item).filter(key => !['name','amount'].includes(key));
        if (extras.length) add(`ingredients[${index}]`, 'FIELD_ALLOWLIST', {count:extras.length});
        for (const [key, maximum] of [['name',200],['amount',100]]) {
          if (typeof item[key] !== 'string') add(`ingredients[${index}].${key}`, 'STRING_TYPE');
          else if ([...item[key]].length > maximum) add(`ingredients[${index}].${key}`, 'STRING_LENGTH',
            {length:[...item[key]].length, maximum});
        }
      });
    }
  }
  return violations;
}

async function main() {
  requireSafe(process.env.FIRESTORE_EMULATOR_HOST === HOST, 'REFUSE_NONISOLATED_EMULATOR');
  const batches = parseCapture(await readFile(INPUT, 'utf8'));
  requireSafe(Array.isArray(batches), 'CAPTURE_BATCH_LIST_REQUIRED');
  const batch = batches.find(item => item && Array.isArray(item.writes) && item.writes.length &&
    item.writes.every(write => write.operation === 'set') &&
    item.writes.some(write => typeof write.path === 'string' && write.path.split('/').length === 4));
  requireSafe(batch && batch.writes.length <= 500, 'CAPTURED_SET_BATCH_REQUIRED');
  requireSafe(number(batch.originalWriteCount) === batch.writes.length, 'PARTIAL_BATCH_CAPTURE_REFUSED');
  const writes = batch.writes;
  const first = writes[0].path?.split('/');
  requireSafe(first?.[0] === 'users' && first[2] === 'mealPlans' && first[1] && first[3], 'OWNER_PLAN_SCOPE_REQUIRED');
  const uid = first[1], planPath = first.slice(0,4).join('/');
  requireSafe(writes.every(write => {
    const parts = typeof write.path === 'string' ? write.path.split('/') : [];
    return (parts.length === 4 || (parts.length === 6 && parts[4] === 'meals')) &&
      parts.slice(0,4).join('/') === planPath && parts.every(part =>
        /^[A-Za-z0-9_-]+$/.test(part));
  }), 'MIXED_OR_INVALID_CAPTURE_SCOPE');
  requireSafe(new Set(writes.map(write => write.path)).size === writes.length, 'DUPLICATE_CAPTURE_PATH');
  const parent = writes.find(write => write.path === planPath);
  requireSafe(parent && writes.filter(write => write.path === planPath).length === 1, 'SINGLE_PARENT_REQUIRED');
  const encoded = writes.map(restWrite);
  // Refuse to overwrite anything, even inside this disposable emulator.
  for (const write of writes) requireSafe(await state(write.path) === 404, 'CAPTURE_DOCUMENT_ALREADY_EXISTS');
  const report = {
    capturedWriteCount: writes.length,
    capturedBatchCount: batches.length,
    schemaDiagnostics: writes.map((write, index) => ({document:index,
      kind:write.path === planPath ? 'plan' : 'meal', violations:violationsFor(write)})),
  };
  report.atomicHttp = await commit(encoded, uid);
  report.atomicDocumentsPresent = 0;
  for (const write of writes) {
    const status = await state(write.path);
    requireSafe(status === 200 || status === 404, 'UNEXPECTED_ATOMIC_READ_STATUS');
    if (status === 200) report.atomicDocumentsPresent++;
  }
  if (report.atomicHttp === 403) {
    report.atomicDenialLeftNoDocuments = report.atomicDocumentsPresent === 0;
    requireSafe(report.atomicDenialLeftNoDocuments, 'ATOMIC_DENIAL_LEFT_DOCUMENTS');
    report.parentOnlyHttp = await commit([restWrite(parent)], uid);
    // This one captured parent is seeded through the emulator-only admin token
    // to isolate each child rule from parent validation. No cloud credentials.
    report.parentAdminSeedHttp = await commit([restWrite(parent)], uid, true);
    requireSafe(report.parentAdminSeedHttp === 200, 'LOCAL_PARENT_SEED_FAILED');
    report.childOnlyHttp = [];
    for (const write of writes.filter(write => write !== parent)) {
      report.childOnlyHttp.push(await commit([restWrite(write)], uid));
    }
  }
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => {
  console.error(JSON.stringify({diagnosticError: error instanceof SafeFailure
    ? error.message : 'CAPTURE_REPLAY_FAILED'}));
  process.exitCode = 1;
});

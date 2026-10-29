import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8180');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST,'127.0.0.1:9099');
const database='projects/demo-whatmeal-audit/databases/(default)';
const base=`http://127.0.0.1:8180/v1/${database}/documents`;
const sessions=new Map();
async function register(label) {
  const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key',{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email:`${label}-${Date.now()}@example.test`,password:'isolated-fixture-password',returnSecureToken:true})});
  assert.equal(response.status,200,'Auth emulator registration');
  const account=await response.json();
  sessions.set(account.localId,account.idToken);
  return account.localId;
}
function value(v) {
  if(v===null)return {nullValue:null};
  if(v instanceof Date)return {timestampValue:v.toISOString()};
  if(typeof v==='number')return {integerValue:String(v)};
  return {stringValue:v};
}
function set(path,data,server=[],mask) {
  return {update:{name:`${database}/documents/${path}`,fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,value(v)]))},
    ...(server.length?{updateTransforms:server.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{}),
    ...(mask?{updateMask:{fieldPaths:mask}}:{})};
}
const del=path=>({delete:`${database}/documents/${path}`});
async function request(uid,suffix,method='GET',body) {
  assert.ok(sessions.has(uid));
  return fetch(base+suffix,{method,headers:{'Content-Type':'application/json',Authorization:`Bearer ${sessions.get(uid)}`},body:body?JSON.stringify(body):undefined});
}
async function commit(uid,writes){return (await request(uid,':commit','POST',{writes})).status;}
const owner=await register('owner');
const invited=await register('invited');
const fid='auth-workflow-'+Date.now();
const now=new Date();
const member=(uid,role,invitationId=null)=>({uid,name:'Fixture',role,joinedAt:now,invitedBy:owner,invitationId});
const index=uid=>({uid,familyId:fid,joinedAt:now});
assert.equal(await commit(owner,[
  set(`families/${fid}`,{schemaVersion:2,name:'Fixture',createdBy:owner,ownerUid:owner,state:'active',createdAt:now,updatedAt:now},['createdAt','updatedAt']),
  set(`families/${fid}/members/${owner}`,member(owner,'owner'),['joinedAt']),
  set(`membershipIndex/${owner}`,index(owner),['joinedAt'])]),200,'bootstrap');
assert.equal((await request(invited,`/families/${fid}`)).status,403);
for(let pass=0;pass<2;pass++) {
  const code=randomBytes(24).toString('base64url');
  const expiresAt=new Date(Date.now()+3600000);
  assert.equal(await commit(owner,[
    set(`householdInvitations/${code}`,{familyId:fid,issuedBy:owner,role:'member',createdAt:now,expiresAt,state:'pending',recipientUid:null,redeemedBy:null,redeemedAt:null},['createdAt']),
    set(`families/${fid}/invitationRefs/${code}`,{issuedBy:owner,expiresAt})]),200,'issue');
  const redeem=()=>[
    set(`householdInvitations/${code}`,{state:'redeemed',redeemedBy:invited,redeemedAt:now},['redeemedAt'],['state','redeemedBy','redeemedAt']),
    set(`families/${fid}/members/${invited}`,member(invited,'member',code),['joinedAt']),
    set(`membershipIndex/${invited}`,index(invited),['joinedAt'])];
  assert.equal(await commit(invited,redeem()),200,'join');
  assert.equal((await request(invited,`/families/${fid}`)).status,200);
  const path=`families/${fid}/pantryItems/shared`;
  assert.equal(await commit(owner,[set(path,{name:'Rice',quantity:'2',category:'Other',expirationDate:expiresAt,status:'available',addedBy:owner,createdAt:now})]),200);
  let doc=await (await request(invited,`/${path}`)).json();
  assert.equal(doc.fields.quantity.stringValue,'2');
  assert.equal(await commit(invited,[set(path,{quantity:'3'},[],['quantity'])]),200);
  doc=await (await request(owner,`/${path}`)).json();
  assert.equal(doc.fields.quantity.stringValue,'3');
  assert.equal(await commit(pass===0?owner:invited,[del(`families/${fid}/members/${invited}`),del(`membershipIndex/${invited}`)]),200,'remove/leave');
  assert.equal((await request(invited,`/families/${fid}`)).status,403);
  assert.equal(await commit(invited,redeem()),403,'reuse denied');
}
console.log('PASS two real Auth emulator registrations: bootstrap, invitation join, bidirectional pantry reads/writes, removal, rejoin, leave and reuse denial.');
console.log('Backend REST acceptance only; not device, SDK listener, live AI or notification delivery verification.');

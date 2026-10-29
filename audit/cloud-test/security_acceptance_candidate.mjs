import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
const host = process.env.FIRESTORE_EMULATOR_HOST;
const listOnly = process.argv.includes('--list');
if (!listOnly) assert.equal(host, '127.0.0.1:9380', 'Refusing to run without the isolated local emulator');
const project='demo-whatmeal-cloud-security';
const database=`projects/${project}/databases/(default)`;
const base=`http://${host}/v1/${database}/documents`;
function jwt(uid) {
  return [{alg:'none',typ:'JWT'},{aud:project,iss:`https://securetoken.google.com/${project}`,
    sub:uid,user_id:uid,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,
    firebase:{sign_in_provider:'custom',identities:{}}}]
    .map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.')+'.';
}
function value(v) {
  if(v===null) return {nullValue:null};
  if(v instanceof Date) return {timestampValue:v.toISOString()};
  if(typeof v==='boolean') return {booleanValue:v};
  if(typeof v==='number') return {integerValue:String(v)};
  if(typeof v==='string') return {stringValue:v};
  if(Array.isArray(v)) return {arrayValue:{values:v.map(value)}};
  return {mapValue:{fields:fields(v)}};
}
function fields(d) { return Object.fromEntries(Object.entries(d).map(([k,v])=>[k,value(v)])); }
const now=()=>new Date();
const later=()=>new Date(Date.now()+3600000);
const past=()=>new Date(Date.now()-3600000);
const token=()=>randomBytes(24).toString('base64url');
function set(path,data,{server=[],mask,create=false}={}) {
  return {update:{name:`${database}/documents/${path}`,fields:fields(data)},
    ...(server.length?{updateTransforms:server.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{}),
    ...(mask?{updateMask:{fieldPaths:mask}}:{}),...(create?{currentDocument:{exists:false}}:{})};
}
const del=path=>({delete:`${database}/documents/${path}`});
async function request(uid,suffix,method='GET',body) {
  return fetch(`${base}${suffix}`,{method,headers:{'Content-Type':'application/json',
    ...(uid===null?{}:{Authorization:`Bearer ${uid==='SEED'?'owner':jwt(uid)}`})},
    body:body===undefined?undefined:JSON.stringify(body)});
}
async function commit(uid,writes) {return (await request(uid,':commit','POST',{writes})).status;}
async function status(uid,path) {return (await request(uid,`/${path}`)).status;}
const family=(owner)=>({schemaVersion:2,name:'Fixture',createdBy:owner,ownerUid:owner,state:'active',createdAt:now(),updatedAt:now()});
const member=(uid,role)=>({uid,name:'Fixture',role,joinedAt:past(),invitedBy:'owner',invitationId:null});
const index=(uid,familyId)=>({uid,familyId,joinedAt:past()});
const pantry=()=>({name:'Rice',quantity:'1',category:'Other',expirationDate:later(),status:'available',addedBy:'owner',createdAt:now()});
async function reset() {
  const result=await fetch(`http://${host}/emulator/v1/${database}/documents`,{method:'DELETE'});
  assert.equal(result.status,200,'fixture reset failed');
  const writes=[set('families/f',family('owner')),set('families/g',family('otherOwner')),
    set('families/f/pantryItems/rice',pantry()),set('families/g/pantryItems/rice',pantry()),
    set('users/owner/secrets/llmConfig',{apiKey:'FAKE_FIXTURE_ONLY'}),
    set('families/legacy',{createdBy:'owner',memberUids:['owner','outsider'],inviteCode:'SHORT'})];
  for(const [uid,role] of [['owner','owner'],['admin','admin'],['member','member'],['viewer','viewOnly']]) {
    writes.push(set(`families/f/members/${uid}`,member(uid,role)),set(`membershipIndex/${uid}`,index(uid,'f')));
  }
  writes.push(set('families/g/members/otherOwner',member('otherOwner','owner')),set('membershipIndex/otherOwner',index('otherOwner','g')));
  assert.equal(await commit('SEED',writes),200,'seed failed');
}
async function issue(uid='owner',fid='f',role='member',overrides={}) {
  const code=token();
  const data={familyId:fid,issuedBy:uid,role,createdAt:now(),expiresAt:later(),state:'pending',recipientUid:null,redeemedBy:null,redeemedAt:null,...overrides};
  const result=await commit(uid,[set(`householdInvitations/${code}`,data,{server:['createdAt']}),
    set(`families/${fid}/invitationRefs/${code}`,{issuedBy:uid,expiresAt:data.expiresAt})]);
  return {code,result,data};
}
function redeemWrites(code,uid,fid='f',role='member',issuer='owner') {
  return [set(`householdInvitations/${code}`,{state:'redeemed',redeemedBy:uid,redeemedAt:now()},
      {mask:['state','redeemedBy','redeemedAt'],server:['redeemedAt']}),
    set(`families/${fid}/members/${uid}`,{...member(uid,role),invitedBy:issuer,invitationId:code},
      {server:['joinedAt'],create:true}),
    set(`membershipIndex/${uid}`,index(uid,fid),{server:['joinedAt'],create:true})];
}
const cases=[];
const test=(name,fn)=>cases.push([name,fn]);
const denied=result=>assert.equal(result,403);
const allowed=result=>assert.equal(result,200);
for(const uid of ['owner','admin','member','viewer','outsider',null]) {
  test(`${uid??'unauthenticated'} shared read`,async()=>assert.equal(await status(uid,'families/f/pantryItems/rice'),
    ['owner','admin','member','viewer'].includes(uid)?200:403));
  test(`${uid??'unauthenticated'} shared write`,async()=>assert.equal(await commit(uid,[set('families/f/pantryItems/new',pantry())]),
    ['owner','admin','member'].includes(uid)?200:403));
}
test('family and invitation listing denied',async()=>{
  denied((await request('owner','/families')).status);
  denied((await request('owner','/householdInvitations')).status);
});
test('outsider cannot read household or invitation refs',async()=>{
  denied(await status('outsider','families/f'));
  denied((await request('outsider','/families/f/invitationRefs')).status);
});
test('canonical membership only: legacy pointer/array does not grant access',async()=>{
  await commit('SEED',[set('users/outsider',{familyId:'legacy'})]);
  denied(await status('outsider','families/legacy'));
  denied(await commit('outsider',[set('families/legacy/pantryItems/x',pantry())]));
});
test('atomic initial owner bootstrap',async()=>{
  allowed(await commit('outsider',[
    set('families/new',family('outsider'),{server:['createdAt','updatedAt'],create:true}),
    set('families/new/members/outsider',{...member('outsider','owner'),invitedBy:'outsider'},{server:['joinedAt'],create:true}),
    set('membershipIndex/outsider',index('outsider','new'),{server:['joinedAt'],create:true})]));
});
test('bootstrap missing index denied',async()=>denied(await commit('outsider',[
  set('families/new',family('outsider'),{server:['createdAt','updatedAt']}),
  set('families/new/members/outsider',{...member('outsider','owner'),invitedBy:'outsider'},{server:['joinedAt']})])));
test('self-join without capability denied',async()=>denied(await commit('outsider',[
  set('families/f/members/outsider',member('outsider','member'),{server:['joinedAt']}),
  set('membershipIndex/outsider',index('outsider','f'),{server:['joinedAt']})])));
test('index creation alone denied',async()=>denied(await commit('outsider',[
  set('membershipIndex/outsider',index('outsider','f'),{server:['joinedAt']})])));
test('owner issues invitation and outsider redeems atomically',async()=>{
  const invitation=await issue(); allowed(invitation.result);
  allowed(await status('outsider',`householdInvitations/${invitation.code}`));
  allowed(await commit('outsider',redeemWrites(invitation.code,'outsider')));
  allowed(await status('outsider','families/f'));
});
test('member and viewer cannot issue tokens',async()=>{
  denied((await issue('member')).result); denied((await issue('viewer')).result);
});
test('admin limited to member/viewer invitations',async()=>{
  allowed((await issue('admin','f','viewOnly')).result);
  denied((await issue('admin','f','admin')).result);
  denied((await issue('owner','f','owner')).result);
});
test('short and excessive-lifetime invitations denied',async()=>{
  const invitation=await issue('owner','f','member',{expiresAt:new Date(Date.now()+8*86400000)});
  denied(invitation.result);
  const data={familyId:'f',issuedBy:'owner',role:'member',createdAt:now(),expiresAt:later(),state:'pending',recipientUid:null,redeemedBy:null,redeemedAt:null};
  denied(await commit('owner',[set('householdInvitations/ABC123',data,{server:['createdAt']}),
    set('families/f/invitationRefs/ABC123',{issuedBy:'owner',expiresAt:data.expiresAt})]));
});
test('revoked invitation cannot be redeemed',async()=>{
  const {code,result}=await issue(); allowed(result);
  allowed(await commit('owner',[set(`householdInvitations/${code}`,{state:'revoked'},{mask:['state']})]));
  denied(await commit('outsider',redeemWrites(code,'outsider')));
});
test('expired invitation cannot be read/redeemed',async()=>{
  const {code,result}=await issue(); allowed(result);
  allowed(await commit('SEED',[set(`householdInvitations/${code}`,{expiresAt:past()},{mask:['expiresAt']})]));
  denied(await status('outsider',`householdInvitations/${code}`));
  denied(await commit('outsider',redeemWrites(code,'outsider')));
});
test('recipient binding and invitation-role tampering denied',async()=>{
  const {code,result}=await issue('owner','f','member',{recipientUid:'intended'}); allowed(result);
  denied(await commit('outsider',redeemWrites(code,'outsider')));
  denied(await commit('intended',redeemWrites(code,'intended','f','admin')));
});
test('consumption without membership/index denied',async()=>{
  const {code,result}=await issue(); allowed(result);
  denied(await commit('outsider',redeemWrites(code,'outsider').slice(0,1)));
});
test('single use survives leave: same token cannot rejoin',async()=>{
  const {code,result}=await issue(); allowed(result);
  allowed(await commit('outsider',redeemWrites(code,'outsider')));
  allowed(await commit('outsider',[del('families/f/members/outsider'),del('membershipIndex/outsider')]));
  denied(await commit('outsider',redeemWrites(code,'outsider')));
});
test('concurrent redeemers: exactly one wins',async()=>{
  const {code,result}=await issue(); allowed(result);
  const outcomes=await Promise.all(['joinA','joinB'].map(uid=>commit(uid,redeemWrites(code,uid))));
  assert.equal(outcomes.filter(x=>x===200).length,1);
  assert.equal(outcomes.filter(x=>x===403||x===409).length,1);
});
test('one user concurrent joins different families: exactly one wins',async()=>{
  const a=await issue(),b=await issue('otherOwner','g'); allowed(a.result);allowed(b.result);
  const outcomes=await Promise.all([commit('joiner',redeemWrites(a.code,'joiner')),
    commit('joiner',redeemWrites(b.code,'joiner','g','member','otherOwner'))]);
  assert.equal(outcomes.filter(x=>x===200).length,1);
});
for(const uid of ['owner','admin','member','viewer']) {
  test(`${uid} cannot self-change role`,async()=>denied(await commit(uid,[
    set(`families/f/members/${uid}`,{role:uid==='owner'?'member':'owner'},{mask:['role']})])));
}
test('owner may promote member, admin may not promote member to admin',async()=>{
  denied(await commit('admin',[set('families/f/members/member',{role:'admin'},{mask:['role']})]));
  allowed(await commit('owner',[set('families/f/members/member',{role:'admin'},{mask:['role']})]));
});
test('creator and direct owner mutation denied',async()=>{
  denied(await commit('owner',[set('families/f',{createdBy:'member'},{mask:['createdBy'],server:['updatedAt']})]));
  denied(await commit('owner',[set('families/f',{ownerUid:'member'},{mask:['ownerUid'],server:['updatedAt']})]));
});
test('ownership offer accepted atomically',async()=>{
  allowed(await commit('owner',[set('families/f/ownershipTransfers/pending',{
    fromUid:'owner',toUid:'member',createdAt:now(),expiresAt:later()},{server:['createdAt']})]));
  allowed(await commit('member',[
    set('families/f',{ownerUid:'member'},{mask:['ownerUid'],server:['updatedAt']}),
    set('families/f/members/owner',{role:'admin'},{mask:['role']}),
    set('families/f/members/member',{role:'owner'},{mask:['role']}),del('families/f/ownershipTransfers/pending')]));
});
for(const [actor,target,ok] of [['owner','member',true],['admin','member',true],['admin','owner',false],['member','viewer',false],['viewer','viewer',true],['member','member',true],['owner','owner',false]]) {
  test(`${actor} removes/leaves ${target}`,async()=>assert.equal(await commit(actor,[
    del(`families/f/members/${target}`),del(`membershipIndex/${target}`)]),ok?200:403));
}
test('partial removal and private-user cross-write denied',async()=>{
  denied(await commit('owner',[del('families/f/members/member')]));
  denied(await commit('owner',[del('membershipIndex/member')]));
  denied(await commit('owner',[set('users/member',{familyId:null})]));
});
test('archive blocks data, member can leave, owner can restore',async()=>{
  allowed(await commit('owner',[set('families/f',{state:'archived'},{mask:['state'],server:['updatedAt']})]));
  denied(await status('member','families/f/pantryItems/rice'));
  denied(await commit('owner',[set('families/f/pantryItems/x',pantry())]));
  allowed(await commit('member',[del('families/f/members/member'),del('membershipIndex/member')]));
  allowed(await commit('owner',[set('families/f',{state:'active'},{mask:['state'],server:['updatedAt']})]));
});
test('hard delete denied even owner',async()=>denied(await commit('owner',[del('families/f')])));
test('cross-household reads/writes and private secrets denied',async()=>{
  denied(await status('member','families/g/pantryItems/rice'));
  denied(await commit('member',[set('families/g/pantryItems/x',pantry())]));
  denied(await status('member','users/owner/secrets/llmConfig'));
  allowed(await status('owner','users/owner/secrets/llmConfig'));
});
test('field injection into membership, household, shared data denied',async()=>{
  denied(await commit('owner',[set('families/f/members/member',{isAdmin:true},{mask:['isAdmin']})]));
  denied(await commit('owner',[set('families/f',{memberUids:['outsider']},{mask:['memberUids'],server:['updatedAt']})]));
  denied(await commit('member',[set('families/f/pantryItems/x',{...pantry(),role:'owner'})]));
  denied(await commit('member',[set('families/f/unknown/x',{payload:'denied'})]));
});
test('activity actor identity immutable and no arbitrary payload',async()=>{
  const data={actorUid:'member',type:'general',createdAt:now(),relatedPlanId:null,targetId:null,includeSelf:false};
  allowed(await commit('member',[set('families/f/activity/e',data,{server:['createdAt']})]));
  denied(await commit('member',[set('families/f/activity/e',{includeSelf:true},{mask:['includeSelf']})]));
  denied(await commit('member',[set('families/f/activity/x',{...data,actorUid:'owner'},{server:['createdAt']})]));
  denied(await commit('member',[set('families/f/activity/x',{...data,body:'untrusted payload'},{server:['createdAt']})]));
  denied(await commit('member',[set('families/f/activity/x',{...data,type:'memberRoleChanged'},{server:['createdAt']})]));
});
test('notification receipts private to viewer; no fan-out writes',async()=>{
  const receipt={read:true,dismissed:false,updatedAt:now()};
  allowed(await commit('viewer',[set('users/viewer/notificationReceipts/household:f:e',receipt,{server:['updatedAt']})]));
  denied(await status('owner','users/viewer/notificationReceipts/household:f:e'));
  denied(await commit('owner',[set('users/member/notificationReceipts/e',receipt,{server:['updatedAt']})]));
  denied(await commit('owner',[set('users/member/notifications/e',{title:'denied'})]));
});
test('removed member immediately loses shared reads and writes',async()=>{
  allowed(await commit('owner',[del('families/f/members/member'),del('membershipIndex/member')]));
  denied(await status('member','families/f/pantryItems/rice'));
  denied(await commit('member',[set('families/f/pantryItems/x',pantry())]));
});
test('demoted invitation issuer loses ability to admit members',async()=>{
  const invitation=await issue('admin'); allowed(invitation.result);
  allowed(await commit('owner',[set('families/f/members/admin',{role:'member'},{mask:['role']})]));
  denied(await commit('outsider',redeemWrites(invitation.code,'outsider','f','member','admin')));
});
test('invitation expiry extension and field injection denied',async()=>{
  const invitation=await issue(); allowed(invitation.result);
  denied(await commit('owner',[set(`householdInvitations/${invitation.code}`,{expiresAt:later()},{mask:['expiresAt']})]));
  denied(await commit('owner',[set(`householdInvitations/${invitation.code}`,{isAdmin:true},{mask:['isAdmin']})]));
});
test('join races with revocation without half-created membership',async()=>{
  const invitation=await issue();allowed(invitation.result);
  const outcomes=await Promise.all([
    commit('outsider',redeemWrites(invitation.code,'outsider')),
    commit('owner',[set(`householdInvitations/${invitation.code}`,{state:'revoked'},{mask:['state']})])]);
  assert.equal(outcomes.filter(x=>x===200).length,1);
  const indexStatus=await status('outsider','membershipIndex/outsider');
  assert.equal(indexStatus,outcomes[0]===200?200:404);
});
test('owner can leave archived household; never active last owner',async()=>{
  allowed(await commit('owner',[set('families/f',{state:'archived'},{mask:['state'],server:['updatedAt']})]));
  allowed(await commit('owner',[del('families/f/members/owner'),del('membershipIndex/owner')]));
  denied(await status('owner','families/f/pantryItems/rice'));
});
test('wrong recipient cannot accept transfer and incomplete transfer denied',async()=>{
  allowed(await commit('owner',[set('families/f/ownershipTransfers/pending',{
    fromUid:'owner',toUid:'member',createdAt:now(),expiresAt:later()},{server:['createdAt']})]));
  denied(await commit('admin',[set('families/f',{ownerUid:'admin'},{mask:['ownerUid'],server:['updatedAt']})]));
  denied(await commit('member',[set('families/f/members/member',{role:'owner'},{mask:['role']})]));
});
test('type and oversized string validation',async()=>{
  denied(await commit('member',[set('families/f/pantryItems/x',{...pantry(),name:'x'.repeat(201)})]));
  denied(await commit('member',[set('families/f/pantryItems/x',{...pantry(),quantity:2})]));
  denied(await commit('member',[set('families/f/members/member',{name:{role:'owner'}},{mask:['name']})]));
});
function meal(title='Soup') {
  return {title,subtitle:null,imageUrl:null,cuisine:null,mealType:'Dinner',dayIndex:2,prepTime:null,cookTime:null,
    servings:null,calories:null,protein:null,carbs:null,fats:null,badgeText:null,ingredients:[{name:'Rice',amount:'1 cup'}],
    instructions:['Cook'],availableIngredients:[],missingIngredients:[],tags:[],reasoning:null,imageSearchQuery:null,
    youtubeSearchQuery:null,status:'pending',accepted:false,replacedByMealId:null,replacedMealId:null,isFavorite:false,createdAt:now()};
}
test('representative complete recipe and nested schema injection',async()=>{
  allowed(await commit('SEED',[set('families/f/mealPlans/p',{title:'Fixture'})]));
  allowed(await commit('member',[set('families/f/mealPlans/p/meals/m',meal())]));
  denied(await commit('member',[set('families/f/mealPlans/p/meals/x',{...meal(),ingredients:[{name:'Rice',amount:'1',role:'owner'}]})]));
  denied(await commit('member',[set('families/f/mealPlans/p/meals/x',{...meal(),instructions:[{malicious:true}]})]));
});
test('replacement requires reciprocal links and immutable successor',async()=>{
  allowed(await commit('SEED',[set('families/f/mealPlans/p',{title:'Fixture'}),set('families/f/mealPlans/p/meals/old',meal())]));
  denied(await commit('member',[set('families/f/mealPlans/p/meals/old',{status:'replaced',replacedByMealId:'new'},
    {mask:['status','replacedByMealId']})]));
  allowed(await commit('member',[
    set('families/f/mealPlans/p/meals/old',{status:'replaced',replacedByMealId:'new'},{mask:['status','replacedByMealId']}),
    set('families/f/mealPlans/p/meals/new',{...meal('Replacement'),replacedMealId:'old'})]));
  denied(await commit('member',[
    set('families/f/mealPlans/p/meals/old',{replacedByMealId:'other'},{mask:['replacedByMealId']}),
    set('families/f/mealPlans/p/meals/other',{...meal('Other'),replacedMealId:'old'})]));
});
test('meal grocery receipts retain strict role and schema validation', async()=>{
  allowed(await commit('SEED',[set('families/f/groceryLists/default',{title:'Shopping',createdAt:now()})]));
  const receipt={name:'onion',quantity:'2 unit',category:'NEEDED FOR MEALS',checked:true,status:'used',tag:null,addedBy:'member',sourceMealPaths:['families/f/mealPlans/p/meals/m']};
  allowed(await commit('member',[set('families/f/groceryLists/default/items/meal_onion',receipt)]));
  denied(await commit('viewer',[set('families/f/groceryLists/default/items/meal_other',receipt)]));
  denied(await commit('outsider',[set('families/f/groceryLists/default/items/meal_other',receipt)]));
  denied(await commit('member',[set('families/f/groceryLists/default/items/bad',{...receipt,sourceMealPaths:[{role:'owner'}]})]));
  denied(await commit('member',[set('families/f/groceryLists/default/items/bad',{...receipt,sourceMealPaths:'not-a-list'})]));
  denied(await commit('member',[set('families/f/groceryLists/default/items/bad',{...receipt,role:'owner'})]));
});
test('normal multi-ingredient recipe and plan save batch fit rule budget', async()=>{
  const plan={title:'Week',startDate:now(),endDate:later(),numberOfDays:7,mealTypes:['Dinner'],cuisinePreferences:['Filipino'],prioritizePantry:true,selectedMemberIds:['profile'],estimatedCost:null,groceryListId:null,status:'active',createdBy:'member',createdAt:now()};
  const recipe={...meal(),ingredients:Array.from({length:8},(_,i)=>({name:`Ingredient ${i}`,amount:'1 cup'})),instructions:Array.from({length:6},(_,i)=>`Step ${i}`),availableIngredients:['Rice','Onion'],missingIngredients:['Chicken'],tags:['Dinner']};
  allowed(await commit('SEED',[set('families/f/mealPlans/diagnostic',plan)]));
  assert.equal(await commit('member',[set('families/f/mealPlans/diagnostic/meals/m',recipe)]),200,'standalone realistic recipe');
  allowed(await commit('member',[set('families/f/mealPlans/full',plan),set('families/f/mealPlans/full/meals/m',recipe),set('families/f/activity/save-full',{actorUid:'member',type:'mealPlanSaved',createdAt:now(),relatedPlanId:'full',targetId:null,includeSelf:true},{server:['createdAt']})]));
  denied(await commit('member',[set('families/f/mealPlans/full/meals/m',{ingredients:[...recipe.ingredients,{name:'Bad',amount:'1',role:'owner'}]},{mask:['ingredients']})]));
});
test('pantry mutation and activity batch permits members but never viewers',async()=>{
  const event={actorUid:'member',type:'pantryItemUpdated',createdAt:now(),relatedPlanId:null,targetId:'rice',includeSelf:false};
  allowed(await commit('member',[set('families/f/pantryItems/rice',{quantity:'4 cups'},{mask:['quantity']}),set('families/f/activity/pantry',event,{server:['createdAt']})]));
  denied(await commit('viewer',[set('families/f/pantryItems/rice',{quantity:'100'},{mask:['quantity']}),set('families/f/activity/forbidden',{...event,actorUid:'viewer'},{server:['createdAt']})]));
});
test('string list bulk validation rejects coercion and oversized entries',async()=>{
  const profile={name:'Dependent',relation:null,age:12,preferences:[],restrictions:[],createdAt:now()};
  for (const bad of [42,true,null,{},[],['nested'],'x'.repeat(1001),'x\u001fy']) {
    const result = await commit('member',[set('families/f/familyMembers/bad',{...profile,restrictions:['safe',bad]})]);
    if (Array.isArray(bad)) assert.equal(result,400,'Firestore rejects nested arrays before rules');
    else denied(result);
  }
  for (const [label, restrictions] of [['newline',['line one\nline two']],['boundary',['x'.repeat(1000)]],['empty',['']],['mixed',['line one\nline two','x'.repeat(1000),'']]]) {
    assert.equal(await commit('member',[set('families/f/familyMembers/good',{...profile,restrictions})]),200,label);
  }
});
test('full 21-meal weekly plan batch respects rule access limits',async()=>{
  const plan={title:'Week',startDate:now(),endDate:later(),numberOfDays:7,mealTypes:['Breakfast','Lunch','Dinner'],cuisinePreferences:['Filipino'],prioritizePantry:true,selectedMemberIds:['profile'],estimatedCost:null,groceryListId:null,status:'active',createdBy:'member',createdAt:now()};
  const writes=[set('families/f/mealPlans/week',plan)];
  for(let i=0;i<21;i++) writes.push(set(`families/f/mealPlans/week/meals/m${i}`,{...meal(),dayIndex:Math.floor(i/3),mealType:plan.mealTypes[i%3],ingredients:Array.from({length:8},(_,n)=>({name:`Ingredient ${n}`,amount:'1 cup'})),instructions:Array.from({length:6},(_,n)=>`Step ${n}`)}));
  writes.push(set('families/f/activity/weekly',{actorUid:'member',type:'mealPlanSaved',createdAt:now(),relatedPlanId:'week',targetId:null,includeSelf:true},{server:['createdAt']}));
  allowed(await commit('member',writes));
});
// Synthetic full serializer shape: the captured failure had 10 ingredients and
// populated optional recipe text. No account IDs or generated recipe are reused.
const mealOptionalTextLimits={subtitle:1000,imageUrl:2048,cuisine:100,mealType:100,
  prepTime:100,cookTime:100,servings:100,calories:100,protein:100,carbs:100,fats:100,
  badgeText:200,reasoning:4000,imageSearchQuery:500,youtubeSearchQuery:500,
  replacedByMealId:128,replacedMealId:128};
function fullOptionalMeal(ingredientCount=10) {
  return {...meal('Synthetic complete recipe'),
    subtitle:'Synthetic dinner fixture with every optional recipe field populated.',
    imageUrl:'https://example.invalid/fixture.jpg',cuisine:'Filipino',mealType:'Dinner',
    prepTime:'15 minutes',cookTime:'30 minutes',servings:'4 servings',calories:'450 kcal',
    protein:'25 g',carbs:'50 g',fats:'15 g',badgeText:'Pantry friendly',
    ingredients:Array.from({length:ingredientCount},(_,i)=>({name:`Synthetic ingredient ${i}`,amount:'1/2 cup'})),
    instructions:Array.from({length:8},(_,i)=>`Synthetic step ${i}: prepare and combine the measured ingredients, then cook as directed.`),
    availableIngredients:['Synthetic ingredient 0','Synthetic ingredient 1'],
    missingIngredients:Array.from({length:8},(_,i)=>`Synthetic ingredient ${i+2}`),
    tags:['Dinner','Synthetic fixture'],
    reasoning:'Synthetic measured recipe used only to exercise strict schema validation and the rules expression budget.',
    imageSearchQuery:'Synthetic dinner recipe',youtubeSearchQuery:'Synthetic dinner cooking instructions'};
}
function fullOptionalPlan(createdBy='member') {
  return {title:'Synthetic week',startDate:now(),endDate:later(),numberOfDays:7,
    mealTypes:['Breakfast','Lunch','Dinner'],cuisinePreferences:['Filipino'],prioritizePantry:true,
    selectedMemberIds:['profile'],estimatedCost:'1000',groceryListId:null,status:'active',createdBy,createdAt:now()};
}
test('full optional 10-ingredient recipe saves atomically in private and household plans',async()=>{
  const plan=fullOptionalPlan();
  const recipe=fullOptionalMeal();
  allowed(await commit('member',[set('users/member/mealPlans/full-optional',plan),
    set('users/member/mealPlans/full-optional/meals/m',recipe)]));
  allowed(await commit('member',[set('families/f/mealPlans/full-optional',plan),
    set('families/f/mealPlans/full-optional/meals/m',recipe),
    set('families/f/activity/full-optional',{actorUid:'member',type:'mealPlanSaved',createdAt:now(),
      relatedPlanId:'full-optional',targetId:null,includeSelf:true},{server:['createdAt']})]));
});
test('full optional 21-meal weekly plan batch fits the rules budget',async()=>{
  const plan=fullOptionalPlan();
  const writes=[set('families/f/mealPlans/full-week',plan)];
  for(let i=0;i<21;i++) writes.push(set(`families/f/mealPlans/full-week/meals/m${i}`,{
    ...fullOptionalMeal(),dayIndex:Math.floor(i/3),mealType:plan.mealTypes[i%3]}));
  writes.push(set('families/f/activity/full-week',{actorUid:'member',type:'mealPlanSaved',createdAt:now(),
    relatedPlanId:'full-week',targetId:null,includeSelf:true},{server:['createdAt']}));
  allowed(await commit('member',writes));
});
test('optional meal scalar validation preserves null missing and exact size boundaries',async()=>{
  allowed(await commit('SEED',[set('families/f/mealPlans/p',{title:'Fixture'})]));
  const ordinaryFields=Object.entries(mealOptionalTextLimits).filter(([key])=>!key.startsWith('replaced'));
  const boundary=meal();
  const absent=meal();
  const nulls=meal();
  for(const [key,max] of ordinaryFields) {
    boundary[key]='x'.repeat(max);
    delete absent[key];
    nulls[key]=null;
  }
  allowed(await commit('member',[set('families/f/mealPlans/p/meals/boundary',boundary)]));
  allowed(await commit('member',[set('families/f/mealPlans/p/meals/absent',absent)]));
  allowed(await commit('member',[set('families/f/mealPlans/p/meals/nulls',nulls)]));
  denied(await commit('member',[set('families/f/mealPlans/p/meals/injected',{...fullOptionalMeal(),role:'owner'})]));
});
test('every optional meal scalar rejects wrong types nested injection and oversize text',async()=>{
  allowed(await commit('SEED',[set('families/f/mealPlans/p',{title:'Fixture'})]));
  for(const [key,max] of Object.entries(mealOptionalTextLimits)) {
    for(const invalid of [1,false,[],{role:'owner'},'x'.repeat(max+1)]) {
      assert.equal(await commit('member',[set('families/f/mealPlans/p/meals/invalid',{
        ...meal(),[key]:invalid})]),403,`${key} must retain its type and length restrictions`);
    }
  }
  // Prove the exact two-key ingredient schema and tuple status checks retain
  // their type/allowlist behavior in the full ten-entry fast path.
  const ordinary={...meal(),ingredients:Array.from({length:10},()=>({name:'Rice',amount:'1 cup'}))};
  allowed(await commit('member',[set('families/f/mealPlans/p/meals/schema-control',ordinary)]));
  for(const invalid of [null,1,true,'aa',{}, {name:'Rice'}, {amount:'1'},
    {name:'Rice',role:'owner'}, {name:'Rice',amount:1}, {name:1,amount:'1'},
    {name:'Rice',amount:'1',role:'owner'}, {name:'x'.repeat(201),amount:'1'},
    {name:'Rice',amount:'x'.repeat(101)}]) {
    for(const position of [0,9]) {
      const ingredients=ordinary.ingredients.slice();ingredients[position]=invalid;
      denied(await commit('member',[set('families/f/mealPlans/p/meals/ingredient-injection',{...ordinary,ingredients})]));
    }
  }
  for(const accepted of [1,'false',null,{},[]]) {
    denied(await commit('member',[set('families/f/mealPlans/p/meals/invalid-accepted',{...meal(),accepted})]));
  }
});
test('128-character replacement links remain reciprocal and immutable',async()=>{
  const oldId='a'.repeat(128),newId='b'.repeat(128);
  allowed(await commit('SEED',[set('families/f/mealPlans/p',{title:'Fixture'}),
    set(`families/f/mealPlans/p/meals/${oldId}`,meal())]));
  allowed(await commit('member',[
    set(`families/f/mealPlans/p/meals/${oldId}`,{status:'replaced',replacedByMealId:newId},
      {mask:['status','replacedByMealId']}),
    set(`families/f/mealPlans/p/meals/${newId}`,{...meal('Successor'),replacedMealId:oldId})]));
  denied(await commit('member',[set(`families/f/mealPlans/p/meals/${newId}`,{replacedMealId:null},
    {mask:['replacedMealId']})]));
});
test('optional meal text retains Unicode and control-character size semantics',async()=>{
  allowed(await commit('SEED',[set('families/f/mealPlans/p',{title:'Fixture'})]));
  const samples=['','x'.repeat(100),'x'.repeat(101),'é'.repeat(100),'é'.repeat(101),
    '😀'.repeat(50),'😀'.repeat(51),'😀'.repeat(100),'😀'.repeat(101),
    'e\u0301'.repeat(50),'e\u0301'.repeat(51),'line one\nline two','tab\tvalue','unit\u001fseparator'];
  for(const quantity of samples) {
    // Compare to the unchanged explicit string type/size validator rather than
    // assuming how the emulator counts supplementary or combining characters.
    const expected=await commit('member',[set('families/f/pantryItems/unicode',{...pantry(),quantity})]);
    assert.ok([200,403].includes(expected),'unchanged size validator must execute');
    assert.equal(await commit('member',[set('families/f/mealPlans/p/meals/unicode',{
      ...meal(),prepTime:quantity})]),expected,
      `optional text size differs: UTF16=${quantity.length}, UTF8=${Buffer.byteLength(quantity)}, scalars=${[...quantity].length}`);
  }
});
if (listOnly) { console.log(cases.map(([name])=>name).join('\n')); console.log(`${cases.length} acceptance cases`); process.exit(0); }
// Private LOCAL emulator diagnostics; never changes assertions or permissions.
// Capture deltas around the failing populated recipe to locate repeated work.
async function captureBudgetCoverage(label) {
  try {
    const response=await fetch(`http://${host}/emulator/v1/projects/${project}:ruleCoverage`,{
      signal:AbortSignal.timeout(10000),redirect:'error'});
    assert.equal(response.status,200);
    const {mkdir,writeFile}=await import('node:fs/promises');
    const folder=new URL('../../build/cloudtest-private/evidence/',import.meta.url);
    await mkdir(folder,{recursive:true});
    await writeFile(new URL(`budget-${Date.now()}-${label}.json`,folder),await response.text(),{flag:'wx'});
  } catch (_) { console.warn('Local budget coverage unavailable; acceptance result unchanged.'); }
}
let failures=0;
for(const [name,fn] of cases) {
  const trace=name==='full optional 10-ingredient recipe saves atomically in private and household plans';
  if(trace) await captureBudgetCoverage('before');
  try {await reset();await fn();console.log(`PASS ${name}`);}
  catch(error) {failures++;console.error(`FAIL ${name}: ${error.message}`);}
  finally {if(trace) await captureBudgetCoverage('after');}
}
console.log(`${cases.length-failures}/${cases.length} emulator acceptance cases passed`);
process.exitCode=failures?1:0;

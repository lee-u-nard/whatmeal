// Bounded diagnostics against only disposable test-account documents. No AI call.
const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const project='whatmeal-gemini-test-20261019';
(async()=>{
  const fixture=JSON.parse(fs.readFileSync(path.join(root,'build/cloudtest-private/accounts.json')));
  const config=JSON.parse(fs.readFileSync(path.join(root,'build/cloud-test/google-services.json')));
  if(fixture.project!==project||config.project_info.project_id!==project)throw new Error('Scope mismatch');
  const client=config.client.find(c=>c.client_info.android_client_info.package_name==='com.example.whatmeal.cloudtest');
  const key=client.api_key[0].current_key;
  const account=fixture.accounts.owner;
  const auth=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:account.email,password:account.password,returnSecureToken:true})});
  const session=await auth.json();if(!auth.ok||session.localId!==account.uid)throw new Error('Test sign-in failed');
  const base=`projects/${project}/databases/(default)/documents`;
  const plan=`${base}/users/${account.uid}/mealPlans/cloud-schema-probe-${Date.now()}`;
  const value=x=>x===null?{nullValue:null}:typeof x==='string'?{stringValue:x}:typeof x==='boolean'?{booleanValue:x}:typeof x==='number'?{integerValue:String(x)}:Array.isArray(x)?{arrayValue:{values:x.map(value)}}:{mapValue:{fields:fields(x)}};
  const fields=x=>Object.fromEntries(Object.entries(x).map(([k,v])=>[k,value(v)]));
  const write=(name,data)=>({update:{name,fields:fields(data)},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]});
  const parent={title:'Cloud schema probe',startDate:null,endDate:null,numberOfDays:1,mealTypes:['Dinner'],cuisinePreferences:['Filipino'],prioritizePantry:true,selectedMemberIds:['synthetic-profile'],estimatedCost:null,groceryListId:null,status:'active',createdBy:account.uid};
  const meal={title:'Synthetic recipe probe',subtitle:null,imageUrl:null,cuisine:'Filipino',mealType:'Dinner',dayIndex:0,prepTime:'10 minutes',cookTime:'20 minutes',servings:'1',calories:'300 kcal',protein:'20 g',carbs:'30 g',fats:'10 g',badgeText:null,ingredients:[{name:'Rice',amount:'1 cup'}],instructions:['Cook the rice.'],availableIngredients:[],missingIngredients:['Rice'],tags:[],reasoning:null,imageSearchQuery:null,youtubeSearchQuery:null,status:'pending',accepted:false,replacedByMealId:null,replacedMealId:null,isFavorite:false};
  async function commit(writes){const r=await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`,{method:'POST',headers:{Authorization:`Bearer ${session.idToken}`,'Content-Type':'application/json'},body:JSON.stringify({writes})}); const data=await r.json();return {http:r.status,status:data.error?.status??'OK'};}
  const results=[];
  results.push({case:'atomic-parent-and-meal',...await commit([write(plan,parent),write(`${plan}/meals/probe`,meal)])});
  if(results[0].http===200){results.push({case:'remove-only-probe',...await commit([{delete:`${plan}/meals/probe`},{delete:plan}])});}
  else {results.push({case:'parent-only',...await commit([write(plan,parent)])});if(results.at(-1).http===200)results.push({case:'remove-only-probe',...await commit([{delete:plan}])});}
  fs.writeFileSync(path.join(__dirname,'schema-probe.json'),JSON.stringify({project,aiRequests:0,results},null,2));
  console.log(JSON.stringify({project,aiRequests:0,results}));
})().catch(()=>{console.error('Scoped schema probe failed; no raw errors or credentials printed.');process.exitCode=1;});

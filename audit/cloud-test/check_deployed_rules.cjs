// Read ONLY the approved new project's active Firestore rule source. Local
// executed evidence must match before authentication or any network operation.
const fs=require('node:fs'); const path=require('node:path'); const crypto=require('node:crypto');
const project='whatmeal-gemini-test-20261019';
(async()=>{
  const verified=require('./candidate_evidence.cjs').readVerifiedCandidate();
  const cliRoot=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib');
  const {getGlobalDefaultAccount}=require(path.join(cliRoot,'auth'));
  const {requireAuth}=require(path.join(cliRoot,'requireAuth'));
  const rules=require(path.join(cliRoot,'gcp/rules'));
  await requireAuth({project,nonInteractive:true,...getGlobalDefaultAccount()});
  const releases=await rules.listAllReleases(project);
  const name=await rules.getLatestRulesetName(project,'cloud.firestore',releases);
  if(!name?.startsWith(`projects/${project}/rulesets/`)) throw new Error('Unexpected rule project.');
  const files=await rules.getRulesetContent(name);
  if(!Array.isArray(files)||files.length!==1||typeof files[0].content!=='string') throw new Error('Unexpected rule files.');
  const source=files[0].content;
  fs.writeFileSync(path.resolve(__dirname,'../../build/cloud-test/explicit-deployed.rules'),source);
  const normalize=s=>s.replace(/\r\n/g,'\n').trim();
  const status={project,activeSourceMatchesReviewedRules:normalize(source)===normalize(verified.source),
    comparedAgainst:'audit/cloud-test/recipe-budget-candidate.rules',
    candidateSha256:verified.sha256,securityPassed:verified.verification.passed,securityTotal:verified.verification.total,
    sourceSha256:crypto.createHash('sha256').update(source).digest('hex')};
  const report=path.join(__dirname,'deployed-rules-check.json');
  if(fs.existsSync(report)){
    const archive=path.join(__dirname,'attempts',`deployed-check-${Date.now()}.json`);
    fs.mkdirSync(path.dirname(archive),{recursive:true});
    fs.copyFileSync(report,archive,fs.constants.COPYFILE_EXCL);
  }
  fs.writeFileSync(report,JSON.stringify(status,null,2));
  console.log(JSON.stringify(status));
  if(!status.activeSourceMatchesReviewedRules)process.exitCode=1;
})().catch(()=>{console.error('Explicit test-project rule verification failed; no credentials printed.');process.exitCode=1;});

const fs = require('node:fs');
const path = require('node:path');
const [input, output] = process.argv.slice(2);
let text = fs.readFileSync(input,'utf8');
const fixture = path.resolve(__dirname,'../../build/cloudtest-private/accounts.json');
if (fs.existsSync(fixture)) {
  const data=JSON.parse(fs.readFileSync(fixture,'utf8'));
  for(const account of Object.values(data.accounts)) for(const value of Object.values(account)) {
    if(typeof value==='string') text=text.split(value).join('[TEST-ACCOUNT-REDACTED]');
  }
}
text=text.replace(/AIza[\w-]+/g,'[KEY-REDACTED]')
  .replace(/eyJ[\w.-]+/g,'[JWT-REDACTED]')
  .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi,'[UUID-REDACTED]')
  .replace(/(Bearer\s+)\S+/gi,'$1[TOKEN-REDACTED]')
  .replace(/((?:apiKey|oobCode|token|key)=)[^&\s]+/gi,'$1[REDACTED]')
  .replace(/(http:\/\/127\.0\.0\.1:\d+\/)\S+?\//g,'$1[VM-SESSION-REDACTED]/')
  .replace(/(about user \()[^)]+\)/g,'$1[UID-REDACTED])');
fs.writeFileSync(output,text);

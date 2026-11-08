// Integration check for this lab's Firebase rules. Requires a configured .env.
// Uses two dedicated test accounts, never a student's personal password.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, collection, query, where, onSnapshot, doc, setDoc, getDoc, getDocs, terminate } from 'firebase/firestore';
import { getStorage, connectStorageEmulator, ref, uploadBytes, getDownloadURL } from 'firebase/storage';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const env=Object.fromEntries(readFileSync(path.join(root,'expo/.env'),'utf8').replace(/^\uFEFF/,'').split(/\r?\n/).filter(x=>x.includes('=')&&!x.startsWith('#')).map(x=>{const i=x.indexOf('=');return [x.slice(0,i),x.slice(i+1)]}));
const config=Object.fromEntries(Object.entries({apiKey:'API_KEY',authDomain:'AUTH_DOMAIN',projectId:'PROJECT_ID',storageBucket:'STORAGE_BUCKET',messagingSenderId:'MESSAGING_SENDER_ID',appId:'APP_ID'}).map(([k,v])=>[k,env['EXPO_PUBLIC_FIREBASE_'+v]]));
const emulator=process.argv.includes('--emulator');
const local=path.join(root,'.local'); mkdirSync(local,{recursive:true});
const credentialsPath=path.join(local,'test-accounts.json');
const accounts=existsSync(credentialsPath)?JSON.parse(readFileSync(credentialsPath,'utf8')):{a:{email:'lab4-a@example.com',password:randomBytes(18).toString('base64url')},b:{email:'lab4-b@example.com',password:randomBytes(18).toString('base64url')}};
writeFileSync(credentialsPath,JSON.stringify(accounts,null,2));
const apps=[];
async function worker(name) {
  const app=initializeApp(config,'smoke-'+name+'-'+Date.now()); apps.push(app);
  const auth=getAuth(app), db=getFirestore(app);
  if(emulator){connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});connectFirestoreEmulator(db,'127.0.0.1',8080);}
  const account=accounts[name];
  let result;
  try {result=await createUserWithEmailAndPassword(auth,account.email,account.password);}
  catch(e){if(e.code!=='auth/email-already-in-use')throw e; result=await signInWithEmailAndPassword(auth,account.email,account.password);}
  return {app,auth,db,uid:result.user.uid};
}
async function adminToken() {
  if(emulator)return 'owner';
  const req=createRequire(import.meta.url);
  const tools=req(path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/auth.js'));
  const account=tools.getGlobalDefaultAccount();
  return (await tools.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform'])).access_token;
}
async function reassign(id,uid){
  const prefix=emulator?'http://127.0.0.1:8080':'https://firestore.googleapis.com';
  const url=`${prefix}/v1/projects/${config.projectId}/databases/(default)/documents/pins/${id}?updateMask.fieldPaths=assignedTo`;
  const result=await fetch(url,{method:'PATCH',headers:{Authorization:'Bearer '+await adminToken(),'Content-Type':'application/json'},body:JSON.stringify({fields:{assignedTo:{stringValue:uid}}})});
  assert.equal(result.status,200,'office reassignment must succeed: '+await result.text());
}
const listenerStops=[];
function waitForPins(w,count){return new Promise((resolve,reject)=>{
  const timeout=setTimeout(()=>reject(new Error('pin snapshot timeout for '+count)),30000);
  const stop=onSnapshot(query(collection(w.db,'pins'),where('assignedTo','==',w.uid)),snap=>{if(snap.size===count){clearTimeout(timeout);stop();resolve(snap);}},reject);
  listenerStops.push(stop);
});}
async function denied(action){await assert.rejects(action,e=>e.code==='permission-denied');}
let a,b;
try {
  a=await worker('a');b=await worker('b');
  const fixtures=JSON.parse(readFileSync(path.join(root,'expo/src/contract/fixtures/entrances.json'),'utf8'));
  // Existing seeded documents cannot be overwritten by a worker. Office reset
  // only changes assignment, leaving all surveyed data in its own collection.
  for(const p of fixtures){
    try{await setDoc(doc(a.db,'pins',p.id),{...p,assignedTo:a.uid});}
    catch(e){if(e.code!=='permission-denied')throw e;await reassign(p.id,a.uid);}
  }
  await waitForPins(a,20);await waitForPins(b,0);
  console.log('PASS sign-in and 20 assigned pins');
  const left=waitForPins(a,19),right=waitForPins(b,1);
  await reassign(fixtures[0].id,b.uid);await Promise.all([left,right]);
  console.log('PASS live reassignment A -> B');
  await denied(()=>getDoc(doc(a.db,'pins',fixtures[0].id)));
  await denied(()=>getDocs(collection(a.db,'pins')));
  await denied(()=>setDoc(doc(a.db,'pins',fixtures[0].id),{...fixtures[0],assignedTo:a.uid}));
  console.log('PASS ownership rules block other pins and reassignment by workers');
  const surveyFor=p=>({id:p.id,coordsConfirmed:true,correctedLat:null,correctedLng:null,street:p.street,number:p.number,entranceName:p.entranceName,addressConfirmed:true,stories:4,flats:20,elevators:1,yearBuilt:1980,groundFloorCommercial:false,comment:'Lab 4 integration test',surveyStatus:'submitted',surveyedBy:a.uid,surveyedAt:new Date().toISOString(),updatedAt:new Date().toISOString()});
  const survey=surveyFor(fixtures[1]);
  await setDoc(doc(a.db,'surveys',survey.id),survey);await setDoc(doc(a.db,'surveys',survey.id),survey);
  assert.equal((await getDoc(doc(a.db,'surveys',survey.id))).data().comment,survey.comment);
  await denied(()=>getDoc(doc(b.db,'surveys',survey.id)));
  console.log('PASS idempotent survey upload and private read');
  const offlineSurvey=surveyFor(fixtures[2]);
  await reassign(offlineSurvey.id,b.uid);
  await denied(()=>setDoc(doc(a.db,'surveys',offlineSurvey.id),offlineSurvey));
  console.log('PASS stale assignment refuses queued survey');
  if(emulator){
    const storage=getStorage(a.app);connectStorageEmulator(storage,'127.0.0.1',9199);
    const image=ref(storage,`photos/${a.uid}/${fixtures[1].id}/smoke.png`);
    await uploadBytes(image,Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0N8AAAAASUVORK5CYII=','base64'),{contentType:'image/png'});
    assert.match(await getDownloadURL(image),/smoke/);
    const other=getStorage(b.app);connectStorageEmulator(other,'127.0.0.1',9199);
    await assert.rejects(()=>uploadBytes(ref(other,`photos/${a.uid}/other.png`),new Uint8Array([1]),{contentType:'image/png'}),e=>e.code==='storage/unauthorized');
    console.log('PASS Storage emulator upload and cross-user refusal (road B)');
  }
  console.log('All Firebase integration checks passed. Credentials are in .local/test-accounts.json (git-ignored).');
} finally {
  for(const stop of listenerStops)stop();
  for(const w of [a,b])if(w)await terminate(w.db);
  await Promise.all(apps.map(deleteApp));
}

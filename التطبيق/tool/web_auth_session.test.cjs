// Session regression tests. Mocked official SDK; no real credentials or network.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(path.resolve(__dirname, '../../supabase-backend.js'), 'utf8');
const admin = {role:'admin',is_active:true,tenant_active:true};
const session = {user:{email:'test@example.com'}};
const settle = async () => { for(let i=0;i<12;i++) await Promise.resolve(); };
function fixture() {
  let event, profile = admin, currentSession = session, sessionRead = null;
  const calls = [], timers = new Map(); let counter = 0;
  const client = {
    async rpc() { if(profile instanceof Error) throw profile; return {data:profile,error:null}; },
    auth: {
      async signInWithPassword(){ return {data:session,error:null}; },
      async signOut(options){ calls.push(options); return {data:{},error:null}; },
      async getSession(){ return sessionRead ? sessionRead() : {data:{session:currentSession},error:null}; },
      onAuthStateChange(fn){event=fn;return {data:{subscription:{unsubscribe(){calls.push('unsubscribe')}}}};}
    }
  };
  const window = {dispatchEvent(){},IKILL_SUPABASE_ENV:{SUPABASE_URL:'https://example.supabase.co',SUPABASE_ANON_KEY:'public'},supabase:{createClient:()=>client}};
  vm.runInNewContext(source,{window,console,Event:class {},setTimeout(fn){const id=++counter;timers.set(id,fn);return id},clearTimeout(id){timers.delete(id)},setInterval(){},clearInterval(){}});
  return {auth:window.auth,calls,timers,setProfile(v){profile=v},setSession(v){currentSession=v},setRead(fn){sessionRead=fn},event(){event()},async tick(){const pending=[...timers.values()];timers.clear();for(const fn of pending)fn();await settle()}};
}
(async()=>{
  let count=0;
  let f=fixture();f.setProfile(new Error('network failure'));
  await assert.rejects(()=>f.auth.signIn('test@example.com','not-real'));assert.equal(f.calls.length,0);count++;
  f=fixture();f.setProfile({...admin,role:'technician'});
  await assert.rejects(()=>f.auth.signIn('test@example.com','not-real'));assert.equal(f.calls[0].scope,'local');count++;
  f=fixture();const users=[],errors=[];f.setProfile(new Error('temporarily unavailable'));
  const stop=f.auth.onSessionChanged(user=>users.push(user),error=>errors.push(error));await settle();
  assert.equal(users.length,0);assert.equal(errors.length,1);assert.equal(f.calls.length,0);count++;
  f.setProfile(admin);await f.tick();assert.equal(users[0].email,'test@example.com');count++;
  stop();assert.equal(f.timers.size,0);count++;
  f=fixture();let resolve;f.setRead(()=>new Promise(r=>{resolve=r}));
  const received=[];f.auth.onSessionChanged(user=>received.push(user));await settle();
  f.setRead(null);f.event();resolve({data:{session:null},error:null});await settle();
  assert.equal(received.length,0);await f.tick();assert.equal(received.length,1);assert.equal(received[0].email,'test@example.com');count++;
  f=fixture();const signedOut=[];f.setSession(null);f.auth.onSessionChanged(user=>signedOut.push(user));await settle();assert.equal(signedOut[0],null);count++;
  f=fixture();await f.auth.signOut();assert.equal(f.calls[0].scope,'local');count++;
  console.log(`PASS: ${count} website admin session regression scenarios.`);
})().catch(error=>{console.error(error);process.exitCode=1});

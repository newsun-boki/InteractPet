import {spawn} from 'node:child_process';
import {readFile,writeFile,mkdtemp} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';

const root=path.resolve(process.argv[2]),profile=await mkdtemp('/private/tmp/taro-gallery-qa-');
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
 '--headless=new','--disable-gpu','--no-sandbox','--disable-background-networking','--disable-extensions',
 '--disable-sync','--no-first-run','--no-default-browser-check','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'
],{stdio:['ignore','ignore','pipe']});
let stderr='';chrome.stderr.on('data',d=>{stderr=(stderr+d.toString()).slice(-6000)});
let ws;
try {
 let port;
 for(let i=0;i<100;i++){
  try{port=(await readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break}catch{}
  if(chrome.exitCode!==null)throw Error('Chrome exited: '+stderr);
  await new Promise(r=>setTimeout(r,100));
 }
 if(!port)throw Error('No browser debug port: '+stderr);
 const target=await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();
 ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject});
 let id=0;const pending=new Map(),errors=[];
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result)}}if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.text)};
 const call=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}))});
 const evaluate=async expression=>(await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true})).result.value;
 await call('Runtime.enable');await call('Page.enable');
 await call('Emulation.setDeviceMetricsOverride',{width:1200,height:1000,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url:pathToFileURL(path.join(root,'locomotion/index.html')).href});
 for(let i=0;i<100;i++){if(await evaluate("document.querySelectorAll('#pet option').length===11"))break;await new Promise(r=>setTimeout(r,100))}
 const media=await evaluate(`(async()=>{
 const pet=document.getElementById('pet'),v=document.getElementById('motion'),results=[];v.muted=true;
 for(const option of pet.options){
  const loaded=new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Video timed out')),8000);v.onloadeddata=()=>{clearTimeout(timer);resolve()};v.onerror=()=>reject(Error('Video failed'))});
  pet.value=option.value;pet.dispatchEvent(new Event('change'));await loaded;
  await v.play();await new Promise(r=>setTimeout(r,150));v.pause();
  results.push({id:option.value,duration:v.duration,width:v.videoWidth,played:v.currentTime>0});
 }
 pet.value='chameleon';const ready=new Promise(resolve=>v.onloadeddata=resolve);pet.dispatchEvent(new Event('change'));await ready;
 document.querySelector('[data-time="6"]').click();await new Promise(r=>setTimeout(r,300));v.pause();
 return {clips:results,seek:v.currentTime};})()`);
 if(media.clips.length!==11||media.clips.some(v=>v.duration!==9||v.width!==960||!v.played)||media.seek<6)throw Error('Video playback check failed: '+JSON.stringify(media));
 const shot=await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true});
 await writeFile(path.join(root,'verification/locomotion-gallery.png'),Buffer.from(shot.data,'base64'));
 await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
 const mobile=await evaluate('({viewport:innerWidth,content:document.documentElement.scrollWidth})');
 if(mobile.content>mobile.viewport+1||errors.length)throw Error('Layout or browser error');
 const result={passed:true,media,mobile,exceptions:errors};
 await writeFile(path.join(root,'verification/locomotion-gallery-checks.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
} finally {if(ws)ws.close();chrome.kill('SIGTERM');}

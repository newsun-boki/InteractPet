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
 await call('Emulation.setDeviceMetricsOverride',{width:1440,height:1100,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url:pathToFileURL(path.join(root,'index.html')).href});
 for(let i=0;i<100;i++){if(await evaluate("document.querySelectorAll('.card').length===20"))break;await new Promise(r=>setTimeout(r,100))}
 const images=await evaluate("(async()=>{document.querySelectorAll('img').forEach(i=>i.loading='eager');await Promise.all([...document.querySelectorAll('.card img')].map(i=>i.decode()));return {count:document.querySelectorAll('.card').length,broken:[...document.querySelectorAll('.card img')].filter(i=>!i.naturalWidth).length}})()");
 if(images.count!==20||images.broken)throw Error('Card images failed: '+JSON.stringify(images));
 const behavior=await evaluate(`(()=>{
  document.querySelector('[data-filter="original"]').click();const originalCount=document.querySelectorAll('.card').length;
  document.querySelector('.visual').click();const modal=document.querySelector('dialog').open;
  document.getElementById('pose').click();const reach=document.getElementById('large').getAttribute('src').endsWith('-reach.png');
  document.getElementById('background').click();const dark=document.getElementById('picture').classList.contains('dark');
  document.getElementById('close').click();document.querySelector('[data-filter="octopus"]').click();const octopusCount=document.querySelectorAll('.card').length;
  document.querySelector('[data-filter="all"]').click();return {originalCount,octopusCount,modal,reach,dark};})()`);
 if(behavior.originalCount!==10||behavior.octopusCount!==10||!behavior.modal||!behavior.reach||!behavior.dark)throw Error('Interaction failed');
 await evaluate("(async()=>{document.querySelectorAll('img').forEach(i=>i.loading='eager');await Promise.all([...document.querySelectorAll('.card img')].map(i=>i.decode()));return true})()");
 const metrics=await call('Page.getLayoutMetrics');
 const shot=await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true,clip:{x:0,y:0,width:1440,height:Math.ceil(metrics.cssContentSize.height),scale:1}});
 await writeFile(path.join(root,'verification/gallery-desktop.png'),Buffer.from(shot.data,'base64'));
 await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
 const mobile=await evaluate('({viewport:innerWidth,content:document.documentElement.scrollWidth})');
 if(mobile.content>mobile.viewport+1)throw Error('Mobile horizontal overflow');
 await call('Page.navigate',{url:pathToFileURL(path.join(root,'boundary/index.html')).href});
 for(let i=0;i<100;i++){if(await evaluate("document.querySelectorAll('#pet option').length===11"))break;await new Promise(r=>setTimeout(r,100))}
 const boundary=await evaluate(`(async()=>{
  const ids=[...document.querySelectorAll('#pet option')].map(o=>o.value);
  const loaded=await Promise.all(ids.flatMap(id=>Array.from({length:6},(_,pose)=>new Promise((resolve,reject)=>{const i=new Image();i.onload=()=>resolve(true);i.onerror=reject;i.src=id+'-'+pose+'.png'}))));
  const pet=document.getElementById('pet');pet.value='chameleon';pet.dispatchEvent(new Event('change'));
  document.querySelector('[data-pose="5"]').click();await document.getElementById('scene').decode();
  return {characters:ids.length,images:loaded.length,selected:document.getElementById('scene').getAttribute('src'),mobileOverflow:document.documentElement.scrollWidth>innerWidth+1};})()`);
 if(boundary.characters!==11||boundary.images!==66||boundary.selected!=='chameleon-5.png'||boundary.mobileOverflow)throw Error('Boundary gallery failed');
 await call('Emulation.setDeviceMetricsOverride',{width:1440,height:1100,deviceScaleFactor:1,mobile:false});
 const boundaryShot=await call('Page.captureScreenshot',{format:'png'});
 await writeFile(path.join(root,'verification/boundary-gallery.png'),Buffer.from(boundaryShot.data,'base64'));
 if(errors.length)throw Error('Browser exceptions: '+errors.join(';'));
 const result={passed:true,images,behavior,mobile,boundary,exceptions:errors};
 await writeFile(path.join(root,'verification/gallery-checks.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
} finally {if(ws)ws.close();chrome.kill('SIGTERM');}

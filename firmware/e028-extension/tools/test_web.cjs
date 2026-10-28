const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const elements={},requests=[];function el(){return {value:'0',selectedIndex:0,classList:{add(){},remove(){}},append(){},setPointerCapture(){}}}
const document={hidden:false,getElementById(id){return elements[id]??=(el())},createElement(){const e=el();(elements.buttons??=[]).push(e);return e},querySelectorAll(){return []}};
const context={document,window:{},AbortSignal,fetch:async(url)=>{requests.push(url);return {ok:true,text:async()=> 'FPGA status'}},setInterval(){}};vm.createContext(context);
const html=fs.readFileSync(require('node:path').join(__dirname,'../web/index.html'),'utf8');vm.runInContext(html.match(/<script>([\s\S]*)<\/script>/)[1],context);
const flush=()=>vm.runInContext('queue',context);
(async()=>{await flush();elements.t.selectedIndex=2;elements.t.onchange();await flush();assert(requests.includes('/c/T02'));
elements.s.selectedIndex=4;elements.s.onchange();await flush();assert(requests.includes('/c/S04'));
const e={preventDefault(){},pointerId:1};elements.buttons[0].onpointerdown(e);await flush();assert.equal(requests.at(-1),'/c/M00001000');elements.buttons[0].onpointerup(e);await flush();assert.equal(requests.at(-1),'/c/M00000000');
elements.buttons[1].onpointerdown(e);elements.stop.onclick();await flush();assert(!requests.includes('/c/M00004000'));assert.equal(requests.at(-1),'/c/H00');
console.log('PASS webpage timbre, screen, press/release, emergency stop drops stale notes');})().catch(e=>{console.error(e);process.exitCode=1});

import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,extname,sep} from 'node:path';
const opts=process.argv.slice(2), get=(key,fallback)=>opts.includes(key)?opts[opts.indexOf(key)+1]:fallback;
const root=fileURLToPath(new URL('./public/',import.meta.url));
const type={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg'};
const port=Number(get('--port','3000')), host=get('--host','127.0.0.1');
createServer(async(req,res)=>{try{const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);const path=resolve(root,'.'+(pathname==='/'?'/index.html':pathname));if(!path.startsWith(root.endsWith(sep)?root:root+sep))throw Error('Not found');const data=await readFile(path);res.writeHead(200,{'Content-Type':type[extname(path)]||'application/octet-stream'});res.end(data)}catch{res.writeHead(404);res.end('Not found')}}).listen(port,host,()=>console.log(`Preview: http://${host}:${port}`));

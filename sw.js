const CACHE="gc-pedidos-sb-v2"; // troque o número ao publicar uma nova versão
const SHELL=["./","index.html","config.js","manifest.json","icons/icon-192.png","icons/icon-512.png","instalar.html"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==CACHE).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
// Rede primeiro (sempre a versão mais nova); cache só como reserva sem internet.
self.addEventListener("fetch",e=>{
  if(e.request.method!=="GET")return;
  const h=new URL(e.request.url).hostname;
  if(h.endsWith("supabase.co")||h==="wa.me")return; // dados e WhatsApp nunca vão para o cache
  e.respondWith(fetch(e.request).then(r=>{if(r&&(r.ok||r.type==="opaque")){const c=r.clone();caches.open(CACHE).then(ch=>ch.put(e.request,c))}return r}).catch(()=>caches.match(e.request)));
});

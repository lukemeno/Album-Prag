import { useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { File } from 'expo-file-system';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';
import { PDFJS_MODULE_BASE64, PDFJS_WORKER_BASE64 } from '@/components/pdfjs-bundle';
import { PDFJS_STANDARD_FONTS_BASE64 } from '@/components/pdfjs-standard-fonts';
import { colors } from '@/domain/theme';

type ReaderMode = 'original' | 'extract';
interface Props { uri: string; mode: ReaderMode; onText?: (text: string) => void; onError?: (message: string) => void; }

function localURL(uri: string): boolean { return uri.startsWith('file://') || uri.startsWith('content://'); }

export function DocumentReader({ uri, mode, onText, onError }: Props) {
  const [busy, setBusy] = useState(mode === 'extract');
  const alive = useRef(true);
  const sent = useRef(false);
  const generation = useRef(0);
  const extractionTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => { alive.current = true; generation.current += 1; sent.current = false; return () => { alive.current = false; generation.current += 1; if (extractionTimer.current) clearTimeout(extractionTimer.current); }; }, [uri, mode]);

  const startExtraction = async (expectedGeneration: number) => {
    if (!alive.current || generation.current !== expectedGeneration || sent.current) return;
    sent.current = true;
    try {
      const bytes = await new File(uri).bytes();
      if (bytes.byteLength > 25_000_000) throw new Error('Das PDF ist größer als 25 MB.');
      const encoded = bytesToBase64(bytes);
      const chunkSize = 48_000;
      for (let offset = 0; offset < encoded.length; offset += chunkSize) {
        if (!alive.current || generation.current !== expectedGeneration) return;
        const chunk = encoded.slice(offset, offset + chunkSize);
        const script = `window.__appendPDF(${JSON.stringify(chunk)}); true;`;
        webViewRef.current?.injectJavaScript(script);
      }
      if (!alive.current || generation.current !== expectedGeneration) return;
      webViewRef.current?.injectJavaScript(`${mode === 'extract' ? 'window.__extractPDF();' : 'window.__renderPDF();'} true;`);
      if (mode === 'extract') extractionTimer.current = setTimeout(() => { if (alive.current && generation.current === expectedGeneration) { setBusy(false); onError?.('Die lokale PDF-Auslese hat zu lange gedauert. Bitte versuche es erneut.'); } }, 20_000);
    } catch (reason) {
      if (alive.current && generation.current === expectedGeneration) { setBusy(false); onError?.(reason instanceof Error ? reason.message : 'PDF konnte nicht gelesen werden.'); }
    }
  };

  const onMessage = (event: WebViewMessageEvent) => {
    if (!alive.current) return;
    if (extractionTimer.current) clearTimeout(extractionTimer.current);
    try {
      const message = JSON.parse(event.nativeEvent.data) as { type?: string; text?: string; message?: string };
      if (message.type === 'text' && typeof message.text === 'string') { setBusy(false); onText?.(message.text.slice(0, 100_000)); }
      if (message.type === 'error') { setBusy(false); onError?.(message.message ?? 'PDF-Text konnte nicht gelesen werden.'); }
    } catch { if (alive.current) { setBusy(false); onError?.('Die PDF-Antwort war ungültig.'); } }
  };

  const webViewRef = useRef<WebView>(null);
  const source = useMemo(() => ({ html: extractionHTML(PDFJS_MODULE_BASE64, PDFJS_WORKER_BASE64, PDFJS_STANDARD_FONTS_BASE64, mode === 'original'), baseUrl: 'about:blank' }), [mode]);
  return <View style={styles.root}>
    {mode === 'original' && !localURL(uri) && <Text style={styles.error}>Das Original ist nur lokal erlaubt.</Text>}
    {mode === 'extract' && busy && <View style={styles.overlay}><ActivityIndicator color={colors.red} /><Text style={styles.status}>PDF-Text wird lokal ausgelesen …</Text></View>}
    <WebView ref={webViewRef} source={source} originWhitelist={['about:blank', 'data:']} javaScriptEnabled domStorageEnabled={false} allowFileAccess={false} allowFileAccessFromFileURLs={false} allowUniversalAccessFromFileURLs={false} onLoadEnd={() => { void startExtraction(generation.current); }} onMessage={onMessage} onShouldStartLoadWithRequest={(request) => request.url === 'about:blank' || request.url.startsWith('data:')} style={styles.web} />
  </View>;
}

function bytesToBase64(bytes: Uint8Array): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let output = '';
  for (let index = 0; index < bytes.length; index += 3) { const a = bytes[index] ?? 0; const b = bytes[index + 1] ?? 0; const c = bytes[index + 2] ?? 0; const value = (a << 16) | (b << 8) | c; output += alphabet[(value >> 18) & 63] + alphabet[(value >> 12) & 63] + (index + 1 < bytes.length ? alphabet[(value >> 6) & 63] : '=') + (index + 2 < bytes.length ? alphabet[value & 63] : '='); }
  return output;
}

function extractionHTML(moduleBase64: string, workerBase64: string, standardFonts: Record<string, string>, renderOriginal: boolean): string {
  const render = renderOriginal ? '<div class="toolbar"><button onclick="previous()">‹</button><span id="page">Seite 1</span><button onclick="next()">›</button><button onclick="zoom(-0.2)">−</button><button onclick="zoom(0.2)">+</button></div><canvas id="canvas"></canvas>' : '<p>Text wird lokal gelesen …</p>';
  return `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' data: blob:; style-src 'unsafe-inline'; worker-src blob:; img-src data: blob:; font-src data: blob:; connect-src 'none'"><style>body{margin:0;background:#f4efe4;color:#1c1915;font:15px system-ui;text-align:center;overflow:auto}.toolbar{display:flex;gap:8px;justify-content:center;align-items:center;padding:8px;background:#fbf8f2;position:sticky;top:0}.toolbar button{border:1px solid #ddd3c2;border-radius:16px;background:#fff;padding:5px 12px;font-size:17px}canvas{background:#fff;display:block;height:auto;margin:12px auto;box-shadow:0 2px 10px #0002}</style></head><body>${render}<script>
  const moduleBase64=${JSON.stringify(moduleBase64)}; const workerBase64=${JSON.stringify(workerBase64)}; const standardFonts=${JSON.stringify(standardFonts)}; let chunks='';
  const decode=(value)=>Uint8Array.from(atob(value), character=>character.charCodeAt(0));
  class LocalStandardFontDataFactory { fetch({filename}) { const encoded=standardFonts[filename]; if(!encoded) return Promise.reject(new Error('Missing local standard font')); return Promise.resolve(decode(encoded)); } }
  window.__appendPDF=(chunk)=>{chunks+=chunk;};
  window.__extractPDF=async()=>{try { const lib=await import('data:text/javascript;base64,'+moduleBase64); lib.GlobalWorkerOptions.workerSrc=URL.createObjectURL(new Blob([decode(workerBase64)],{type:'text/javascript'})); const pdf=await lib.getDocument({data:decode(chunks),disableAutoFetch:true,disableStream:true,useSystemFonts:true,StandardFontDataFactory:LocalStandardFontDataFactory,standardFontDataUrl:'local:'}).promise; let text=''; for(let pageNumber=1;pageNumber<=pdf.numPages;pageNumber+=1){const page=await pdf.getPage(pageNumber); const content=await page.getTextContent(); text+=content.items.map((item)=>('str' in item?item.str+(item.hasEOL?'\\n':' '):'')).join(''); if(text.length>=100000) break;} if(!text.trim()) throw new Error('SCANNED'); window.ReactNativeWebView.postMessage(JSON.stringify({type:'text',text:text.slice(0,100000)})); } catch(error) { window.ReactNativeWebView.postMessage(JSON.stringify({type:'error',message:(error&&error.name==='PasswordException'?'Dieses PDF ist passwortgeschützt.':error&&error.message==='SCANNED'?'Dieses PDF enthält keinen maschinenlesbaren Text (wahrscheinlich Scan).':'Das PDF ist beschädigt oder enthält keinen lesbaren Text.')})); }};
  window.__renderPDF=async()=>{try { const lib=await import('data:text/javascript;base64,'+moduleBase64); lib.GlobalWorkerOptions.workerSrc=URL.createObjectURL(new Blob([decode(workerBase64)],{type:'text/javascript'})); window.__pdf=await lib.getDocument({data:decode(chunks),disableAutoFetch:true,disableStream:true,useSystemFonts:true,StandardFontDataFactory:LocalStandardFontDataFactory,standardFontDataUrl:'local:'}).promise; window.__page=1; window.__scale=Math.min(.55,(window.innerWidth*.9)/612); window.renderPage(); } catch(error) { window.ReactNativeWebView.postMessage(JSON.stringify({type:'error',message:(error&&error.name==='PasswordException'?'Dieses PDF ist passwortgeschützt.':'Das PDF ist beschädigt oder kann nicht angezeigt werden.')})); }};
  let renderQueue=Promise.resolve(); let renderToken=0; window.renderPage=()=>{const token=++renderToken; renderQueue=renderQueue.then(async()=>{if(token!==renderToken||!window.__pdf)return; const page=await window.__pdf.getPage(window.__page); const viewport=page.getViewport({scale:window.__scale}); const canvas=document.getElementById('canvas'); canvas.width=viewport.width; canvas.height=viewport.height; canvas.style.width=viewport.width+'px'; await page.render({canvasContext:canvas.getContext('2d'),viewport}).promise; if(token===renderToken)document.getElementById('page').textContent='Seite '+window.__page+' / '+window.__pdf.numPages;}).catch(()=>window.ReactNativeWebView.postMessage(JSON.stringify({type:'error',message:'Die PDF-Seite konnte nicht gerendert werden.'}))); return renderQueue;}; window.previous=()=>{if(window.__page>1){window.__page-=1;window.renderPage();}}; window.next=()=>{if(window.__pdf&&window.__page<window.__pdf.numPages){window.__page+=1;window.renderPage();}}; window.zoom=(delta)=>{window.__scale=Math.max(.6,Math.min(2.5,window.__scale+delta));window.renderPage();};
  </script></body></html>`;
}

const styles = StyleSheet.create({ root: { backgroundColor: colors.paper, flex: 1, minHeight: 260 }, web: { flex: 1 }, overlay: { alignItems: 'center', backgroundColor: colors.paper, gap: 8, justifyContent: 'center', left: 0, padding: 18, position: 'absolute', right: 0, top: 0, zIndex: 2 }, status: { color: colors.inkSoft, fontSize: 14 }, error: { color: colors.red, padding: 12 } });

const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const base = __dirname;
const blobs = {"12bd731b2c4ef10b148cfadcfaa06d92":"charles-bridge","0cb9dbd029776913d652efc75416bfc5":"letna","632bd7fba453c6b00d3c4afaec62bddc":"old-town","d96ce5b4af7bc0e3235d71b1e291ed10":"cover-charles-bridge-sunset","9a5302d55f68eca26aa14e22e425912d":"cafe"};
(async () => {
  const b = await chromium.launch();
  const names = process.argv[2].split(',');
  const theme = process.argv[3] || 'light';
  const css = fs.readFileSync(base+'/tokens.css','utf8') + fs.readFileSync(base+'/../project/components/bundle.css','utf8');
  for (const n of names) {
    let html = fs.readFileSync(`${base}/../project/components/${n}/preview.html`,'utf8');
    const m = html.match(/width=(\d+)/); const w = m ? +m[1] : 1000;
    html = html.replace('<head>', `<head><style>${css}</style>`).replace('<html lang="de">', `<html lang="de" data-theme="${theme}">`);
    const p = await b.newPage({ viewport: { width: w, height: 600 } });
    await p.route('**/*', r => {
      const u = r.request().url();
      const bm = u.match(/_blob\/([0-9a-f]+)/); if (bm) return r.fulfill({ path: `${base}/img/${blobs[bm[1]]}.jpg` });
      const fm = u.match(/\/project\/(fonts\/.*)$/); if (fm) return r.fulfill({ path: `${base}/../project/${fm[1]}` });
      if (u.startsWith('http://x/')) return r.fulfill({ body: html, contentType: 'text/html' });
      return r.continue();
    });
    p.on('pageerror', e => console.log(n, 'ERR', e.message));
    await p.goto('http://x/');
    await p.waitForTimeout(400);
    await p.screenshot({ path: `${base}/shots/${n}-${theme}.png`, fullPage: true });
    await p.close();
  }
  await b.close();
})();

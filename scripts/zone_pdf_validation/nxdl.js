// node nxdl.js slug outname  -> clicks the whole-week PDF button in the NX timetable embed
const { chromium } = require('playwright');
(async () => {
  const [slug, out] = process.argv.slice(2);
  const b = await chromium.launch({ channel:'chromium', proxy: { server: process.env.HTTPS_PROXY } });
  const ctx = await b.newContext({ acceptDownloads: true, userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36' });
  const p = await ctx.newPage();
  let embed = null;
  p.on('request', r => { if (r.url().startsWith('https://timetables-embed.nxbus.co.uk/') && !r.url().includes('/static/')) embed = embed || r.url(); });
  await p.goto('https://nxbus.co.uk/west-midlands/services-timetables/' + slug, { waitUntil: 'networkidle', timeout: 90000 }).catch(e => {});
  if (!embed) { console.log('NOEMBED', slug); await b.close(); return; }
  const e = await ctx.newPage();
  await e.goto(embed, { waitUntil: 'networkidle', timeout: 90000 });
  const btns = await e.$$('button.button-download-pdf');
  const labels = await Promise.all(btns.map(x => x.innerText()));
  console.log(slug, embed, JSON.stringify(labels));
  const week = await e.$('.wrapper-download-pdf-week button.button-download-pdf') || btns[0];
  const [dl] = await Promise.all([e.waitForEvent('download', { timeout: 120000 }), week.click()]);
  await dl.saveAs(out); console.log('SAVED', out);
  await b.close();
})();

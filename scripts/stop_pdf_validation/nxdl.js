// node nxdl.js slug out.pdf
// National Express West Midlands, now westmidlandsbus.co.uk: opens the
// service page, finds the timetable embed, and clicks its whole-week PDF
// button. Current edition only. Set PW_CHROMIUM to a Chromium executable to
// use one already on disk instead of Playwright's own download.
const { chromium } = require('playwright');
(async () => {
  const [slug, out] = process.argv.slice(2);
  const opt = process.env.PW_CHROMIUM ? { executablePath: process.env.PW_CHROMIUM } : {};
  const b = await chromium.launch(opt);
  const ctx = await b.newContext({ acceptDownloads: true, userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36' });
  const p = await ctx.newPage();
  let embed = null;
  p.on('request', r => { const u = r.url(); if (/^https:\/\/timetables-embed\.(nxbus|westmidlandsbus)\.co\.uk\//.test(u) && !u.includes('/static/')) embed = embed || u; });
  await p.goto('https://westmidlandsbus.co.uk/west-midlands/services-timetables/' + slug, { waitUntil: 'networkidle', timeout: 90000 }).catch(e => {});
  if (!embed) { const f = await p.$('iframe[src*="timetables-embed"]'); if (f) embed = await f.getAttribute('src'); }
  if (!embed) { console.log('NOEMBED', slug); await b.close(); return; }
  const e = await ctx.newPage();
  await e.goto(embed, { waitUntil: 'networkidle', timeout: 90000 });
  const btns = await e.$$('button.button-download-pdf');
  const week = await e.$('.wrapper-download-pdf-week button.button-download-pdf') || btns[0];
  if (!week) { console.log('NOBUTTON', slug, embed); await b.close(); return; }
  const [dl] = await Promise.all([e.waitForEvent('download', { timeout: 120000 }), week.click()]);
  await dl.saveAs(out); console.log('SAVED', slug);
  await b.close();
})();

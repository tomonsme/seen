import {chromium} from "playwright";
import {mkdir} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const template = `file://${path.join(root, "appstore/templates/asset-page.html")}`;
const output = path.join(root, "appstore/generated");

const screenshots = [
  ["01-reveal-your-social-type.png", "reveal"],
  ["02-cute-roast.png", "roast"],
  ["03-crush-compatibility.png", "duo"],
  ["04-friend-votes.png", "vote"],
  ["05-share-card.png", "share"],
];

const ads = [
  ["aura-ad-square.png", "ad-square", "reveal", {width: 1080, height: 1080}],
  ["aura-ad-story.png", "ad-story", "share", {width: 1080, height: 1920}],
  ["aura-ad-landscape.png", "ad-landscape", "duo", {width: 1200, height: 628}],
];

await mkdir(path.join(output, "iphone-6-9"), {recursive: true});
await mkdir(path.join(output, "ads"), {recursive: true});

const browser = await chromium.launch();

for (const [filename, type] of screenshots) {
  const page = await browser.newPage({viewport: {width: 1290, height: 2796}, deviceScaleFactor: 1});
  await page.goto(`${template}?mode=screenshot&type=${type}`, {waitUntil: "networkidle"});
  await page.screenshot({path: path.join(output, "iphone-6-9", filename), fullPage: false});
  await page.close();
}

for (const [filename, mode, type, viewport] of ads) {
  const page = await browser.newPage({viewport, deviceScaleFactor: 1});
  await page.goto(`${template}?mode=${mode}&type=${type}`, {waitUntil: "networkidle"});
  await page.screenshot({path: path.join(output, "ads", filename), fullPage: false});
  await page.close();
}

await browser.close();

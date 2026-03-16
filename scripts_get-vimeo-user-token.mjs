import http from "node:http";
import { URL } from "node:url";
import { Buffer } from "node:buffer";

const CLIENT_ID = process.env.VIMEO_CLIENT_ID;
const CLIENT_SECRET = process.env.VIMEO_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  throw new Error("Missing VIMEO_CLIENT_ID or VIMEO_CLIENT_SECRET env var.");
}

const REDIRECT_URI = "http://localhost:8787/callback";
const SCOPE = "public private";

function basicAuthHeader(id, secret) {
  return "Basic " + Buffer.from(`${id}:${secret}`).toString("base64");
}

const authorizeUrl =
  "https://api.vimeo.com/oauth/authorize" +
  `?response_type=code&client_id=${encodeURIComponent(CLIENT_ID)}` +
  `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
  `&scope=${encodeURIComponent(SCOPE)}`;

console.log("\n1) Add this callback URL in Vimeo app settings (exactly):");
console.log("   " + REDIRECT_URI);
console.log("\n2) Open this URL in your browser and approve:\n");
console.log(authorizeUrl);
console.log("\nWaiting for callback on:", REDIRECT_URI, "\n");

const server = http.createServer(async (req, res) => {
  try {
    const reqUrl = new URL(req.url, REDIRECT_URI);

    if (reqUrl.pathname !== "/callback") {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not found");
      return;
    }

    const error = reqUrl.searchParams.get("error");
    const code = reqUrl.searchParams.get("code");

    if (error) {
      res.writeHead(400, { "Content-Type": "text/plain" });
      res.end("OAuth error: " + error);
      server.close();
      return;
    }

    if (!code) {
      res.writeHead(400, { "Content-Type": "text/plain" });
      res.end("Missing code");
      return;
    }

    const tokenRes = await fetch("https://api.vimeo.com/oauth/access_token", {
      method: "POST",
      headers: {
        Authorization: basicAuthHeader(CLIENT_ID, CLIENT_SECRET),
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/vnd.vimeo.*+json;version=3.4",
      },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: REDIRECT_URI,
      }),
    });

    const tokenText = await tokenRes.text();

    if (!tokenRes.ok) {
      res.writeHead(500, { "Content-Type": "text/plain" });
      res.end("Token exchange failed:\n" + tokenText);
      server.close();
      return;
    }

    const tokenJson = JSON.parse(tokenText);
    const accessToken = tokenJson.access_token;

    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("Success. You can close this tab.\nCheck your terminal for the access token.\n");

    console.log("\n=== VIMEO USER ACCESS TOKEN (use this as VIMEO_TOKEN) ===\n");
    console.log(accessToken);
    console.log("\nExample PowerShell usage:");
    console.log(`$env:VIMEO_TOKEN="<PASTE_TOKEN_HERE>"`);
    console.log("node .\\scripts\\build-vimeo-library.mjs\n");

    server.close();
  } catch (e) {
    res.writeHead(500, { "Content-Type": "text/plain" });
    res.end(String(e?.stack || e));
    server.close();
  }
});

server.listen(8787);
// Cloud Function Steady : push direct APNs quand un message de groupe arrive.
// On envoie DIRECTEMENT à Apple (pas via FCM) en essayant l'environnement
// sandbox puis production → marche que le jeton soit de dev ou de prod.
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const http2 = require("http2");

admin.initializeApp();

const APNS_KEY = defineSecret("APNS_KEY"); // contenu du fichier AuthKey_B5BR67R3W6.p8
// Clé configurée « Sandbox & Production » dans le portail Apple. L'ancienne
// (5QMNLSJM47) était limitée à Sandbox → BadEnvironmentKeyInToken en prod.
const KEY_ID = "B5BR67R3W6";
const TEAM_ID = "V3BB9YS6N2";
const TOPIC = "Rodrigo.Steady";

function b64url(buf) {
  return Buffer.from(buf).toString("base64")
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

// Jeton d'authentification APNs (JWT ES256 signé avec la clé .p8).
function makeJWT(keyPem) {
  const header = b64url(JSON.stringify({alg: "ES256", kid: KEY_ID}));
  const claims = b64url(JSON.stringify({iss: TEAM_ID, iat: Math.floor(Date.now() / 1000)}));
  const input = `${header}.${claims}`;
  const sig = crypto.createSign("SHA256").update(input).sign({key: keyPem, dsaEncoding: "ieee-p1363"});
  return `${input}.${b64url(sig)}`;
}

// Envoi HTTP/2 à un endpoint APNs. Résout {status, body}.
function sendAPNS(host, token, jwt, payload) {
  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}`);
    client.on("error", (e) => resolve({status: 0, body: String(e)}));
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      "authorization": `bearer ${jwt}`,
      "apns-topic": TOPIC,
      "apns-push-type": "alert",
    });
    let status = 0; let body = "";
    req.on("response", (h) => { status = h[":status"]; });
    req.on("data", (d) => { body += d; });
    req.on("end", () => { client.close(); resolve({status, body}); });
    req.on("error", (e) => { resolve({status: 0, body: String(e)}); });
    req.write(JSON.stringify(payload));
    req.end();
  });
}

// Envoie un push à un uid donné. Sandbox d'abord (build dev), sinon production.
// Retourne true si Apple a accepté.
async function pushTo(uid, payload) {
  const user = await admin.firestore().doc(`users/${uid}`).get();
  const apns = user.get("apnsToken");
  if (!apns) { logger.warn("pas de apnsToken (l'app doit republier)", {uid}); return false; }

  const jwt = makeJWT(APNS_KEY.value());
  let res = await sendAPNS("api.sandbox.push.apple.com", apns, jwt, payload);
  let env = "sandbox";
  if (res.status !== 200) {
    const prod = await sendAPNS("api.push.apple.com", apns, jwt, payload);
    if (prod.status === 200) { res = prod; env = "prod"; }
    else { res = {status: res.status, body: `sandbox:${res.body} | prod:${prod.body}`}; env = "aucun"; }
  }
  if (res.status === 200) { logger.info("✅ push envoyé", {uid, env}); return true; }
  logger.error("❌ push refusé", {uid, status: res.status, body: res.body});
  return false;
}

// Encouragement reçu : l'ami dépose un doc dans users/{userId}/cheers/{id}.
exports.notifyCheer = onDocumentCreated(
  {
    document: "users/{userId}/cheers/{cheerId}",
    region: "europe-west1",
    secrets: [APNS_KEY],
  },
  async (event) => {
    const cheer = event.data ? event.data.data() : null;
    if (!cheer) return;
    const from = cheer.fromUsername || "Un ami";
    await pushTo(event.params.userId, {
      aps: {
        alert: {title: "Steady", body: `👏 ${from} t'encourage !`},
        sound: "default",
      },
    });
  },
);

exports.notifyGroupMessage = onDocumentCreated(
  {
    document: "groups/{groupId}/messages/{messageId}",
    region: "europe-west1",
    secrets: [APNS_KEY],
  },
  async (event) => {
    const msg = event.data ? event.data.data() : null;
    if (!msg) return;

    const groupSnap = await admin.firestore().doc(`groups/${event.params.groupId}`).get();
    const group = groupSnap.data();
    if (!group) { logger.warn("groupe introuvable"); return; }

    const memberIds = (group.members || []).filter((u) => u !== msg.authorUID);
    if (memberIds.length === 0) { logger.warn("aucun destinataire"); return; }

    const payload = {
      aps: {
        alert: {
          title: group.name || "Steady",
          body: `${msg.authorName || "Quelqu'un"} : ${msg.text || ""}`.slice(0, 150),
        },
        sound: "default",
      },
    };

    for (const uid of memberIds) {
      await pushTo(uid, payload);
    }
  },
);

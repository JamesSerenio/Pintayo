import { importPKCS8, SignJWT } from "jose";

export const firebaseProjectId = "pintayo";
export const fcmEndpoint =
  `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}
let cached: { token: string; expires: number; email: string } | undefined;
export async function accessToken(account: ServiceAccount): Promise<string> {
  if (!account.client_email || !account.private_key) {
    throw new Error("FCM server credentials are incomplete");
  }
  if (
    cached && cached.email === account.client_email &&
    cached.expires > Date.now() + 60_000
  ) return cached.token;
  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" }).setIssuer(
      account.client_email,
    )
    .setAudience("https://oauth2.googleapis.com/token").setIssuedAt()
    .setExpirationTime("1h").sign(key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    signal: AbortSignal.timeout(15000),
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("FCM server authorization failed");
  const data = await response.json();
  cached = {
    token: data.access_token,
    expires: Date.now() + data.expires_in * 1000,
    email: account.client_email,
  };
  return cached.token;
}

export function pushMessage(
  event: { id: string; kind: string; recipient: string },
  registration: string,
  conversation?: string,
) {
  return {
    fid: registration,
    notification: {
      title: "PinTayo",
      body: event.kind === "message"
        ? "You have a new message."
        : "You have a new friend request.",
    },
    data: {
      event_id: event.id,
      kind: event.kind,
      recipient_id: event.recipient,
      ...(conversation ? { conversation_id: conversation } : {}),
    },
    android: {
      collapse_key: event.id,
      notification: { tag: event.id, channel_id: "pintayo_messages" },
    },
    apns: {
      headers: { "apns-collapse-id": event.id },
      payload: { aps: { sound: "default" } },
    },
  };
}

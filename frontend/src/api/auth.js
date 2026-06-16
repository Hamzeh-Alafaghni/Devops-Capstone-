import { authClient } from "./client.js";

export async function register(payload) {
  // payload: { username, password, email? }
  const res = await authClient.post("/api/auth/register", payload);
  return res.data; // { message, token, user }
}

export async function login(username, password) {
  const res = await authClient.post("/api/auth/login", { username, password });
  return res.data; // { token, user }
}

export async function me(token) {
  const res = await authClient.get("/api/auth/me", {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data;
}

export async function updateProfile(token, payload) {
  // payload: { email?, full_name?, address? }
  const res = await authClient.put("/api/auth/profile", payload, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data;
}

export async function changePassword(token, currentPassword, newPassword) {
  const res = await authClient.post(
    "/api/auth/change-password",
    { current_password: currentPassword, new_password: newPassword },
    { headers: { Authorization: `Bearer ${token}` } }
  );
  return res.data;
}

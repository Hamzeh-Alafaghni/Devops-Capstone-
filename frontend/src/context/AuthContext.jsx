import React, { createContext, useContext, useEffect, useState } from "react";
import * as authApi from "../api/auth.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem("capstone_token"));
  const [user, setUser] = useState(() => {
    try {
      const raw = localStorage.getItem("capstone_user");
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  });
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (token) {
      localStorage.setItem("capstone_token", token);
    } else {
      localStorage.removeItem("capstone_token");
    }
  }, [token]);

  useEffect(() => {
    if (user) {
      localStorage.setItem("capstone_user", JSON.stringify(user));
    } else {
      localStorage.removeItem("capstone_user");
    }
  }, [user]);

  // On first load, re-validate the stored token against auth-service and
  // refresh the user profile (covers role changes, profile edits, etc).
  useEffect(() => {
    async function bootstrap() {
      if (token) {
        try {
          const profile = await authApi.me(token);
          setUser(profile);
        } catch {
          setToken(null);
          setUser(null);
        }
      }
      setReady(true);
    }
    bootstrap();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function login(username, password) {
    const data = await authApi.login(username, password);
    setToken(data.token);
    setUser(data.user);
  }

  async function register(username, password, email) {
    const data = await authApi.register({ username, password, email });
    setToken(data.token);
    setUser(data.user);
  }

  function logout() {
    setToken(null);
    setUser(null);
  }

  async function refreshProfile() {
    if (!token) return;
    const profile = await authApi.me(token);
    setUser(profile);
  }

  const value = {
    token,
    user,
    username: user?.username,
    isAdmin: user?.role === "admin",
    ready,
    login,
    register,
    logout,
    refreshProfile,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

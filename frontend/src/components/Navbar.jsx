import React from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext.jsx";
import { useCart } from "../context/CartContext.jsx";

export default function Navbar() {
  const { user, isAdmin, logout } = useAuth();
  const { count } = useCart();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate("/login");
  }

  return (
    <header className="sticky top-0 z-10 border-b border-gray-200 bg-white/90 backdrop-blur">
      <nav className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
        <Link to="/" className="text-lg font-bold text-brand-700">
          Capstone Shop
        </Link>
        <div className="flex flex-wrap items-center gap-5 text-sm font-medium text-gray-600">
          <Link to="/" className="hover:text-brand-600">
            Catalog
          </Link>
          <Link to="/cart" className="relative hover:text-brand-600">
            Cart
            {count > 0 && (
              <span className="absolute -right-3 -top-2 inline-flex h-5 w-5 items-center justify-center rounded-full bg-brand-600 text-[11px] font-semibold text-white">
                {count}
              </span>
            )}
          </Link>
          {user && (
            <Link to="/orders" className="hover:text-brand-600">
              My Orders
            </Link>
          )}
          {isAdmin && (
            <>
              <Link to="/admin/products" className="hover:text-brand-600">
                Admin Products
              </Link>
              <Link to="/admin/orders" className="hover:text-brand-600">
                Admin Orders
              </Link>
            </>
          )}
          {user ? (
            <>
              <Link to="/profile" className="hover:text-brand-600">
                Hi, {user.username}
              </Link>
              <button className="btn-secondary !px-3 !py-1.5" onClick={handleLogout}>
                Logout
              </button>
            </>
          ) : (
            <>
              <Link to="/login" className="hover:text-brand-600">
                Login
              </Link>
              <Link to="/register" className="btn-primary !px-3 !py-1.5">
                Register
              </Link>
            </>
          )}
        </div>
      </nav>
    </header>
  );
}

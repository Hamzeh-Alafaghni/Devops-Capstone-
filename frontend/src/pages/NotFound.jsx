import React from "react";
import { Link } from "react-router-dom";

export default function NotFound() {
  return (
    <div className="mx-auto max-w-md px-4 py-20 text-center">
      <h1 className="text-3xl font-bold text-gray-900">404</h1>
      <p className="mt-2 text-gray-500">Page not found.</p>
      <Link className="btn-primary mt-6 inline-block" to="/">
        Back home
      </Link>
    </div>
  );
}

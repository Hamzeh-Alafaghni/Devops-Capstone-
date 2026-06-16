import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import toast from "react-hot-toast";
import { getProduct } from "../api/catalog.js";
import { useCart } from "../context/CartContext.jsx";

export default function ProductDetail() {
  const { id } = useParams();
  const [product, setProduct] = useState(null);
  const [quantity, setQuantity] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const { addItem } = useCart();

  useEffect(() => {
    setLoading(true);
    setError("");
    getProduct(id)
      .then(setProduct)
      .catch(() => setError("Product not found."))
      .finally(() => setLoading(false));
  }, [id]);

  function handleAdd() {
    addItem(product, quantity);
    toast.success(`${product.name} added to cart`);
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-12">
        <div className="skeleton h-96 w-full" />
      </div>
    );
  }

  if (error || !product) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-12">
        <p className="field-error">{error || "Product not found."}</p>
        <Link className="font-medium text-brand-600" to="/">
          &larr; Back to catalog
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link to="/" className="text-sm font-medium text-brand-600">
        &larr; Back to catalog
      </Link>
      <div className="mt-4 grid gap-8 sm:grid-cols-2">
        <img
          src={product.image_url || "https://placehold.co/480x360?text=No+Image"}
          alt={product.name}
          className="w-full rounded-xl object-cover"
        />
        <div>
          <span className="badge bg-brand-50 text-brand-700">{product.category}</span>
          <h1 className="mt-2 text-2xl font-bold text-gray-900">{product.name}</h1>
          <p className="mt-2 text-gray-600">{product.description}</p>
          <p className="mt-4 text-3xl font-bold text-gray-900">${product.price.toFixed(2)}</p>
          <p className={`mt-1 text-sm ${product.stock < 1 ? "text-red-600" : "text-gray-500"}`}>
            {product.stock < 1 ? "Out of stock" : `${product.stock} in stock`}
          </p>
          <div className="mt-6 flex items-center gap-3">
            <input
              type="number"
              min={1}
              max={Math.max(product.stock, 1)}
              className="input-field w-20"
              value={quantity}
              onChange={(e) =>
                setQuantity(Math.max(1, Math.min(product.stock, Number(e.target.value) || 1)))
              }
              disabled={product.stock < 1}
            />
            <button className="btn-primary" disabled={product.stock < 1} onClick={handleAdd}>
              Add to cart
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

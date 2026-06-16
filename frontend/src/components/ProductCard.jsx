import React from "react";
import { Link } from "react-router-dom";
import toast from "react-hot-toast";
import { useCart } from "../context/CartContext.jsx";

export default function ProductCard({ product }) {
  const { addItem } = useCart();

  function handleAdd(e) {
    e.preventDefault();
    addItem(product);
    toast.success(`${product.name} added to cart`);
  }

  return (
    <Link
      to={`/products/${product.id}`}
      className="card flex flex-col transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <img
        src={product.image_url || "https://placehold.co/480x360?text=No+Image"}
        alt={product.name}
        className="h-40 w-full rounded-lg object-cover"
        loading="lazy"
      />
      <span className="badge mt-3 self-start bg-brand-50 text-brand-700">{product.category}</span>
      <h3 className="mt-2 font-semibold text-gray-900">{product.name}</h3>
      <p className="mt-1 line-clamp-2 flex-1 text-sm text-gray-500">{product.description}</p>
      <div className="mt-3 flex items-center justify-between">
        <span className="text-lg font-bold text-gray-900">${product.price.toFixed(2)}</span>
        <span className={`text-xs ${product.stock < 1 ? "text-red-600" : "text-gray-500"}`}>
          {product.stock < 1 ? "Out of stock" : `${product.stock} in stock`}
        </span>
      </div>
      <button className="btn-primary mt-3" disabled={product.stock < 1} onClick={handleAdd}>
        Add to cart
      </button>
    </Link>
  );
}

import React from "react";

export function ProductCardSkeleton() {
  return (
    <div className="card">
      <div className="skeleton h-40 w-full" />
      <div className="skeleton mt-4 h-4 w-3/4" />
      <div className="skeleton mt-2 h-4 w-1/2" />
      <div className="skeleton mt-4 h-9 w-full" />
    </div>
  );
}

export function OrderSkeleton() {
  return (
    <div className="card">
      <div className="skeleton h-4 w-1/3" />
      <div className="skeleton mt-3 h-3 w-full" />
      <div className="skeleton mt-2 h-3 w-2/3" />
    </div>
  );
}

import React, { useEffect, useState } from "react";
import { listProducts, listCategories } from "../api/catalog.js";
import ProductCard from "../components/ProductCard.jsx";
import { ProductCardSkeleton } from "../components/Skeletons.jsx";
import EmptyState from "../components/EmptyState.jsx";
import Pagination from "../components/Pagination.jsx";

const SORT_OPTIONS = [
  { value: "newest", label: "Newest" },
  { value: "price_asc", label: "Price: Low to High" },
  { value: "price_desc", label: "Price: High to Low" },
  { value: "name", label: "Name (A-Z)" },
];

const PAGE_SIZE = 12;

export default function Catalog() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [category, setCategory] = useState("");
  const [sort, setSort] = useState("newest");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    listCategories()
      .then(setCategories)
      .catch(() => {});
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search), 350);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    setPage(1);
  }, [debouncedSearch, category, sort]);

  useEffect(() => {
    setLoading(true);
    setError("");
    listProducts({
      q: debouncedSearch || undefined,
      category: category || undefined,
      sort,
      page,
      page_size: PAGE_SIZE,
    })
      .then((data) => {
        setProducts(data.items);
        setTotal(data.total);
        setTotalPages(data.total_pages);
      })
      .catch(() => setError("Could not load products. Is catalog-service running on :5002?"))
      .finally(() => setLoading(false));
  }, [debouncedSearch, category, sort, page]);

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Shop products</h1>
          <p className="mt-1 text-sm text-gray-500">
            {total} item{total === 1 ? "" : "s"} available
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <input
            className="input-field sm:w-56"
            placeholder="Search products..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select
            className="input-field sm:w-44"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          >
            <option value="">All categories</option>
            {categories.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
          <select
            className="input-field sm:w-44"
            value={sort}
            onChange={(e) => setSort(e.target.value)}
          >
            {SORT_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {error && <p className="field-error mt-4">{error}</p>}

      <div className="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {loading
          ? Array.from({ length: 6 }).map((_, i) => <ProductCardSkeleton key={i} />)
          : products.map((p) => <ProductCard key={p.id} product={p} />)}
      </div>

      {!loading && products.length === 0 && !error && (
        <div className="mt-6">
          <EmptyState
            title="No products found"
            description="Try adjusting your search or filters."
          />
        </div>
      )}

      {!loading && <Pagination page={page} totalPages={totalPages} onChange={setPage} />}
    </div>
  );
}

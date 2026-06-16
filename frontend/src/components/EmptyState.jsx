import React from "react";

export default function EmptyState({ title, description, action }) {
  return (
    <div className="card flex flex-col items-center gap-2 py-12 text-center">
      <h3 className="text-lg font-semibold text-gray-800">{title}</h3>
      {description && <p className="max-w-sm text-sm text-gray-500">{description}</p>}
      {action}
    </div>
  );
}

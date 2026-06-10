import type { InputHTMLAttributes } from "react";

export function Field({
  label,
  name,
  placeholder,
  required,
  inputMode,
  defaultValue,
  onChange,
  onBlur,
  value
}: {
  label: string;
  name: string;
  placeholder: string;
  required?: boolean;
  inputMode?: InputHTMLAttributes<HTMLInputElement>["inputMode"];
  defaultValue?: string;
  onChange?: InputHTMLAttributes<HTMLInputElement>["onChange"];
  onBlur?: InputHTMLAttributes<HTMLInputElement>["onBlur"];
  value?: string;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-bold text-ink">{label}</span>
      <input
        className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
        inputMode={inputMode}
        name={name}
        placeholder={placeholder}
        required={required}
        defaultValue={defaultValue}
        onChange={onChange}
        onBlur={onBlur}
        value={value}
      />
    </label>
  );
}

export function Spinner() {
  return (
    <svg className="size-3.5 animate-spin text-gray-400" viewBox="0 0 24 24" fill="none">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
    </svg>
  );
}

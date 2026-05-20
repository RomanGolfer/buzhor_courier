export function PageHeader({
  title,
  description,
  action
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-col justify-between gap-4 md:flex-row md:items-end">
      <div>
        <h1 className="text-2xl font-black tracking-tight text-ink">{title}</h1>
        {description ? <p className="mt-1 text-sm text-muted">{description}</p> : null}
      </div>
      {action}
    </div>
  );
}

export function Panel({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <section className={`rounded-lg border border-line bg-white shadow-panel ${className}`}>{children}</section>;
}

export function StatusPill({ tone, children }: { tone: "good" | "warn" | "bad" | "muted"; children: React.ReactNode }) {
  const colors = {
    good: "bg-emerald-50 text-good",
    warn: "bg-amber-50 text-warn",
    bad: "bg-red-50 text-bad",
    muted: "bg-slate-100 text-muted"
  };

  return <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-bold ${colors[tone]}`}>{children}</span>;
}

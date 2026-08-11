export function DirectorySearch({
  action,
  defaultValue = "",
  placeholder = "Поиск"
}: {
  action: string;
  defaultValue?: string;
  placeholder?: string;
}) {
  return (
    <form action={action} className="mb-4 flex max-w-2xl gap-2">
      <input
        className="focus-ring h-11 flex-1 border border-line px-3 text-sm"
        defaultValue={defaultValue}
        name="q"
        placeholder={placeholder}
      />
      <button className="bg-brand px-5 text-sm font-black text-white hover:bg-brandDark" type="submit">
        Найти
      </button>
    </form>
  );
}

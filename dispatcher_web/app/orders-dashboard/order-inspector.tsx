import type { Courier, Order, OrderState } from "@/lib/types";
import { Panel, StatusPill } from "@/components/ui";
import { isOrderOverdue } from "./date-utils";
import {
  clientRatingLabel,
  editableStates,
  fiscalReceiptLabel,
  formatMoney,
  markingCount,
  paymentLabels,
  stateLabels,
  stateTone
} from "./order-formatters";

export function OrderInspector({
  order,
  couriers,
  draftState,
  draftCourierId,
  draftComment,
  draftFailureReason,
  isSaving,
  message,
  error,
  onStateChange,
  onCourierChange,
  onCommentChange,
  onFailureReasonChange,
  onSave,
  onClose
}: {
  order: Order | null;
  couriers: Courier[];
  draftState: OrderState;
  draftCourierId: string;
  draftComment: string;
  draftFailureReason: string;
  isSaving: boolean;
  message: string | null;
  error: string | null;
  onStateChange: (value: OrderState) => void;
  onCourierChange: (value: string) => void;
  onCommentChange: (value: string) => void;
  onFailureReasonChange: (value: string) => void;
  onSave: () => void;
  onClose?: () => void;
}) {
  if (!order) {
    return (
      <Panel className="p-5">
        <div className="text-sm font-semibold text-muted">Выберите заказ, чтобы открыть диспетчерские действия.</div>
      </Panel>
    );
  }

  const mapHref =
    order.lat !== null && order.lng !== null
      ? `https://yandex.ru/maps/?pt=${order.lng},${order.lat}&z=16&l=map`
      : null;

  return (
    <Panel className="h-fit p-5 xl:sticky xl:top-6">
      <div className="mb-4 flex items-start justify-between gap-3">
        <div>
          <div className="text-xs font-black uppercase tracking-[0.16em] text-muted">Заказ</div>
          <h2 className="mt-1 text-xl font-black text-ink">{order.order_number}</h2>
        </div>
        <div className="flex items-center gap-2">
          <StatusPill tone={stateTone(order.state)}>{stateLabels[order.state]}</StatusPill>
          {onClose && (
            <button
              aria-label="Закрыть"
              className="rounded-md p-1.5 text-muted hover:bg-slate-100 hover:text-ink"
              onClick={onClose}
            >
              <svg fill="none" height="16" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" viewBox="0 0 24 24" width="16">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>
      </div>

      <div className="space-y-3 border-b border-line pb-4 text-sm">
        <InfoRow label="Клиент" value={order.client_name} />
        <InfoRow label="Телефон" value={order.client_phone ?? "не указан"} href={order.client_phone ? `tel:${order.client_phone}` : undefined} />
        <InfoRow label="Адрес" value={order.address} />
        <InfoRow label="Район" value={order.district ?? "не указан"} />
        <InfoRow label="Слот" value={order.time_slot ?? "без слота"} />
        {isOrderOverdue(order) ? <InfoRow label="Срок" value="Просрочен" /> : null}
        <InfoRow label="Рейтинг клиента" value={clientRatingLabel(order)} />
        <InfoRow label="Оплата" value={`${paymentLabels[order.payment_method]} · ${formatMoney(order.price)}`} />
        <InfoRow label="Бутыли" value={String(order.bottles)} />
        <InfoRow label="Маркировка" value={`${markingCount(order)} кодов`} />
        <InfoRow label="Чек" value={fiscalReceiptLabel(order)} />
        {order.fiscal_receipt?.receiptUrl ? (
          <InfoRow label="Ссылка на чек" value="Открыть чек" href={order.fiscal_receipt.receiptUrl} />
        ) : null}
        {mapHref ? <InfoRow label="Карта" value="Открыть точку" href={mapHref} /> : null}
      </div>

      <div className="mt-4 space-y-4">
        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Статус</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            value={draftState}
            onChange={(event) => onStateChange(event.target.value as OrderState)}
          >
            {editableStates.map((state) => (
              <option key={state} value={state}>
                {stateLabels[state]}
              </option>
            ))}
          </select>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Курьер</span>
          <select
            className="focus-ring w-full rounded-md border border-line px-3 py-3 text-sm"
            value={draftCourierId}
            onChange={(event) => onCourierChange(event.target.value)}
          >
            <option value="">Не назначен</option>
            {couriers.map((courier) => (
              <option key={courier.id} value={courier.id}>
                {courier.display_name}
              </option>
            ))}
          </select>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Комментарий диспетчера</span>
          <textarea
            className="focus-ring min-h-28 w-full resize-y rounded-md border border-line px-3 py-3 text-sm"
            placeholder="Код домофона, уточнения по клиенту, что передать курьеру"
            value={draftComment}
            onChange={(event) => onCommentChange(event.target.value)}
          />
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-bold text-ink">Причина проблемы</span>
          <textarea
            className="focus-ring min-h-20 w-full resize-y rounded-md border border-line px-3 py-3 text-sm"
            placeholder="Заполняется для проблемных или отмененных заказов"
            value={draftFailureReason}
            onChange={(event) => onFailureReasonChange(event.target.value)}
          />
        </label>

        {message ? <div className="rounded-md bg-emerald-50 px-3 py-2 text-sm font-bold text-good">{message}</div> : null}
        {error ? <div className="rounded-md bg-red-50 px-3 py-2 text-sm font-bold text-bad">{error}</div> : null}

        <button
          className="w-full rounded-md bg-brand px-4 py-3 text-sm font-black text-white hover:bg-brandDark disabled:opacity-60"
          disabled={isSaving}
          onClick={() => void onSave()}
        >
          {isSaving ? "Сохраняем..." : "Сохранить изменения"}
        </button>
      </div>
    </Panel>
  );
}

function InfoRow({ label, value, href }: { label: string; value: string; href?: string }) {
  return (
    <div>
      <div className="text-xs font-bold uppercase tracking-[0.12em] text-muted">{label}</div>
      {href ? (
        <a className="font-bold text-brand hover:text-brandDark" href={href} rel="noreferrer" target={href.startsWith("http") ? "_blank" : undefined}>
          {value}
        </a>
      ) : (
        <div className="font-semibold text-ink">{value}</div>
      )}
    </div>
  );
}

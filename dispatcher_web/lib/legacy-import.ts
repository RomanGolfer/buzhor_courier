export type LegacyImportEntity = "clients" | "organizations" | "orders";
export type LegacyRawRow = Record<string, unknown>;

export type ClientImportPreview = {
  fullName: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  organization: string | null;
  errors: string[];
};

export type OrganizationImportPreview = {
  name: string | null;
  inn: string | null;
  kpp: string | null;
  phone: string | null;
  address: string | null;
  errors: string[];
};

export type OrderImportPreview = {
  orderNumber: string | null;
  deliveryDate: string;
  clientName: string | null;
  phone: string | null;
  address: string | null;
  organization: string | null;
  errors: string[];
};

export type LegacyImportPreview = ClientImportPreview | OrganizationImportPreview | OrderImportPreview;

export type NormalizedClientRow = ClientImportPreview & {
  legacyId: string | null;
  status: string | null;
  loyaltyPoints: number | null;
  tareDebt: number | null;
  notes: string | null;
  zoneName: string | null;
  district: string | null;
  locality: string | null;
  street: string | null;
  house: string | null;
  building: string | null;
  structure: string | null;
  entrance: string | null;
  floor: string | null;
  apartment: string | null;
  lat: number | null;
  lng: number | null;
  original: LegacyRawRow;
};

export type NormalizedOrganizationRow = OrganizationImportPreview & {
  legacyId: string | null;
  email: string | null;
  tareDebt: number | null;
  original: LegacyRawRow;
};

export type NormalizedOrderRow = OrderImportPreview & {
  legacyId: string | null;
  state: "draft" | "assigned" | "accepted" | "in_progress" | "delivered" | "failed" | "cancelled";
  paymentMethod: "card" | "cash" | "qr" | "online" | "contract";
  price: number;
  bottles: number;
  district: string | null;
  lat: number | null;
  lng: number | null;
  timeSlot: string | null;
  comment: string | null;
  organizationInn: string | null;
  courierName: string | null;
  courierPhone: string | null;
  createdAt: string | null;
  original: LegacyRawRow;
};

const aliases = {
  legacyId: ["id", "client_id", "customer_id", "order_id", "organization_id", "legacy_id", "external_id", "код", "код клиента", "код заказа", "код организации", "ид", "идентификатор"],
  fullName: ["full_name", "client_name", "customer_name", "customer", "fio", "name", "клиент", "фио", "фио клиента", "имя клиента", "контактное лицо", "наименование клиента"],
  firstName: ["first_name", "firstname", "given_name", "имя"],
  lastName: ["last_name", "lastname", "surname", "фамилия"],
  middleName: ["middle_name", "middlename", "patronymic", "отчество"],
  phone: ["phone", "client_phone", "customer_phone", "telephone", "mobile", "телефон", "телефон клиента", "мобильный", "номер телефона"],
  email: ["email", "e-mail", "mail", "электронная почта", "почта"],
  status: ["status", "client_status", "статус", "статус клиента"],
  loyaltyPoints: ["loyalty_points", "bonus", "bonuses", "points", "баллы", "бонусы", "бонусные баллы"],
  tareDebt: ["tare_debt", "container_debt", "bottle_debt", "долг по таре", "долг тары", "тара долг", "долг бутылей"],
  notes: ["notes", "note", "comment", "client_comment", "примечание", "комментарий", "комментарий клиента"],
  address: ["address", "client_address", "customer_address", "delivery_address", "full_address", "адрес", "адрес клиента", "адрес доставки", "полный адрес"],
  zoneName: ["zone", "zone_name", "delivery_zone", "route", "route_name", "зона", "зона доставки", "маршрут"],
  district: ["district", "area", "район", "округ"],
  locality: ["locality", "city", "settlement", "город", "населенный пункт", "населённый пункт", "поселок", "посёлок"],
  street: ["street", "улица"],
  house: ["house", "house_number", "дом"],
  building: ["building", "block", "корпус"],
  structure: ["structure", "строение"],
  entrance: ["entrance", "подъезд"],
  floor: ["floor", "этаж"],
  apartment: ["apartment", "flat", "office", "квартира", "офис"],
  lat: ["lat", "latitude", "широта"],
  lng: ["lng", "lon", "longitude", "долгота"],
  organization: ["organization", "organization_name", "company", "company_name", "legal_entity", "организация", "название организации", "компания", "юридическое лицо"],
  inn: ["inn", "tax_id", "инн"],
  kpp: ["kpp", "кпп"],
  orderNumber: ["order_number", "number", "order_no", "order", "номер заказа", "заказ", "номер"],
  deliveryDate: ["delivery_date", "date_delivery", "date", "дата доставки", "дата заказа", "дата"],
  timeSlot: ["time_slot", "delivery_time", "interval", "время доставки", "интервал", "временной интервал"],
  state: ["state", "order_status", "status", "состояние", "статус заказа", "статус"],
  paymentMethod: ["payment_method", "payment", "payment_type", "способ оплаты", "оплата", "тип оплаты"],
  price: ["price", "amount", "total", "sum", "стоимость", "сумма", "итого"],
  bottles: ["bottles", "bottle_count", "quantity", "qty", "бутыли", "количество бутылей", "количество"],
  courierName: ["courier", "courier_name", "driver", "driver_name", "курьер", "водитель", "фио водителя"],
  courierPhone: ["courier_phone", "driver_phone", "телефон курьера", "телефон водителя"],
  createdAt: ["created_at", "created", "creation_date", "дата создания", "создан"],
  organizationAddress: ["organization_address", "company_address", "legal_address", "адрес организации", "юридический адрес"]
} as const;

export function normalizeImportRow(entity: LegacyImportEntity, row: LegacyRawRow): LegacyImportPreview {
  if (entity === "clients") return normalizeClientRow(row);
  if (entity === "organizations") return normalizeOrganizationRow(row);
  return normalizeOrderRow(row);
}

export function normalizeClientRow(row: LegacyRawRow): NormalizedClientRow {
  const legacyId = textValue(row, aliases.legacyId);
  const fullName = personName(row);
  const phone = textValue(row, aliases.phone);
  const email = textValue(row, aliases.email);
  const address = buildAddress(row);
  const errors: string[] = [];
  if (!fullName) errors.push("Не найдено имя клиента");

  return {
    legacyId,
    fullName,
    phone,
    email,
    address,
    organization: textValue(row, aliases.organization),
    status: textValue(row, aliases.status),
    loyaltyPoints: numberValue(row, aliases.loyaltyPoints),
    tareDebt: nonNegativeInteger(row, aliases.tareDebt),
    notes: textValue(row, aliases.notes),
    zoneName: textValue(row, aliases.zoneName),
    district: textValue(row, aliases.district),
    locality: textValue(row, aliases.locality),
    street: textValue(row, aliases.street),
    house: textValue(row, aliases.house),
    building: textValue(row, aliases.building),
    structure: textValue(row, aliases.structure),
    entrance: textValue(row, aliases.entrance),
    floor: textValue(row, aliases.floor),
    apartment: textValue(row, aliases.apartment),
    lat: coordinateValue(row, aliases.lat, -90, 90),
    lng: coordinateValue(row, aliases.lng, -180, 180),
    errors,
    original: row
  };
}

export function normalizeOrganizationRow(row: LegacyRawRow): NormalizedOrganizationRow {
  const legacyId = textValue(row, aliases.legacyId);
  const name = textValue(row, aliases.organization) ?? textValue(row, aliases.fullName);
  const inn = textValue(row, aliases.inn);
  const phone = textValue(row, aliases.phone);
  const errors: string[] = [];
  if (!name) errors.push("Не найдено название организации");

  return {
    legacyId,
    name,
    inn,
    kpp: textValue(row, aliases.kpp),
    phone,
    email: textValue(row, aliases.email),
    address: textValue(row, aliases.organizationAddress) ?? buildAddress(row),
    tareDebt: nonNegativeInteger(row, aliases.tareDebt),
    errors,
    original: row
  };
}

export function normalizeOrderRow(row: LegacyRawRow): NormalizedOrderRow {
  const clientName = personName(row);
  const address = buildAddress(row);
  const createdAt = dateTimeValue(row, aliases.createdAt);
  const deliveryDate = dateValue(row, aliases.deliveryDate) ?? createdAt?.slice(0, 10) ?? moscowToday();
  const errors: string[] = [];
  if (!clientName) errors.push("Не найдено имя клиента");
  if (!address) errors.push("Не найден адрес доставки");

  return {
    legacyId: textValue(row, aliases.legacyId),
    orderNumber: textValue(row, aliases.orderNumber),
    deliveryDate,
    clientName,
    phone: textValue(row, aliases.phone),
    address,
    organization: textValue(row, aliases.organization),
    organizationInn: textValue(row, aliases.inn),
    district: textValue(row, aliases.district),
    lat: coordinateValue(row, aliases.lat, -90, 90),
    lng: coordinateValue(row, aliases.lng, -180, 180),
    timeSlot: textValue(row, aliases.timeSlot),
    state: orderState(textValue(row, aliases.state)),
    paymentMethod: paymentMethod(textValue(row, aliases.paymentMethod), Boolean(textValue(row, aliases.organization))),
    price: Math.max(0, numberValue(row, aliases.price) ?? 0),
    bottles: nonNegativeInteger(row, aliases.bottles) ?? 0,
    comment: textValue(row, aliases.notes),
    courierName: textValue(row, aliases.courierName),
    courierPhone: textValue(row, aliases.courierPhone),
    createdAt,
    errors,
    original: row
  };
}

export function parseDelimitedText(source: string): LegacyRawRow[] {
  const text = source.replace(/^\uFEFF/, "");
  const delimiter = detectDelimiter(text);
  const rows: string[][] = [];
  let row: string[] = [];
  let value = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    const next = text[index + 1];
    if (character === '"' && quoted && next === '"') {
      value += '"';
      index += 1;
    } else if (character === '"') {
      quoted = !quoted;
    } else if (character === delimiter && !quoted) {
      row.push(value.trim());
      value = "";
    } else if ((character === "\n" || character === "\r") && !quoted) {
      if (character === "\r" && next === "\n") index += 1;
      row.push(value.trim());
      if (row.some(Boolean)) rows.push(row);
      row = [];
      value = "";
    } else {
      value += character;
    }
  }

  row.push(value.trim());
  if (row.some(Boolean)) rows.push(row);
  return matrixToObjects(rows);
}

export function matrixToObjects(matrix: unknown[][]): LegacyRawRow[] {
  if (matrix.length < 2) return [];
  const headers = matrix[0].map((value, index) => cleanText(value) ?? `Колонка ${index + 1}`);
  return matrix.slice(1).flatMap((values) => {
    const row: LegacyRawRow = {};
    let hasValue = false;
    headers.forEach((header, index) => {
      const value = values[index] ?? null;
      if (value !== null && value !== "") hasValue = true;
      row[header] = value;
    });
    return hasValue ? [row] : [];
  });
}

export function normalizePhone(value: string | null) {
  if (!value) return null;
  const digits = value.replace(/\D/g, "");
  if (!digits) return null;
  if (digits.length === 11 && digits.startsWith("8")) return `7${digits.slice(1)}`;
  if (digits.length === 10) return `7${digits}`;
  return digits;
}

function textValue(row: LegacyRawRow, names: readonly string[]) {
  return cleanText(findValue(row, names));
}

function numberValue(row: LegacyRawRow, names: readonly string[]) {
  const raw = findValue(row, names);
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;
  const text = cleanText(raw);
  if (!text) return null;
  const normalized = text.replace(/\s/g, "").replace(",", ".").replace(/[^\d.-]/g, "");
  const value = Number(normalized);
  return Number.isFinite(value) ? value : null;
}

function nonNegativeInteger(row: LegacyRawRow, names: readonly string[]) {
  const value = numberValue(row, names);
  return value === null ? null : Math.max(0, Math.round(value));
}

function coordinateValue(row: LegacyRawRow, names: readonly string[], min: number, max: number) {
  const value = numberValue(row, names);
  return value !== null && value >= min && value <= max ? value : null;
}

function dateValue(row: LegacyRawRow, names: readonly string[]) {
  const raw = findValue(row, names);
  if (raw instanceof Date && !Number.isNaN(raw.valueOf())) return raw.toISOString().slice(0, 10);
  const text = cleanText(raw);
  if (!text) return null;
  const isoMatch = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (isoMatch) return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
  const ruMatch = text.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{4})/);
  if (ruMatch) return `${ruMatch[3]}-${ruMatch[2].padStart(2, "0")}-${ruMatch[1].padStart(2, "0")}`;
  const parsed = new Date(text);
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString().slice(0, 10);
}

function dateTimeValue(row: LegacyRawRow, names: readonly string[]) {
  const raw = findValue(row, names);
  if (raw instanceof Date && !Number.isNaN(raw.valueOf())) return raw.toISOString();
  const text = cleanText(raw);
  if (!text) return null;
  const parsed = new Date(text);
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
}

function buildAddress(row: LegacyRawRow) {
  const direct = textValue(row, aliases.address);
  if (direct) return direct;
  const locality = textValue(row, aliases.locality);
  const street = textValue(row, aliases.street);
  const house = textValue(row, aliases.house);
  const building = textValue(row, aliases.building);
  const structure = textValue(row, aliases.structure);
  const apartment = textValue(row, aliases.apartment);
  const pieces = [
    locality,
    street,
    house ? `д. ${house}` : null,
    building ? `корп. ${building}` : null,
    structure ? `стр. ${structure}` : null,
    apartment ? `кв./офис ${apartment}` : null
  ].filter(Boolean);
  return pieces.length > 0 ? pieces.join(", ") : null;
}

function personName(row: LegacyRawRow) {
  const direct = textValue(row, aliases.fullName);
  if (direct) return direct;
  const pieces = [
    textValue(row, aliases.lastName),
    textValue(row, aliases.firstName),
    textValue(row, aliases.middleName)
  ].filter(Boolean);
  return pieces.length > 0 ? pieces.join(" ") : null;
}

function findValue(row: LegacyRawRow, names: readonly string[]) {
  const wanted = new Set(names.map(canonicalHeader));
  const entry = Object.entries(row).find(([key]) => wanted.has(canonicalHeader(key)));
  return entry?.[1] ?? null;
}

function canonicalHeader(value: string) {
  return value
    .toLocaleLowerCase("ru-RU")
    .replace(/ё/g, "е")
    .replace(/[._-]+/g, " ")
    .replace(/[^a-zа-я0-9]+/gi, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function cleanText(value: unknown) {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "object") return null;
  const text = String(value).trim();
  return text && text.toLocaleLowerCase("ru-RU") !== "null" ? text : null;
}

function orderState(value: string | null): NormalizedOrderRow["state"] {
  const state = canonicalHeader(value ?? "");
  if (["delivered", "complete", "completed", "доставлен", "выполнен", "завершен"].includes(state)) return "delivered";
  if (["cancelled", "canceled", "отменен", "отмена"].includes(state)) return "cancelled";
  if (["failed", "не доставлен", "ошибка", "отказ"].includes(state)) return "failed";
  if (["in progress", "в пути", "доставка", "на маршруте"].includes(state)) return "in_progress";
  if (["accepted", "принят"].includes(state)) return "accepted";
  if (["assigned", "назначен"].includes(state)) return "assigned";
  return "draft";
}

function paymentMethod(value: string | null, hasOrganization: boolean): NormalizedOrderRow["paymentMethod"] {
  const method = canonicalHeader(value ?? "");
  if (hasOrganization || ["contract", "договор", "безнал", "по счету"].includes(method)) return "contract";
  if (["card", "карта", "картой", "терминал"].includes(method)) return "card";
  if (["qr", "сбп", "qr код"].includes(method)) return "qr";
  if (["online", "онлайн", "оплачено онлайн"].includes(method)) return "online";
  return "cash";
}

function detectDelimiter(text: string) {
  const sample = text.split(/\r?\n/).find((line) => line.trim()) ?? "";
  const options = [";", ",", "\t"] as const;
  return options.reduce((best, candidate) => {
    const candidateCount = sample.split(candidate).length;
    const bestCount = sample.split(best).length;
    return candidateCount > bestCount ? candidate : best;
  }, ";" as (typeof options)[number]);
}

function moscowToday() {
  const parts = new Intl.DateTimeFormat("en", {
    day: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Moscow",
    year: "numeric"
  }).formatToParts(new Date());
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

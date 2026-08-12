"use client";

import * as L from "leaflet";
import { useEffect, useRef } from "react";
import type { OperationsCourier, OperationsOrder } from "@/lib/types";

const anapaCenter: L.LatLngExpression = [44.8951, 37.3168];

export function OperationsMap({
  couriers,
  orders,
  selectedOrderId,
  onSelectOrder
}: {
  couriers: OperationsCourier[];
  orders: OperationsOrder[];
  selectedOrderId: string | null;
  onSelectOrder: (orderId: string) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const layerRef = useRef<L.LayerGroup | null>(null);
  const latestSelect = useRef(onSelectOrder);

  useEffect(() => { latestSelect.current = onSelectOrder; }, [onSelectOrder]);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = L.map(containerRef.current, { center: anapaCenter, scrollWheelZoom: true, zoom: 12 });
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19
    }).addTo(map);
    mapRef.current = map;
    layerRef.current = L.layerGroup().addTo(map);
    return () => {
      map.remove();
      mapRef.current = null;
      layerRef.current = null;
    };
  }, []);

  useEffect(() => {
    const layer = layerRef.current;
    const map = mapRef.current;
    if (!layer || !map) return;
    layer.clearLayers();
    const positions: L.LatLngExpression[] = [];

    for (const order of orders) {
      if (order.lat === null || order.lng === null) continue;
      positions.push([order.lat, order.lng]);
      const marker = L.circleMarker([order.lat, order.lng], {
        color: order.id === selectedOrderId ? "#162033" : orderColor(order),
        fillColor: orderColor(order),
        fillOpacity: 0.9,
        radius: order.id === selectedOrderId ? 10 : 7,
        weight: order.id === selectedOrderId ? 4 : 2
      });
      const tooltip = document.createElement("span");
      const title = document.createElement("strong");
      title.textContent = `${order.order_number} · ${order.bottles} бут.`;
      tooltip.append(title, document.createElement("br"), document.createTextNode(`${order.client_name} · ${order.address}`));
      marker.bindTooltip(tooltip, { direction: "top", sticky: true });
      marker.on("click", () => latestSelect.current(order.id));
      layer.addLayer(marker);
    }

    for (const courier of couriers) {
      if (courier.lat === null || courier.lng === null) continue;
      positions.push([courier.lat, courier.lng]);
      const marker = L.marker([courier.lat, courier.lng], {
        icon: L.divIcon({
          className: "",
          html: '<span class="operations-courier-marker">🚚</span>',
          iconAnchor: [18, 18],
          iconSize: [36, 36]
        }),
        title: courier.name
      });
      const tooltip = document.createElement("span");
      const title = document.createElement("strong");
      title.textContent = courier.name;
      tooltip.append(title, document.createElement("br"), document.createTextNode(`${courier.vehicle_plate ?? "Без машины"} · ${courier.delivered_orders}/${courier.total_orders} доставлено`));
      marker.bindTooltip(tooltip, { direction: "top" });
      layer.addLayer(marker);
    }

    if (positions.length === 1) map.setView(positions[0], 14);
    else if (positions.length > 1) map.fitBounds(L.latLngBounds(positions), { maxZoom: 14, padding: [36, 36] });
  }, [couriers, orders, selectedOrderId]);

  return <div className="h-[540px] min-h-[420px] w-full bg-slate-100" ref={containerRef} />;
}

function orderColor(order: OperationsOrder) {
  if (order.state === "failed" || order.is_overdue) return "#c2413a";
  if (!order.courier_id) return "#d97706";
  if (order.state === "delivered") return "#15945b";
  if (order.state === "in_progress") return "#2563eb";
  return order.zone_color ?? "#65748a";
}

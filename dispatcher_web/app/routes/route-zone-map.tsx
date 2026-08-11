"use client";

import * as L from "leaflet";
import { useEffect, useRef } from "react";
import type { DeliveryZone } from "@/lib/types";

export type ZoneMapPoint = {
  lat: number;
  lng: number;
};

type RouteZoneMapProps = {
  drawingEnabled: boolean;
  editingZoneId: string | null;
  points: ZoneMapPoint[];
  zones: DeliveryZone[];
  onAddPoint: (point: ZoneMapPoint) => void;
  onMovePoint: (index: number, point: ZoneMapPoint) => void;
  onSelectZone: (zoneId: string) => void;
};

const anapaCenter: L.LatLngExpression = [44.8951, 37.3168];

export function RouteZoneMap(props: RouteZoneMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const shapesRef = useRef<L.LayerGroup | null>(null);
  const latestProps = useRef(props);

  useEffect(() => {
    latestProps.current = props;
  }, [props]);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = L.map(containerRef.current, {
      center: anapaCenter,
      scrollWheelZoom: true,
      zoom: 12
    });
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19
    }).addTo(map);

    const shapes = L.layerGroup().addTo(map);
    map.on("click", (event: L.LeafletMouseEvent) => {
      const current = latestProps.current;
      if (!current.drawingEnabled) return;
      current.onAddPoint({ lat: event.latlng.lat, lng: event.latlng.lng });
    });

    mapRef.current = map;
    shapesRef.current = shapes;

    return () => {
      map.remove();
      mapRef.current = null;
      shapesRef.current = null;
    };
  }, []);

  useEffect(() => {
    const shapes = shapesRef.current;
    if (!shapes) return;
    shapes.clearLayers();

    for (const zone of props.zones) {
      if (zone.id === props.editingZoneId) continue;
      const zonePoints = boundaryToMapPoints(zone);
      if (zonePoints.length < 3) continue;

      const polygon = L.polygon(zonePoints.map(toLatLng), {
        color: zone.color,
        fillColor: zone.color,
        fillOpacity: zone.is_active ? 0.2 : 0.08,
        opacity: zone.is_active ? 0.9 : 0.45,
        weight: 3
      });
      polygon.on("click", (event) => {
        if (event.originalEvent) L.DomEvent.stopPropagation(event.originalEvent);
        latestProps.current.onSelectZone(zone.id);
      });
      polygon.bindTooltip(zoneTooltip(zone), { direction: "top", sticky: true });
      shapes.addLayer(polygon);
    }

    if (props.points.length >= 3) {
      shapes.addLayer(
        L.polygon(props.points.map(toLatLng), {
          color: "#e8720c",
          dashArray: "8 8",
          fillColor: "#e8720c",
          fillOpacity: 0.18,
          weight: 4
        })
      );
    } else if (props.points.length >= 2) {
      shapes.addLayer(
        L.polyline(props.points.map(toLatLng), {
          color: "#e8720c",
          dashArray: "8 8",
          weight: 4
        })
      );
    }

    props.points.forEach((point, index) => {
      const marker = L.marker(toLatLng(point), {
        draggable: true,
        icon: vertexIcon(index + 1),
        keyboard: true,
        title: `Точка ${index + 1}`
      });
      marker.on("dragend", () => {
        const position = marker.getLatLng();
        latestProps.current.onMovePoint(index, { lat: position.lat, lng: position.lng });
      });
      shapes.addLayer(marker);
    });
  }, [props.editingZoneId, props.points, props.zones]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || props.drawingEnabled) return;

    const points = props.points.length > 0 ? props.points : props.zones.flatMap(boundaryToMapPoints);
    if (points.length === 0) return;
    if (points.length === 1) {
      map.setView(toLatLng(points[0]), 14);
      return;
    }

    map.fitBounds(L.latLngBounds(points.map(toLatLng)), { maxZoom: 15, padding: [36, 36] });
  }, [props.drawingEnabled, props.points, props.zones]);

  return <div className="h-[620px] min-h-[460px] w-full bg-slate-100" ref={containerRef} />;
}

function boundaryToMapPoints(zone: DeliveryZone): ZoneMapPoint[] {
  const ring = zone.boundary?.coordinates?.[0] ?? [];
  const points = ring.flatMap((coordinate): ZoneMapPoint[] => {
    const [lng, lat] = coordinate;
    return Number.isFinite(lat) && Number.isFinite(lng) ? [{ lat, lng }] : [];
  });

  if (points.length > 1 && samePoint(points[0], points.at(-1)!)) points.pop();
  return points;
}

function samePoint(left: ZoneMapPoint, right: ZoneMapPoint) {
  return Math.abs(left.lat - right.lat) < 0.0000001 && Math.abs(left.lng - right.lng) < 0.0000001;
}

function toLatLng(point: ZoneMapPoint): L.LatLngExpression {
  return [point.lat, point.lng];
}

function vertexIcon(number: number) {
  return L.divIcon({
    className: "",
    html: `<span class="route-zone-vertex">${number}</span>`,
    iconAnchor: [15, 15],
    iconSize: [30, 30]
  });
}

function zoneTooltip(zone: DeliveryZone) {
  const content = document.createElement("span");
  const name = document.createElement("strong");
  name.textContent = zone.name;
  content.append(name, document.createElement("br"), zone.is_active ? "Активная зона" : "Зона выключена");
  return content;
}

import { NextResponse } from "next/server";

type NominatimResult = {
  lat: string;
  lon: string;
};

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const query = searchParams.get("q")?.trim();

  if (!query) {
    return NextResponse.json([]);
  }

  const nominatimUrl = new URL("https://nominatim.openstreetmap.org/search");
  nominatimUrl.searchParams.set("q", query);
  nominatimUrl.searchParams.set("format", "json");
  nominatimUrl.searchParams.set("limit", "1");
  nominatimUrl.searchParams.set("countrycodes", "ru");

  const response = await fetch(nominatimUrl, {
    cache: "no-store",
    headers: {
      Accept: "application/json",
      "User-Agent": "buzhor-dispatcher/1.0"
    }
  });

  if (!response.ok) {
    return NextResponse.json([], { status: response.status });
  }

  const data = (await response.json()) as NominatimResult[];
  return NextResponse.json(data);
}

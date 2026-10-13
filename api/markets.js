/**
 * ListingoAI server-side market data adapter.
 * CoinGecko credentials stay on the server; the browser only calls /api/markets.
 */
const COINS = [
  "bitcoin","ethereum","tether","binancecoin","solana","usd-coin",
  "xrp","dogecoin","cardano","avalanche-2","chainlink","polkadot"
];

function json(res, status, body, extraHeaders = {}) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "s-maxage=60, stale-while-revalidate=120");
  Object.entries(extraHeaders).forEach(([key, value]) => res.setHeader(key, value));
  res.end(JSON.stringify(body));
}

function compactCoin(coin) {
  return {
    id: coin.id,
    symbol: String(coin.symbol || "").toUpperCase(),
    name: coin.name,
    image: coin.image,
    rank: coin.market_cap_rank,
    priceUsd: coin.current_price,
    marketCapUsd: coin.market_cap,
    volume24hUsd: coin.total_volume,
    change24h: coin.price_change_percentage_24h,
    change7d: coin.price_change_percentage_7d_in_currency,
    high24h: coin.high_24h,
    low24h: coin.low_24h,
    circulatingSupply: coin.circulating_supply,
    sparkline7d: coin.sparkline_in_7d?.price || []
  };
}

async function cgFetch(path, apiTier, apiKey) {
  const base = apiTier === "pro"
    ? "https://pro-api.coingecko.com/api/v3"
    : "https://api.coingecko.com/api/v3";
  const url = new URL(base + path);
  const headers = { accept: "application/json" };

  if (apiKey) {
    headers[apiTier === "pro" ? "x-cg-pro-api-key" : "x-cg-demo-api-key"] = apiKey;
  }

  const response = await fetch(url, {
    headers,
    signal: AbortSignal.timeout(9000)
  });

  const text = await response.text();
  let payload;
  try { payload = JSON.parse(text); } catch { payload = { error: text.slice(0, 300) }; }

  if (!response.ok) {
    const reason = payload?.status?.error_message || payload?.error || `CoinGecko HTTP ${response.status}`;
    const error = new Error(reason);
    error.status = response.status;
    throw error;
  }
  return payload;
}

module.exports = async function handler(req, res) {
  if (req.method !== "GET") {
    return json(res, 405, { error: "Method not allowed" }, { Allow: "GET" });
  }

  const apiKey = process.env.COINGECKO_API_KEY || "";
  const apiTier = (process.env.COINGECKO_API_TIER || "demo").toLowerCase() === "pro" ? "pro" : "demo";

  try {
    const ids = COINS.join(",");
    const marketsPath =
      `/coins/markets?vs_currency=usd&ids=${encodeURIComponent(ids)}&order=market_cap_desc&per_page=12&page=1&sparkline=true&price_change_percentage=24h,7d&locale=en`;

    const [coins, global] = await Promise.all([
      cgFetch(marketsPath, apiTier, apiKey),
      cgFetch("/global", apiTier, apiKey)
    ]);

    return json(res, 200, {
      provider: "CoinGecko",
      sourceMode: apiKey ? `api-${apiTier}` : "public-api",
      asOf: new Date().toISOString(),
      global: {
        totalMarketCapUsd: global?.data?.total_market_cap?.usd ?? null,
        totalVolume24hUsd: global?.data?.total_volume?.usd ?? null,
        btcDominance: global?.data?.market_cap_percentage?.btc ?? null,
        marketCapChange24h: global?.data?.market_cap_change_percentage_24h_usd ?? null
      },
      coins: Array.isArray(coins) ? coins.map(compactCoin) : []
    });
  } catch (error) {
    console.error("ListingoAI market feed error", error);
    return json(res, 502, {
      error: "Market data temporarily unavailable",
      detail: process.env.NODE_ENV === "development" ? error?.message : undefined,
      configured: Boolean(apiKey),
      provider: "CoinGecko"
    });
  }
};

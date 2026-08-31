# MFZ BYA IMACD2

Pine Script **v6** overlay indicator for TradingView.
Signal engine adapted from *Impulse MACD [LazyBear]* (open source) and re-engineered
into a live-ready setup with Entry / SL / TP1 / TP2 / TP3 levels and a TVMT webhook alert.

## Files
- `MFZ_BYA_IMACD2.pine` — the complete indicator, ready to paste into the TradingView Pine Editor.

## Signal
Default **Signal Mode = "Signal Line crosses MACD"** with **Signal Length 3** and **MA Length 10**:

- signal line (3) crosses **up** through the Impulse MACD line (10) → **BUY**
- signal line (3) crosses **down** through the Impulse MACD line (10) → **SELL**

Three other modes are selectable in Settings:
`Fast MA crosses Slow MA (price)` (plain EMA 3 over EMA 10 on price),
`MACD crosses Signal Line` (the original orientation), and `Zero Line Cross`.

## Key behaviour
- **No repainting** — signals are gated behind `barstate.isconfirmed`, so a printed marker never disappears.
- **Distance Method** dropdown: `Pip` / `ATR` / `Percentage`. All three engines are built in and apply to all four levels.
- **Pip rule**: 1 pip = 10 points = `10 * syminfo.mintick` (Auto), with a Manual override.
  - XAUUSD 2-decimal feed → pip `0.10` (150 pips = 15.00 in price)
  - XAUUSD 3-decimal feed → pip `0.01`
  - 5-digit forex → `0.0001` · 3-digit JPY → `0.01`
- **Only the latest setup is drawn** — previous lines and labels are deleted first.
- Lines extend right and labels re-anchor to the live edge every bar, so nothing scrolls off screen.
- Every marker shape, marker colour and line colour is an input.
- Every input uses `display = display.none`, so the chart status line shows only the indicator name.

## Alert setup (TVMT webhook)

**Recommended — one alert, built by Pine.** This is the default and it cannot send `NaN`,
cannot fire BUY and SELL on the same cross, and is the only path where the broker symbol
can be overridden.

1. Indicator **Settings → 6 - Alerts → Alert Method** = `One alert (alert function)`
2. If your MT4/MT5 Market Watch name differs from the chart ticker, set
   **Broker Symbol Override** in the same group (chart `GOLD` → terminal `XAUUSD`, `GOLD.a`, `XAUUSDm`, …)
3. Right-click the chart → **Add alert**
4. Condition: **BYA IMACD1** → **Any alert() function call**
5. Trigger: **Once Per Bar Close**
6. Leave the Message box alone — Pine sends its own JSON
7. Notifications tab → **Webhook URL** → paste your TVMT bridge URL

**Alternative — two alerts, `{{plot()}}` placeholders.** Condition **MFZ BUY (TVMT)** or
**MFZ SELL (TVMT)**, message pre-filled, do not edit it. This path sends `{{ticker}}`
verbatim, so **Broker Symbol Override does not apply to it**, and both alerts must be
created with identical indicator settings or a single cross can trigger both.

`"tp"` carries TP1. On the placeholder path the levels are matched by plot **title**,
not by number, so plot order can never break the webhook.

Alert payload (identical on both paths):

```json
{
  "symbol": "XAUUSD",
  "action": "buy",
  "entry": 4447.20,
  "sl": 4432.20,
  "tp": 4462.20,
  "tp2": 4477.20,
  "tp3": 4492.20,
  "tv_time": "2026-08-31T21:05:00Z",
  "tv_alert_id": "tv-XAUUSD-buy-1756672500000"
}
```

## "Webhook successfully delivered" but the terminal did nothing

That green line in TradingView means only one thing: **TradingView sent the POST and the
bridge answered 2xx.** It is not an acknowledgement from MT4/MT5. Every failure below
still shows as "successfully delivered". Work down the list — the first two cover almost
every case.

| # | Cause | How to confirm | Fix |
|---|-------|----------------|-----|
| 1 | **Symbol name mismatch.** The payload says `"symbol": "GOLD"`, the terminal's Market Watch says `XAUUSD` / `GOLD.a` / `XAUUSDm`. The EA looks the name up literally, finds nothing, and exits without logging a trade. | Open Market Watch (Ctrl+M) and compare, character for character, with the `symbol` field in the alert log | Set **Broker Symbol Override** to the exact Market Watch name (Alert Method must be `One alert`) |
| 2 | **Numbers arrived as `NaN`.** `{{plot("entry")}}` only resolves for a plot that is still an output. Hidden with `display.none` it returns `NaN`, the body stops being valid JSON, the bridge still answers 200. | Look at the delivered body in the TradingView alert log — any `NaN`, blank, or literal `{{plot("entry")}}` | Fixed in this version: the five alert plots now use `display.data_window`. Re-add the indicator so the alert picks up the new outputs |
| 3 | **Alert built on the wrong condition.** An alert on "Any alert() function call" while Alert Method is `Two alerts` (or the reverse) fires the bell and sends nothing usable. | Alert's Condition line vs. the Alert Method input | Match them per the setup steps above |
| 4 | **AutoTrading is off**, or the EA shows a sad face / no smiley on the chart | Toolbar AutoTrading button; the EA's face on the chart corner | Enable AutoTrading, allow algo trading in the EA properties |
| 5 | **Bridge URL not allow-listed in the terminal** (only applies to bridges the EA polls over HTTP) | Tools → Options → Expert Advisors → Allow WebRequest for listed URL | Add the bridge URL there |
| 6 | **The EA is not on a chart**, or is on a chart of a different symbol than the payload | Terminal → Experts tab, and the chart the EA sits on | Attach the EA and leave that chart open |
| 7 | **Market closed / trading disabled for the symbol** at the moment of the alert | Journal tab, "market closed" or "trade disabled" | Nothing to fix in the script |
| 8 | **Bridge received it but rejected it** (missing required field, bad auth key, unknown action) | The bridge's own log, not TradingView's | Align the payload with what your bridge expects |

Check the terminal's **Journal** and **Experts** tabs at the alert timestamp. If neither
shows a single line at that moment, the request never reached the terminal and the fault
is between the bridge and MT — not in the indicator.

## Why the markers are labels, not plotshapes
TradingView allows a maximum of **64 plot outputs per script**, and a `plotshape()` with a
variable colour compiles into three outputs (shape, colour, text colour). Offering nine
shape choices for each direction therefore cost 54 outputs on its own and tripped runtime
error **RE10140** (`too many plots (65)`) when the script was added to a chart.

Markers are drawn with `label.new()` instead. Labels are drawing objects, not plots, so the
full shape and colour choice is preserved at zero plot cost. The script now uses 11 of the
64 outputs. The trade-off is TradingView's 500-label cap, so markers show for roughly the
most recent 500 signals.

## Win-rate dashboard
Top-right table. It makes no signals of its own — it replays the indicator's own entries against the
same SL / TP levels bar by bar across loaded history. SL before TP1 = Loss, TP1 or better = Win.
It recalculates automatically when any input or the timeframe changes. It is a quick overview, not a
tick-precise backtester: when one bar touches both sides, the order is estimated from the bar open/high/low.

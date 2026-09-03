# MFZ BYA IMACD2

Pine Script **v6** overlay indicator for TradingView.
Signal engine adapted from *Impulse MACD [LazyBear]* (open source) and re-engineered
into a live-ready setup with Entry / SL / TP1 / TP2 / TP3 levels and a TVMT webhook alert.

## Files
- `MFZ_BYA_IMACD2.pine` — the complete indicator, ready to paste into the TradingView Pine Editor.

## Signal

**The crossing of the two lines is the only thing that fires an alert.**
With **MA Length 10** (slow, drives the Impulse MACD line `md`) and
**Signal Length 3** (fast, drives the signal line `sb`):

- `md` crosses **up** through `sb` → **BUY**
- `md` crosses **down** through `sb` → **SELL**

There is no zone filter, no one-signal-per-direction filter and no trend filter.
Any of those can swallow a crossing and leave the alerts out of step with the
chart, so they were removed. Lot size, TP and SL are managed in TVMT.

A single setting, **Which Cross Is A BUY**, swaps the two labels:

| Setting | Meaning |
| --- | --- |
| `MACD crosses Signal Line (standard)` *(default)* | `md` up through `sb` = BUY. Follows price direction. |
| `Signal Line crosses MACD (reversed)` | The **same** crossings with BUY and SELL swapped. |

Both options describe one and the same event — two lines can only swap places
once per crossing — so this only decides which side gets called BUY. The old
separate `Invert Buy / Sell` checkbox was removed: having two controls that do
the same job made it easy to flip twice and end up back where you started.

## Why the alerts did not match the chart

The `Signal Mode` dropdown used to carry two extra options that are **not** the
MACD/signal crossing at all:

- `Fast MA crosses Slow MA (price)` — a plain EMA(3)/EMA(10) crossover on *price*
- `Zero Line Cross` — the Impulse MACD crossing zero

For a while `Fast MA crosses Slow MA (price)` was the **default**. TradingView
stores an indicator's input values inside the saved chart layout, so a chart set
up during that period keeps running the price-EMA crossover even after the
script's default is changed back — the saved value always wins over a new
default. The alerts were faithfully reporting an EMA-on-price crossover while
the chart was being read against the MACD and signal lines.

Both options are now gone, so the stale saved value can no longer be restored.

> **After updating the script, open Settings → Inputs and confirm
> `Which Cross Is A BUY` reads `MACD crosses Signal Line (standard)`.**
> If markers still sit on the wrong side, switch it to the reversed option —
> that one setting is now the only thing that can flip them.

## Checking alignment against the pane indicator

This script is an **overlay**, so `md` and `sb` are not drawn on it. To compare
it against *Impulse MACD [LazyBear]* in the lower pane, that pane copy must use
the same numbers or the lines will not be the ones firing your alerts:

- MA Length **10** (LazyBear ships 34)
- Signal Length **3** (LazyBear ships 9)
- Source **hlc3**

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
1. Right-click the chart → **Add alert**
2. Condition: **MFZ BYA IMACD2** → pick **MFZ BUY (TVMT)** or **MFZ SELL (TVMT)**
3. Trigger: **Once Per Bar Close**
4. Leave the pre-filled JSON message exactly as it is — do not add any text
5. Notifications tab → **Webhook URL** → paste your TVMT bridge URL

Alert payload (values arrive as raw numbers via `{{plot("title")}}`):

```json
{
  "symbol": "{{ticker}}",
  "action": "buy",
  "entry": {{plot("entry")}},
  "sl": {{plot("sl")}},
  "tp": {{plot("tp")}},
  "tp2": {{plot("tp2")}},
  "tp3": {{plot("tp3")}},
  "tv_time": "{{timenow}}",
  "tv_alert_id": "tv-{{ticker}}-buy-{{time}}"
}
```

`"tp"` carries TP1. Levels are matched by plot **title**, not by number, so plot order can never break the webhook.

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
